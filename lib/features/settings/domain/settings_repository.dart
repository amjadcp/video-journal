abstract class SettingsRepository {
  Future<bool> isAutoBackupEnabled();
  Future<void> setAutoBackupEnabled(bool enabled);

  Future<bool> isWifiOnlyBackup();
  Future<void> setWifiOnlyBackup(bool wifiOnly);

  Future<bool> isDeleteCloudCopyEnabled();
  Future<void> setDeleteCloudCopyEnabled(bool enabled);

  Future<String?> getDriveRootFolderId();
  Future<void> setDriveRootFolderId(String? folderId);

  Future<String?> getLastBackupTime();
  Future<void> setLastBackupTime(String? timeStr);
}
