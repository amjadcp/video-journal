import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/sync/data/drive_service.dart';
import 'package:video_journal/shared/enums/enums.dart';

class BackupProgress {
  final int totalItems;
  final int currentItemIndex;
  final String currentItemName;
  final String status;

  BackupProgress({
    required this.totalItems,
    required this.currentItemIndex,
    required this.currentItemName,
    required this.status,
  });
}

class BackupManager {
  final Ref _ref;

  BackupManager(this._ref);

  Future<void> runBackup({
    required String accessToken,
    required String rootFolderId,
    Function(BackupProgress progress)? onProgress,
  }) async {
    final repo = _ref.read(journalRepositoryProvider);
    final api = DriveService.getDriveApi(accessToken);

    try {
      AppLogger.info(LogCategory.backup, 'Starting incremental backup to folder: $rootFolderId');
      
      // Fetch assets that are not synced
      final allAssets = await repo.getAllAssets();
      final unsyncedAssets = allAssets.where((a) => a.syncStatus != SyncStatus.synced).toList();

      if (unsyncedAssets.isEmpty) {
        AppLogger.info(LogCategory.backup, 'No unsynced assets found. Uploading database only.');
        onProgress?.call(BackupProgress(
          totalItems: 1,
          currentItemIndex: 0,
          currentItemName: 'Database Backup',
          status: 'Uploading database...',
        ));
        await _uploadDatabase(api, rootFolderId);
        _ref.read(settingsRepositoryProvider).setLastBackupTime(DateTime.now().toIso8601String());
        return;
      }

      final totalCount = unsyncedAssets.length;
      for (int i = 0; i < totalCount; i++) {
        final asset = unsyncedAssets[i];
        
        onProgress?.call(BackupProgress(
          totalItems: totalCount,
          currentItemIndex: i,
          currentItemName: p.basename(asset.localPath),
          status: 'Uploading file ${i + 1} of $totalCount...',
        ));

        // Update local sync status to syncing
        await repo.updateAsset(asset.copyWith(syncStatus: SyncStatus.syncing));

        // Perform Drive upload
        final mimeType = asset.assetType == AssetType.video ? 'video/mp4' : 'image/png';
        final fileId = await DriveService.uploadFile(
          api: api,
          file: File(asset.localPath),
          name: p.basename(asset.localPath),
          mimeType: mimeType,
          parentId: rootFolderId,
        );

        if (fileId != null) {
          // Success: Update database
          await repo.updateAsset(asset.copyWith(
            syncStatus: SyncStatus.synced,
            driveFileId: Value(fileId),
            updatedAt: DateTime.now(),
          ));
          AppLogger.info(LogCategory.backup, 'Asset ${asset.id} synced successfully');
        } else {
          // Failure
          await repo.updateAsset(asset.copyWith(syncStatus: SyncStatus.failed));
          AppLogger.warning(LogCategory.backup, 'Failed to upload asset ${asset.id}');
        }
      }

      // Finally, backup the local database file
      onProgress?.call(BackupProgress(
        totalItems: totalCount,
        currentItemIndex: totalCount,
        currentItemName: 'Database Backup',
        status: 'Uploading database...',
      ));
      await _uploadDatabase(api, rootFolderId);

      // Save last backup time
      await _ref.read(settingsRepositoryProvider).setLastBackupTime(DateTime.now().toIso8601String());
      AppLogger.info(LogCategory.backup, 'Backup process finished successfully');
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.backup, 'Critical backup manager error', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _uploadDatabase(dynamic api, String parentId) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'journal.db'));

      if (!await dbFile.exists()) {
        AppLogger.warning(LogCategory.backup, 'Database file not found, skipping database backup');
        return;
      }

      // Check if db backup file already exists in Drive to overwrite or create new
      final list = await api.files.list(
        q: "name = 'journal_backup.db' and '$parentId' in parents and trashed = false",
        spaces: 'drive',
      );

      if (list.files != null && list.files!.isNotEmpty) {
        // Update existing database file
        final existingId = list.files!.first.id!;
        AppLogger.info(LogCategory.backup, 'Updating existing database backup: $existingId');
        final driveFile = drive.File()..name = 'journal_backup.db';
        final media = drive.Media(dbFile.openRead(), await dbFile.length());
        await api.files.update(driveFile, existingId, uploadMedia: media);
        AppLogger.info(LogCategory.backup, 'Database backup updated successfully');
      } else {
        // Create new database backup file
        AppLogger.info(LogCategory.backup, 'Creating new database backup in Drive');
        await DriveService.uploadFile(
          api: api,
          file: dbFile,
          name: 'journal_backup.db',
          mimeType: 'application/octet-stream',
          parentId: parentId,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.backup, 'Database backup upload failed', e, stackTrace);
    }
  }
}

final backupManagerProvider = Provider<BackupManager>((ref) {
  return BackupManager(ref);
});
