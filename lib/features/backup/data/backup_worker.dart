import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/backup/domain/backup_manager.dart';

const String autoBackupTaskName = "com.antigravity.video_journal.autoBackupTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info(LogCategory.backup, 'Background backup task started from WorkManager');
    
    try {
      // Initialize Firebase (required since we run in a separate Isolate)
      await Firebase.initializeApp();

      // Create a temporary ProviderContainer to access our Riverpod providers
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final settingsRepo = container.read(settingsRepositoryProvider);

      final user = authRepo.currentUser;
      if (user == null) {
        AppLogger.info(LogCategory.backup, 'No user signed in. Skipping background backup.');
        return true;
      }

      final isAutoBackupEnabled = await settingsRepo.isAutoBackupEnabled();
      if (!isAutoBackupEnabled) {
        AppLogger.info(LogCategory.backup, 'Auto backup is disabled. Skipping.');
        return true;
      }

      final rootFolderId = await settingsRepo.getDriveRootFolderId();
      if (rootFolderId == null) {
        AppLogger.warning(LogCategory.backup, 'No Drive root folder ID set. Skipping.');
        return true;
      }

      final accessToken = await authRepo.getAccessToken();
      if (accessToken == null) {
        AppLogger.warning(LogCategory.backup, 'Failed to retrieve Google access token for backup. Skipping.');
        return true;
      }

      final backupManager = container.read(backupManagerProvider);
      await backupManager.runBackup(
        accessToken: accessToken,
        rootFolderId: rootFolderId,
      );

      AppLogger.info(LogCategory.backup, 'Background backup completed successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.backup, 'Background backup task failed', e, stackTrace);
      return false;
    }
  });
}
