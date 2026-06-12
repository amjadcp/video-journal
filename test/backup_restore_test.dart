import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/backup/domain/backup_manager.dart';
import 'package:video_journal/features/backup/domain/restore_manager.dart';
import 'package:video_journal/features/journal/data/journal_repository_impl.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/features/settings/domain/settings_repository.dart';
import 'package:video_journal/features/auth/domain/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_journal/shared/enums/enums.dart';

// Fake implementations for Google Drive API
class FakeDriveApi implements drive.DriveApi {
  @override
  final FakeFilesResource files;

  FakeDriveApi(this.files);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFileEntry {
  final drive.File metadata;
  final List<int> bytes;

  _FakeFileEntry(this.metadata, this.bytes);
}

class FakeFilesResource implements drive.FilesResource {
  final Map<String, _FakeFileEntry> driveFiles = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;

    if (name == #list) {
      final String? q = invocation.namedArguments[#q] as String?;
      return _list(q);
    }

    if (name == #create) {
      final drive.File request = invocation.positionalArguments[0] as drive.File;
      final drive.Media? uploadMedia = invocation.namedArguments[#uploadMedia] as drive.Media?;
      return _create(request, uploadMedia);
    }

    if (name == #update) {
      final drive.File request = invocation.positionalArguments[0] as drive.File;
      final String fileId = invocation.positionalArguments[1] as String;
      final drive.Media? uploadMedia = invocation.namedArguments[#uploadMedia] as drive.Media?;
      return _update(request, fileId, uploadMedia);
    }

    if (name == #get) {
      final String fileId = invocation.positionalArguments[0] as String;
      final drive.DownloadOptions downloadOptions =
          invocation.namedArguments[#downloadOptions] as drive.DownloadOptions? ?? drive.DownloadOptions.metadata;
      return _get(fileId, downloadOptions);
    }

    return super.noSuchMethod(invocation);
  }

  Future<drive.FileList> _list(String? q) async {
    List<drive.File> filtered = driveFiles.values.map((e) => e.metadata).toList();

    if (q != null) {
      if (q.contains("mimeType = 'application/vnd.google-apps.folder'")) {
        filtered = filtered.where((f) => f.mimeType == 'application/vnd.google-apps.folder').toList();
      }
      
      final nameRegExp = RegExp(r"name\s*=\s*'([^']+)'");
      final nameMatch = nameRegExp.firstMatch(q);
      if (nameMatch != null) {
        final name = nameMatch.group(1);
        filtered = filtered.where((f) => f.name == name).toList();
      }

      final parentRegExp = RegExp(r"'([^']+)'\s+in\s+parents");
      final parentMatch = parentRegExp.firstMatch(q);
      if (parentMatch != null) {
        final parentId = parentMatch.group(1);
        filtered = filtered.where((f) => f.parents?.contains(parentId) ?? false).toList();
      }
    }

    return drive.FileList()..files = filtered;
  }

  Future<drive.File> _create(drive.File request, drive.Media? uploadMedia) async {
    final fileId = request.id ?? 'drive_file_${DateTime.now().microsecondsSinceEpoch}_${driveFiles.length}';
    final metadata = drive.File()
      ..id = fileId
      ..name = request.name
      ..mimeType = request.mimeType
      ..parents = request.parents
      ..size = uploadMedia?.length.toString()
      ..createdTime = DateTime.now();

    List<int> bytes = [];
    if (uploadMedia != null) {
      bytes = await uploadMedia.stream.expand((chunk) => chunk).toList();
    }

    driveFiles[fileId] = _FakeFileEntry(metadata, bytes);
    return metadata;
  }

  Future<drive.File> _update(drive.File request, String fileId, drive.Media? uploadMedia) async {
    final existing = driveFiles[fileId];
    if (existing == null) {
      throw Exception('File not found in Drive: $fileId');
    }

    final metadata = existing.metadata
      ..name = request.name ?? existing.metadata.name
      ..parents = request.parents ?? existing.metadata.parents
      ..mimeType = request.mimeType ?? existing.metadata.mimeType;

    List<int> bytes = existing.bytes;
    if (uploadMedia != null) {
      bytes = await uploadMedia.stream.expand((chunk) => chunk).toList();
      metadata.size = bytes.length.toString();
    }

    driveFiles[fileId] = _FakeFileEntry(metadata, bytes);
    return metadata;
  }

  Future<Object> _get(String fileId, drive.DownloadOptions downloadOptions) async {
    final entry = driveFiles[fileId];
    if (entry == null) {
      throw Exception('File not found in Drive: $fileId');
    }

    if (downloadOptions == drive.DownloadOptions.fullMedia) {
      final stream = Stream.value(entry.bytes);
      return drive.Media(stream, entry.bytes.length);
    }

    return entry.metadata;
  }
}

// Fake implementation of SettingsRepository
class FakeSettingsRepository implements SettingsRepository {
  bool autoBackup = false;
  bool wifiOnly = true;
  bool deleteCloud = false;
  String? driveRoot;
  String? lastBackup;

  @override
  Future<bool> isAutoBackupEnabled() async => autoBackup;

  @override
  Future<void> setAutoBackupEnabled(bool enabled) async => autoBackup = enabled;

  @override
  Future<bool> isWifiOnlyBackup() async => wifiOnly;

  @override
  Future<void> setWifiOnlyBackup(bool wifiOnly) async => this.wifiOnly = wifiOnly;

  @override
  Future<bool> isDeleteCloudCopyEnabled() async => deleteCloud;

  @override
  Future<void> setDeleteCloudCopyEnabled(bool enabled) async => deleteCloud = enabled;

  @override
  Future<String?> getDriveRootFolderId() async => driveRoot;

  @override
  Future<void> setDriveRootFolderId(String? folderId) async => driveRoot = folderId;

  @override
  Future<String?> getLastBackupTime() async => lastBackup;

  @override
  Future<void> setLastBackupTime(String? timeStr) async => lastBackup = timeStr;

  String? themeMode = 'system';

  @override
  Future<String?> getThemeMode() async => themeMode;

  @override
  Future<void> setThemeMode(String mode) async => themeMode = mode;
}

// Fake implementation of AuthRepository
class FakeAuthRepository implements AuthRepository {
  String? token = 'fake_access_token';

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory baseTempDir;
  late Directory mockDocDir;
  late Directory mockTempDir;

  setUpAll(() {
    baseTempDir = Directory.systemTemp.createTempSync('video_journal_test_');
    mockDocDir = Directory(p.join(baseTempDir.path, 'documents'))..createSync();
    mockTempDir = Directory(p.join(baseTempDir.path, 'temp'))..createSync();

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getTemporaryPath':
        case 'getTemporaryDirectory':
          return mockTempDir.path;
        case 'getApplicationDocumentsPath':
        case 'getApplicationDocumentsDirectory':
          return mockDocDir.path;
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    if (await baseTempDir.exists()) {
      await baseTempDir.delete(recursive: true);
    }
  });

  late JournalDatabase database;
  late ProviderContainer container;
  late FakeSettingsRepository settingsRepository;
  late FakeAuthRepository authRepository;
  late FakeFilesResource fakeFilesResource;
  late FakeDriveApi fakeDriveApi;

  setUp(() async {
    // Recreate local directory sandboxes
    if (await mockDocDir.exists()) {
      await mockDocDir.delete(recursive: true);
    }
    await mockDocDir.create(recursive: true);

    if (await mockTempDir.exists()) {
      await mockTempDir.delete(recursive: true);
    }
    await mockTempDir.create(recursive: true);

    final dbFile = File(p.join(mockDocDir.path, 'journal.db'));
    database = JournalDatabase.forTesting(NativeDatabase(dbFile));
    settingsRepository = FakeSettingsRepository();
    authRepository = FakeAuthRepository();
    fakeFilesResource = FakeFilesResource();
    fakeDriveApi = FakeDriveApi(fakeFilesResource);

    container = ProviderContainer(
      overrides: [
        journalDatabaseProvider.overrideWithValue(database),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
  });

  tearDown(() async {
    await database.close();
    container.dispose();
  });

  group('Automated Data Integrity Tests', () {
    test('Test 1: Local Soft-Delete marks record and deletes local files', () async {
      final repository = container.read(journalRepositoryProvider);
      final controller = container.read(journalControllerProvider.notifier);

      // Create local file
      final mediaDir = Directory(p.join(mockDocDir.path, 'media'))..createSync();
      final localFile = File(p.join(mediaDir.path, 'test_media.png'));
      localFile.writeAsStringSync('Hello Visual Journal');
      expect(localFile.existsSync(), isTrue);

      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: localFile.path,
        thumbnailPath: localFile.path,
        autoTag: '26-06-12-06-00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash_hello_123',
        isDeleted: false,
      );

      await repository.saveAsset(asset);

      // Verify asset exists in local listings
      var activeAssets = await repository.getAllAssets();
      expect(activeAssets.any((a) => a.id == assetId), isTrue);

      // Trigger soft delete from controller
      await controller.deleteAsset(assetId);

      // 1. Verify that database is updated with isDeleted = true and repository query excludes it
      activeAssets = await repository.getAllAssets();
      expect(activeAssets.any((a) => a.id == assetId), isFalse);

      final rawAsset = await (database.select(database.visualAssets)
            ..where((t) => t.id.equals(assetId)))
          .getSingleOrNull();
      expect(rawAsset, isNotNull);
      expect(rawAsset!.isDeleted, isTrue);

      // 2. Verify physical files are cleaned up from disk
      expect(localFile.existsSync(), isFalse);
    });

    test('Test 2: Backup uploads database and files to fake Google Drive', () async {
      final repository = container.read(journalRepositoryProvider);
      final backupManager = container.read(backupManagerProvider);

      // Create folder and unsynced file
      final folderId = const Uuid().v4();
      final folder = FolderData(
        id: folderId,
        name: 'Backup Folder',
        sequenceCounter: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveFolder(folder);

      final mediaDir = Directory(p.join(mockDocDir.path, 'media'))..createSync();
      final localFile = File(p.join(mediaDir.path, 'backup_item.png'));
      localFile.writeAsStringSync('Backup contents');

      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: localFile.path,
        thumbnailPath: localFile.path,
        folderId: folderId,
        autoTag: '#1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash_backup_item',
        isDeleted: false,
      );
      await repository.saveAsset(asset);

      // Run backup to fake root folder
      final rootFolderId = 'drive_root_folder_123';
      await backupManager.runBackup(
        accessToken: 'some_token',
        rootFolderId: rootFolderId,
        driveApi: fakeDriveApi,
      );

      // Verify files in fake Google Drive
      final driveFiles = fakeFilesResource.driveFiles.values.toList();
      
      // Should contain database backup and the media file
      expect(driveFiles.any((f) => f.metadata.name == 'journal_backup.db'), isTrue);
      expect(driveFiles.any((f) => f.metadata.name == 'backup_item.png'), isTrue);

      // Verify database record has been updated to synced and driveFileId is populated
      final updatedAsset = await repository.getAssetById(assetId);
      expect(updatedAsset, isNotNull);
      expect(updatedAsset!.syncStatus, SyncStatus.synced);
      expect(updatedAsset.driveFileId, isNotNull);
    });

    test('Test 3 (Scenario A): Restore skips record when file is missing from Google Drive', () async {
      final repository = container.read(journalRepositoryProvider);
      final backupManager = container.read(backupManagerProvider);
      final restoreManager = container.read(restoreManagerProvider);

      // Create folder and local file
      final folderId = const Uuid().v4();
      final folder = FolderData(
        id: folderId,
        name: 'Scenario A Folder',
        sequenceCounter: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveFolder(folder);

      final mediaDir = Directory(p.join(mockDocDir.path, 'media'))..createSync();
      final localFile = File(p.join(mediaDir.path, 'scenario_a.png'));
      localFile.writeAsStringSync('Scenario A data');

      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: localFile.path,
        thumbnailPath: localFile.path,
        folderId: folderId,
        autoTag: '#1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash_scenario_a',
        isDeleted: false,
      );
      await repository.saveAsset(asset);

      // Back up to fake Drive
      final rootFolderId = 'drive_root_folder_123';
      await backupManager.runBackup(
        accessToken: 'some_token',
        rootFolderId: rootFolderId,
        driveApi: fakeDriveApi,
      );

      final syncedAsset = await repository.getAssetById(assetId);
      final driveFileId = syncedAsset!.driveFileId!;

      // Verify it exists in fake drive
      expect(fakeFilesResource.driveFiles.containsKey(driveFileId), isTrue);

      // SIMULATE SCENARIO A:
      // 1. Delete the media file from Google Drive
      fakeFilesResource.driveFiles.remove(driveFileId);

      // 2. Delete the local media file
      await localFile.delete();
      expect(localFile.existsSync(), isFalse);

      // 3. Clear local storage and database to simulate clean install
      await database.close();
      final dbFile = File(p.join(mockDocDir.path, 'journal.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      database = JournalDatabase.forTesting(NativeDatabase(dbFile));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          journalDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );

      // Confirm local database is empty
      var emptyAssets = await container.read(journalRepositoryProvider).getAllAssets();
      expect(emptyAssets, isEmpty);

      // Run Restore
      await container.read(restoreManagerProvider).runRestore(
        accessToken: 'some_token',
        rootFolderId: rootFolderId,
        driveApi: fakeDriveApi,
      );

      // Verify that folder is restored, but the asset is skipped since its media file was missing from Drive
      final restoredFolders = await container.read(journalRepositoryProvider).getAllFolders();
      expect(restoredFolders.any((f) => f.id == folderId), isTrue);

      final restoredAssets = await container.read(journalRepositoryProvider).getAllAssets();
      expect(restoredAssets.any((a) => a.id == assetId), isFalse);

      final rawRestoredAsset = await (database.select(database.visualAssets)
            ..where((t) => t.id.equals(assetId)))
          .getSingleOrNull();
      expect(rawRestoredAsset, isNull);
    });

    test('Test 4 (Scenario B): Restore downloads file and undeletes record when file is present on Drive', () async {
      final repository = container.read(journalRepositoryProvider);
      final backupManager = container.read(backupManagerProvider);

      // Create folder and local file
      final folderId = const Uuid().v4();
      final folder = FolderData(
        id: folderId,
        name: 'Scenario B Folder',
        sequenceCounter: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveFolder(folder);

      final mediaDir = Directory(p.join(mockDocDir.path, 'media'))..createSync();
      final localFile = File(p.join(mediaDir.path, 'scenario_b.png'));
      localFile.writeAsStringSync('Scenario B data content');

      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: localFile.path,
        thumbnailPath: localFile.path,
        folderId: folderId,
        autoTag: '#1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash_scenario_b',
        isDeleted: false,
      );
      await repository.saveAsset(asset);

      // Back up to fake Drive
      final rootFolderId = 'drive_root_folder_123';
      await backupManager.runBackup(
        accessToken: 'some_token',
        rootFolderId: rootFolderId,
        driveApi: fakeDriveApi,
      );

      final syncedAsset = await repository.getAssetById(assetId);
      final driveFileId = syncedAsset!.driveFileId!;

      // Verify it exists in fake drive
      expect(fakeFilesResource.driveFiles.containsKey(driveFileId), isTrue);

      // SIMULATE SCENARIO B:
      // 1. Delete local file
      await localFile.delete();
      expect(localFile.existsSync(), isFalse);

      // 2. Clear local database to simulate clean install
      await database.close();
      final dbFile = File(p.join(mockDocDir.path, 'journal.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      database = JournalDatabase.forTesting(NativeDatabase(dbFile));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          journalDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );

      // Confirm local database is empty
      var emptyAssets = await container.read(journalRepositoryProvider).getAllAssets();
      expect(emptyAssets, isEmpty);

      // Run Restore
      await container.read(restoreManagerProvider).runRestore(
        accessToken: 'some_token',
        rootFolderId: rootFolderId,
        driveApi: fakeDriveApi,
      );

      // Verify asset record is restored, isDeleted is false, and the file is re-downloaded to disk
      final restoredAssets = await container.read(journalRepositoryProvider).getAllAssets();
      expect(restoredAssets.any((a) => a.id == assetId), isTrue);

      final restoredAsset = restoredAssets.firstWhere((a) => a.id == assetId);
      expect(restoredAsset.isDeleted, isFalse);
      expect(restoredAsset.syncStatus, SyncStatus.synced);

      final restoredFile = File(restoredAsset.localPath);
      expect(restoredFile.existsSync(), isTrue);
      expect(restoredFile.readAsStringSync(), 'Scenario B data content');
    });
  });
}
