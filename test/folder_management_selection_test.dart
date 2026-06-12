import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/journal/data/journal_repository_impl.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';
import 'package:video_journal/features/journal/presentation/selection_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

void main() {
  group('SelectionController Unit Tests', () {
    test('Initial selection state is inactive and empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(selectionProvider);
      expect(state.isSelectionMode, isFalse);
      expect(state.selectedAssetIds, isEmpty);
    });

    test('Entering selection mode sets state active and contains asset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(selectionProvider.notifier);
      notifier.enterSelectionMode('asset-1');

      final state = container.read(selectionProvider);
      expect(state.isSelectionMode, isTrue);
      expect(state.selectedAssetIds, contains('asset-1'));
    });

    test('Toggling selection adds/removes items and exits mode when empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(selectionProvider.notifier);
      notifier.enterSelectionMode('asset-1');
      notifier.toggleSelection('asset-2');

      var state = container.read(selectionProvider);
      expect(state.selectedAssetIds, containsAll(['asset-1', 'asset-2']));

      notifier.toggleSelection('asset-1');
      state = container.read(selectionProvider);
      expect(state.selectedAssetIds, contains('asset-2'));
      expect(state.selectedAssetIds, isNot(contains('asset-1')));
      expect(state.isSelectionMode, isTrue);

      notifier.toggleSelection('asset-2');
      state = container.read(selectionProvider);
      expect(state.isSelectionMode, isFalse);
      expect(state.selectedAssetIds, isEmpty);
    });

    test('selectAll selects all provided IDs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(selectionProvider.notifier);
      notifier.selectAll(['asset-1', 'asset-2', 'asset-3']);

      final state = container.read(selectionProvider);
      expect(state.isSelectionMode, isTrue);
      expect(state.selectedAssetIds, hasLength(3));
      expect(state.selectedAssetIds, containsAll(['asset-1', 'asset-2', 'asset-3']));
    });
  });

  group('Folders and Journal Controllers Integration Tests', () {
    late JournalDatabase database;
    late ProviderContainer container;

    setUp(() {
      database = JournalDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          journalDatabaseProvider.overrideWithValue(database),
          journalRepositoryProvider.overrideWithValue(JournalRepositoryImpl(database)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('Folder rename updates folder list', () async {
      final foldersNotifier = container.read(foldersControllerProvider.notifier);
      final folder = await foldersNotifier.createFolder('Old Name');

      var folders = container.read(foldersControllerProvider).valueOrNull;
      expect(folders, isNotNull);
      expect(folders!.first.name, 'Old Name');

      await foldersNotifier.renameFolder(folder.id, 'New Name');
      folders = container.read(foldersControllerProvider).valueOrNull;
      expect(folders!.first.name, 'New Name');
    });

    test('Folder delete deletes folder and nullifies assets folderIds', () async {
      final foldersNotifier = container.read(foldersControllerProvider.notifier);
      final folder = await foldersNotifier.createFolder('Trip');

      final journalNotifier = container.read(journalControllerProvider.notifier);
      await journalNotifier.saveAssetToFolder(
        mediaPath: 'dummy_photo.png',
        type: AssetType.photo,
        folderId: folder.id,
      );

      var assets = container.read(journalControllerProvider).valueOrNull;
      expect(assets, isNotNull);
      expect(assets!.first.folderId, folder.id);

      // Delete folder
      await foldersNotifier.deleteFolder(folder.id);

      final folders = container.read(foldersControllerProvider).valueOrNull;
      expect(folders, isEmpty);

      // Verify asset folderId is set to null
      assets = container.read(journalControllerProvider).valueOrNull;
      expect(assets, isNotNull);
      expect(assets!.first.folderId, isNull);
    });

    test('Mass move assets to folder increments sequence counter and updates tags', () async {
      final foldersNotifier = container.read(foldersControllerProvider.notifier);
      final folder = await foldersNotifier.createFolder('Trip');

      final journalNotifier = container.read(journalControllerProvider.notifier);
      await journalNotifier.saveAssetToHomeList(
        mediaPath: 'img1.png',
        type: AssetType.photo,
      );
      await journalNotifier.saveAssetToHomeList(
        mediaPath: 'img2.png',
        type: AssetType.photo,
      );

      var assets = container.read(journalControllerProvider).valueOrNull;
      expect(assets, hasLength(2));
      expect(assets![0].folderId, isNull);
      expect(assets![1].folderId, isNull);

      final assetIds = assets.map((a) => a.id).toList();

      // Perform mass move to folder
      await journalNotifier.moveAssetsToFolder(assetIds, folder.id);

      // Check folder updated
      final updatedFolder = await database.select(database.folders).getSingle();
      expect(updatedFolder.sequenceCounter, 2);

      // Check assets updated
      final updatedAssets = container.read(journalControllerProvider).valueOrNull!;
      expect(updatedAssets[0].folderId, folder.id);
      expect(updatedAssets[1].folderId, folder.id);
      expect(updatedAssets.map((a) => a.autoTag), containsAll(['#1', '#2']));
    });
  });
}
