import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';

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
}

final foldersControllerProvider = StateNotifierProvider<FoldersController, AsyncValue<List<FolderData>>>((ref) {
  return FoldersController(ref);
});
