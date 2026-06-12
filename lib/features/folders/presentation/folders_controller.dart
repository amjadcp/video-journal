import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/journal/presentation/journal_controller.dart';

class FoldersController extends StateNotifier<AsyncValue<List<FolderData>>> {
  final Ref _ref;

  FoldersController(this._ref) : super(const AsyncValue.loading()) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    try {
      final repo = _ref.read(journalRepositoryProvider);
      final folders = await repo.getAllFolders();
      state = AsyncValue.data(folders);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<FolderData> createFolder(String name) async {
    final repo = _ref.read(journalRepositoryProvider);
    final newFolder = FolderData(
      id: const Uuid().v4(),
      name: name,
      sequenceCounter: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.saveFolder(newFolder);
    await loadFolders();
    return newFolder;
  }

  Future<void> renameFolder(String id, String newName) async {
    final repo = _ref.read(journalRepositoryProvider);
    final folder = await repo.getFolderById(id);
    if (folder == null) return;
    final updated = folder.copyWith(name: newName, updatedAt: DateTime.now());
    await repo.updateFolder(updated);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    final repo = _ref.read(journalRepositoryProvider);
    await repo.deleteFolder(id);
    await loadFolders();
    // Refresh the journal assets because folderId was set to null on database cascade
    await _ref.read(journalControllerProvider.notifier).loadAssets();
  }
}

final foldersControllerProvider = StateNotifierProvider<FoldersController, AsyncValue<List<FolderData>>>((ref) {
  return FoldersController(ref);
});
