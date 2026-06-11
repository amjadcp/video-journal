import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/core/storage/database.dart';
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
  }) async {
    final localRepo = _ref.read(journalRepositoryProvider);
    final api = DriveService.getDriveApi(accessToken);

    File? tempDbFile;
    JournalDatabase? remoteDb;

    try {
      AppLogger.info(LogCategory.restore, 'Starting restore workflow from root: $rootFolderId');
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 0, status: 'Searching for backup...'));

      // List files in the root folder
      final remoteFiles = await DriveService.listFiles(api, rootFolderId);
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
      final localAssets = await localRepo.getAllAssets();

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

        // Check duplicates: UUID, Hash, or Drive ID
        VisualAssetData? duplicate;
        for (final la in localAssets) {
          if (la.id == rAsset.id ||
              la.assetHash == rAsset.assetHash ||
              (la.driveFileId != null && la.driveFileId == rAsset.driveFileId)) {
            duplicate = la;
            break;
          }
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
        if (!fileExistsLocally && rAsset.driveFileId != null) {
          AppLogger.info(LogCategory.restore, 'Downloading missing asset file: ${rAsset.id}');
          final downloaded = await DriveService.downloadFile(
            api: api,
            fileId: rAsset.driveFileId!,
            localSavePath: targetLocalPath,
          );
          if (!downloaded) {
            AppLogger.warning(LogCategory.restore, 'Failed downloading file for asset: ${rAsset.id}');
            continue; // Skip database record save if file download failed
          }
        }

        // Save/Update asset metadata locally with verified local path
        if (!assetExistsLocally) {
          final restoredAsset = rAsset.copyWith(
            localPath: targetLocalPath,
            thumbnailPath: targetLocalPath, // Use same path for simple MVP thumbnail
            syncStatus: SyncStatus.synced,
          );
          await localRepo.saveAsset(restoredAsset);
        } else if (!fileExistsLocally) {
          // File was missing but metadata existed; update path and set synced
          final updatedAsset = duplicate!.copyWith(
            localPath: targetLocalPath,
            thumbnailPath: targetLocalPath,
            syncStatus: SyncStatus.synced,
          );
          await localRepo.updateAsset(updatedAsset);
        }
      }

      // 3. Restore Tags
      onProgress?.call(RestoreProgress(totalItems: 10, currentItemIndex: 9, status: 'Restoring tags...'));
      final remoteTags = await remoteDb.select(remoteDb.tags).get();
      for (final rTag in remoteTags) {
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
      // Close temporary database connection
      await remoteDb?.close();
      // Clean up temporary downloaded database file
      if (tempDbFile != null && await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    }
  }
}

final restoreManagerProvider = Provider<RestoreManager>((ref) {
  return RestoreManager(ref);
});
