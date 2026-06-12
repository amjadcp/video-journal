import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/backup/data/backup_worker.dart';
import 'package:video_journal/features/backup/domain/backup_manager.dart';
import 'package:video_journal/features/backup/domain/restore_manager.dart';
import 'package:video_journal/features/sync/data/drive_service.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoBackup = false;
  bool _wifiOnly = true;
  bool _deleteCloud = false;
  String? _rootFolderId;
  String? _lastBackupTime;

  bool _isSyncing = false;
  String _syncProgressText = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final autoBackup = await settingsRepo.isAutoBackupEnabled();
    final wifiOnly = await settingsRepo.isWifiOnlyBackup();
    final deleteCloud = await settingsRepo.isDeleteCloudCopyEnabled();
    final rootId = await settingsRepo.getDriveRootFolderId();
    final lastBackup = await settingsRepo.getLastBackupTime();

    setState(() {
      _autoBackup = autoBackup;
      _wifiOnly = wifiOnly;
      _deleteCloud = deleteCloud;
      _rootFolderId = rootId;
      _lastBackupTime = lastBackup;
    });
  }

  Future<void> _toggleAutoBackup(bool val) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setAutoBackupEnabled(val);
    setState(() => _autoBackup = val);

    if (val) {
      // Register WorkManager periodic task
      AppLogger.info(LogCategory.backup, 'Registering WorkManager auto-backup task');
      await Workmanager().registerPeriodicTask(
        "auto-backup-sync",
        autoBackupTaskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(
          networkType: _wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } else {
      AppLogger.info(LogCategory.backup, 'Cancelling WorkManager auto-backup task');
      await Workmanager().cancelByUniqueName("auto-backup-sync");
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithGoogle();
    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Drive connected successfully.')),
      );
      _setupDriveFolder();
    }
  }

  Future<void> _setupDriveFolder() async {
    final authRepo = ref.read(authRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    
    final token = await authRepo.getAccessToken();
    if (token == null) return;

    setState(() => _isSyncing = true);
    setState(() => _syncProgressText = 'Configuring Drive folder...');

    final api = DriveService.getDriveApi(token);
    // Create/retrieve root folder "My Visual Journal"
    final folderId = await DriveService.getOrCreateRootFolder(api, 'My Visual Journal');

    if (folderId != null) {
      await settingsRepo.setDriveRootFolderId(folderId);
      setState(() => _rootFolderId = folderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive Root Folder selected.')),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _triggerManualBackup() async {
    final authRepo = ref.read(authRepositoryProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final token = await authRepo.getAccessToken();
    if (token == null || _rootFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Google Drive first.')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncProgressText = 'Preparing backup...';
    });

    try {
      final backupManager = ref.read(backupManagerProvider);
      await backupManager.runBackup(
        accessToken: token,
        rootFolderId: _rootFolderId!,
        onProgress: (prog) {
          setState(() {
            _syncProgressText = prog.status;
          });
        },
      );
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your memories are safely backed up.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup could not be completed. We\'ll try again later.')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _triggerRestore() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (_rootFolderId == null) return;

    final token = await authRepo.getAccessToken();
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Memories?'),
        content: const Text('Restore will merge your remote backups into this local device. Existing items will not be duplicated.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text('Restore'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSyncing = true;
      _syncProgressText = 'Restoring backups...';
    });

    try {
      final restoreManager = ref.read(restoreManagerProvider);
      await restoreManager.runRestore(
        accessToken: token,
        rootFolderId: _rootFolderId!,
        onProgress: (prog) {
          setState(() {
            _syncProgressText = prog.status;
          });
        },
      );
      // Reload UI controllers with the newly restored local database data
      await ref.read(journalControllerProvider.notifier).loadAssets();
      await ref.read(foldersControllerProvider.notifier).loadFolders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed. Please check internet connection.')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isSyncing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_syncProgressText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account setup section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Google Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        user == null
                            ? Column(
                                children: [
                                  const Text('Sign in to backup your visual journals to Google Drive.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  const SizedBox(height: 16),
                                  SignInButton(
                                    Buttons.google,
                                    text: "Connect Google Drive",
                                    onPressed: _handleGoogleSignIn,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null),
                                    title: Text(user.displayName ?? 'Connected Account'),
                                    subtitle: Text(user.email ?? ''),
                                    trailing: TextButton(
                                      onPressed: () async {
                                        await authRepo.signOut();
                                        await ref.read(settingsRepositoryProvider).setDriveRootFolderId(null);
                                        setState(() {
                                          _rootFolderId = null;
                                        });
                                        _loadSettings();
                                      },
                                      child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Appearance Section (Theme selection toggle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Dark Mode'),
                          subtitle: const Text('Toggle between Light and Dark theme'),
                          value: ref.watch(themeModeProvider) == ThemeMode.dark ||
                              (ref.watch(themeModeProvider) == ThemeMode.system &&
                                  MediaQuery.of(context).platformBrightness == Brightness.dark),
                          onChanged: (bool isDark) {
                            ref.read(themeModeProvider.notifier).setThemeMode(
                                  isDark ? ThemeMode.dark : ThemeMode.light,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Backup Settings Section
                if (user != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Backup Preferences', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Auto Backup'),
                            subtitle: const Text('Schedule automatic background sync'),
                            value: _autoBackup,
                            onChanged: _toggleAutoBackup,
                          ),
                          SwitchListTile(
                            title: const Text('Wi-Fi Only'),
                            subtitle: const Text('Restricts automatic sync to Wi-Fi networks'),
                            value: _wifiOnly,
                            onChanged: (val) async {
                              await ref.read(settingsRepositoryProvider).setWifiOnlyBackup(val);
                              setState(() => _wifiOnly = val);
                              if (_autoBackup) _toggleAutoBackup(true); // reload background task logic
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Cloud Deletion preference'),
                            subtitle: const Text('Delete cloud copy when deleting media locally'),
                            value: _deleteCloud,
                            onChanged: (val) async {
                              await ref.read(settingsRepositoryProvider).setDeleteCloudCopyEnabled(val);
                              setState(() => _deleteCloud = val);
                            },
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _lastBackupTime == null
                                  ? 'Last backup: Never'
                                  : 'Last backup: ${DateTime.parse(_lastBackupTime!).toLocal().toString().split('.')[0]}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Manual Operations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _triggerManualBackup,
                                  icon: const Icon(Icons.backup),
                                  label: const Text('Backup Now'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _triggerRestore,
                                  icon: const Icon(Icons.restore),
                                  label: const Text('Restore Data'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
