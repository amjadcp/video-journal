import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:video_journal/features/sync/data/drive_service.dart';
import 'package:video_journal/shared/enums/enums.dart';

class RestoreProgress {
  final int totalItems;
  final int currentItemIndex;
  final String status;

  RestoreProgress({
    required this.totalItems,
    required this.currentItemIndex,
    required this.status,
  });
}

class RestoreManager {
  final Ref _ref;

  RestoreManager(this._ref);

  Future<void> runRestore({
    required String accessToken,
    required String rootFolderId,
    Function(RestoreProgress progress)? onProgress,
    drive.DriveApi? driveApi,
  }) async {
    final localRepo = _ref.read(journalRepositoryProvider);
    final api = driveApi ?? DriveService.getDriveApi(accessToken);

    File? tempDbFile;
    JournalDatabase? remoteDb;

    try {
      AppLogger.info(LogCategory.restore, 'Starting restore workflow from root: $rootFolderId');
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 0, status: 'Searching for backup...'));

      // List files in the root folder
      final remoteFiles = await DriveService.listFiles(api, rootFolderId);
      final remoteFileIds = remoteFiles.map((f) => f.id).toSet();
      final dbBackupFile = remoteFiles.firstWhere(
        (f) => f.name == 'journal_backup.db',
        orElse: () => throw Exception('No database backup file found in Drive'),
      );

      // Download remote database file to a temporary location
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 1, status: 'Downloading backup metadata...'));
      final tempDir = await getTemporaryDirectory();
      tempDbFile = File(p.join(tempDir.path, 'temp_restore_journal.db'));
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }

      final dbDownloadSuccess = await DriveService.downloadFile(
        api: api,
        fileId: dbBackupFile.id!,
        localSavePath: tempDbFile.path,
      );

      if (!dbDownloadSuccess) {
        throw Exception('Failed to download database backup');
      }

      // Open the downloaded database using Drift
      remoteDb = JournalDatabase.forTesting(NativeDatabase(tempDbFile));

      // 1. Restore Folder Structure
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 2, status: 'Restoring folders...'));
      final remoteFolders = await remoteDb.select(remoteDb.folders).get();
      for (final rFolder in remoteFolders) {
        final localFolder = await localRepo.getFolderById(rFolder.id);
        if (localFolder == null) {
          await localRepo.saveFolder(rFolder);
        }
      }

      // 2. Restore Visual Assets (with duplicate prevention checks)
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 4, status: 'Restoring assets...'));
      final remoteAssets = await remoteDb.select(remoteDb.visualAssets).get();
      final localDb = _ref.read(journalDatabaseProvider);

      final docDir = await getApplicationDocumentsDirectory();
      final localMediaDir = Directory(p.join(docDir.path, 'media'));
      if (!await localMediaDir.exists()) {
        await localMediaDir.create(recursive: true);
      }

      final totalAssets = remoteAssets.length;
      for (int i = 0; i < totalAssets; i++) {
        final rAsset = remoteAssets[i];

        onProgress?.call(RestoreProgress(
          totalItems: totalAssets,
          currentItemIndex: i,
          status: 'Restoring asset ${i + 1} of $totalAssets...',
        ));

        // Find if it already exists in the local database (even if soft-deleted)
        final localAsset = await (localDb.select(localDb.visualAssets)..where((t) => t.id.equals(rAsset.id))).getSingleOrNull();

        // Check if there is a duplicate by hash or drive id if the ID doesn't match
        VisualAssetData? duplicate = localAsset;
        if (duplicate == null) {
          final query = localDb.select(localDb.visualAssets)
            ..where((t) => t.assetHash.equals(rAsset.assetHash) | (t.driveFileId.isNotNull() & t.driveFileId.equals(rAsset.driveFileId ?? '')));
          duplicate = await query.getSingleOrNull();
        }

        final assetExistsLocally = duplicate != null;
        final localFile = File(assetExistsLocally ? duplicate.localPath : rAsset.localPath);
        final fileExistsLocally = await localFile.exists();

        // Target path where to save the restored asset
        String targetLocalPath = rAsset.localPath;

        // If the path belongs to another device or is relative, normalize to current App Documents Directory
        if (!fileExistsLocally) {
          final fileName = p.basename(rAsset.localPath);
          targetLocalPath = p.join(localMediaDir.path, fileName);
        }

        // If the media file is not on disk, download it
        if (!fileExistsLocally) {
          final fileId = rAsset.driveFileId;
          final isFileOnDrive = fileId != null && remoteFileIds.contains(fileId);
          
          if (isFileOnDrive) {
            AppLogger.info(LogCategory.restore, 'Downloading missing asset file: ${rAsset.id}');
            final downloaded = await DriveService.downloadFile(
              api: api,
              fileId: fileId,
              localSavePath: targetLocalPath,
            );
            if (!downloaded) {
              AppLogger.warning(LogCategory.restore, 'Failed downloading file for asset: ${rAsset.id}');
              continue; // Skip database record save if file download failed
            }
          } else {
            // File is missing locally and either has no Drive ID or the file is not present in the Drive folder.
            // Skip restoring this database record as the media is unrecoverable.
            AppLogger.warning(LogCategory.restore, 'Asset ${rAsset.id} has no valid Drive backup file. Skipping.');
            continue;
          }
        }

        // Save/Update asset metadata locally with verified local path and set isDeleted = false (undelete)
        if (!assetExistsLocally) {
          final restoredAsset = rAsset.copyWith(
            localPath: targetLocalPath,
            thumbnailPath: targetLocalPath, // Use same path for simple MVP thumbnail
            syncStatus: SyncStatus.synced,
            isDeleted: false, // Ensure it is NOT marked as deleted
          );
          await localRepo.saveAsset(restoredAsset);
        } else if (!fileExistsLocally || duplicate.isDeleted) {
          // File was missing or metadata existed but was soft-deleted; update path, sync, and set isDeleted = false
          final updatedAsset = duplicate.copyWith(
            localPath: targetLocalPath,
            thumbnailPath: targetLocalPath,
            syncStatus: SyncStatus.synced,
            isDeleted: false, // Ensure it is NOT marked as deleted
          );
          await localRepo.updateAsset(updatedAsset);
        }
      }

      // 3. Restore Tags
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 9, status: 'Restoring tags...'));
      final remoteTags = await remoteDb.select(remoteDb.tags).get();
      for (final rTag in remoteTags) {
        // Ensure the associated asset exists in the local database to avoid foreign key violations (e.g. if the asset was skipped)
        final assetInDb = await (localDb.select(localDb.visualAssets)..where((t) => t.id.equals(rTag.visualAssetId))).getSingleOrNull();
        if (assetInDb == null) {
          AppLogger.warning(LogCategory.restore, 'Skipping tag ${rTag.name} because its associated asset ${rTag.visualAssetId} is missing locally');
          continue;
        }

        final tagsForAsset = await localRepo.getTagsForAsset(rTag.visualAssetId);
        final tagExists = tagsForAsset.any((lt) => lt.name == rTag.name);
        if (!tagExists) {
          await localRepo.addTag(rTag);
        }
      }

      AppLogger.info(LogCategory.restore, 'Restore completed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.restore, 'Failed during restore execution', e, stackTrace);
      rethrow;
    } finally {
      // Close temporary database connection safely
      try {
        await remoteDb?.close();
      } catch (closeError) {
        AppLogger.warning(LogCategory.restore, 'Failed to close remote database connection: $closeError');
      }
      
      // Clean up temporary downloaded database file safely
      try {
        if (tempDbFile != null && await tempDbFile.exists()) {
          await tempDbFile.delete();
        }
      } catch (deleteError) {
        AppLogger.warning(LogCategory.restore, 'Failed to delete temporary database file: $deleteError');
      }
    }
  }
}

final restoreManagerProvider = Provider<RestoreManager>((ref) {
  return RestoreManager(ref);
});
