import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_journal/features/settings/domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final FlutterSecureStorage _storage;

  SettingsRepositoryImpl(this._storage);

  static const _keyAutoBackup = 'auto_backup_enabled';
  static const _keyWifiOnly = 'wifi_only_backup';
  static const _keyDeleteCloud = 'delete_cloud_copy';
  static const _keyDriveRoot = 'drive_root_folder_id';
  static const _keyLastBackup = 'last_backup_time';

  @override
  Future<bool> isAutoBackupEnabled() async {
    final val = await _storage.read(key: _keyAutoBackup);
    return val == 'true';
  }

  @override
  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _storage.write(key: _keyAutoBackup, value: enabled.toString());
  }

  @override
  Future<bool> isWifiOnlyBackup() async {
    final val = await _storage.read(key: _keyWifiOnly);
    // Defaults to true (safety first, avoiding cellular data by default)
    return val != 'false';
  }

  @override
  Future<void> setWifiOnlyBackup(bool wifiOnly) async {
    await _storage.write(key: _keyWifiOnly, value: wifiOnly.toString());
  }

  @override
  Future<bool> isDeleteCloudCopyEnabled() async {
    final val = await _storage.read(key: _keyDeleteCloud);
    return val == 'true';
  }

  @override
  Future<void> setDeleteCloudCopyEnabled(bool enabled) async {
    await _storage.write(key: _keyDeleteCloud, value: enabled.toString());
  }

  @override
  Future<String?> getDriveRootFolderId() {
    return _storage.read(key: _keyDriveRoot);
  }

  @override
  Future<void> setDriveRootFolderId(String? folderId) {
    if (folderId == null) {
      return _storage.delete(key: _keyDriveRoot);
    }
    return _storage.write(key: _keyDriveRoot, value: folderId);
  }

  @override
  Future<String?> getLastBackupTime() {
    return _storage.read(key: _keyLastBackup);
  }

  @override
  Future<void> setLastBackupTime(String? timeStr) {
    if (timeStr == null) {
      return _storage.delete(key: _keyLastBackup);
    }
    return _storage.write(key: _keyLastBackup, value: timeStr);
  }

  static const _keyThemeMode = 'theme_mode';

  @override
  Future<String?> getThemeMode() {
    return _storage.read(key: _keyThemeMode);
  }

  @override
  Future<void> setThemeMode(String mode) {
    return _storage.write(key: _keyThemeMode, value: mode);
  }
}
