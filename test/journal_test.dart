import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/journal/data/journal_repository_impl.dart';
import 'package:video_journal/shared/enums/enums.dart';

void main() {
  late JournalDatabase database;
  late JournalRepositoryImpl repository;

  setUp(() {
    database = JournalDatabase.forTesting(NativeDatabase.memory());
    repository = JournalRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Drift Local Database & Repository Tests', () {
    test('Initial database is empty', () async {
      final assets = await repository.getAllAssets();
      final folders = await repository.getAllFolders();
      expect(assets, isEmpty);
      expect(folders, isEmpty);
    });

    test('Create folder successfully and check sequencing', () async {
      final folderId = const Uuid().v4();
      final folder = FolderData(
        id: folderId,
        name: 'Vacation 2026',
        sequenceCounter: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveFolder(folder);

      final folders = await repository.getAllFolders();
      expect(folders, hasLength(1));
      expect(folders.first.name, 'Vacation 2026');
      expect(folders.first.sequenceCounter, 0);

      // Increment sequence
      await repository.incrementFolderSequence(folderId);
      final updatedFolder = await repository.getFolderById(folderId);
      expect(updatedFolder?.sequenceCounter, 1);
    });

    test('Add visual asset to folder and check auto tagging integrity', () async {
      final folderId = const Uuid().v4();
      final folder = FolderData(
        id: folderId,
        name: 'Daily Logs',
        sequenceCounter: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveFolder(folder);
      await repository.incrementFolderSequence(folderId);

      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: '/data/user/0/com.antigravity.video_journal/files/pic.png',
        thumbnailPath: '/data/user/0/com.antigravity.video_journal/files/pic.png',
        folderId: folderId,
        autoTag: '#1', // First folder item auto tag
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash123',
      );

      await repository.saveAsset(asset);

      final retrieved = await repository.getAssetById(assetId);
      expect(retrieved, isNotNull);
      expect(retrieved!.autoTag, '#1');
      expect(retrieved.folderId, folderId);
      expect(retrieved.syncStatus, SyncStatus.notBackedUp);
    });

    test('Tag association CRUD operations', () async {
      final assetId = const Uuid().v4();
      final asset = VisualAssetData(
        id: assetId,
        assetType: AssetType.photo,
        localPath: 'some_path.png',
        thumbnailPath: 'some_path.png',
        autoTag: '26-06-12-02-20',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.notBackedUp,
        assetHash: 'hash456',
      );

      await repository.saveAsset(asset);

      // Add tag
      final tagId = const Uuid().v4();
      final tag = TagData(
        id: tagId,
        visualAssetId: assetId,
        name: 'sunset',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.addTag(tag);

      final tags = await repository.getTagsForAsset(assetId);
      expect(tags, hasLength(1));
      expect(tags.first.name, 'sunset');

      // Update tag
      await repository.updateTag(tagId, 'sunrise');
      final updatedTags = await repository.getTagsForAsset(assetId);
      expect(updatedTags.first.name, 'sunrise');

      // Search by tag
      final searchResult = await repository.searchAssetsByTag('sunrise');
      expect(searchResult, hasLength(1));
      expect(searchResult.first.id, assetId);

      // Delete tag
      await repository.deleteTag(tagId);
      final emptyTags = await repository.getTagsForAsset(assetId);
      expect(emptyTags, isEmpty);
    });
  });
}
