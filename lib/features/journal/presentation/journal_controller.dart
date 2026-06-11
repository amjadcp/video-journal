import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/shared/enums/enums.dart';

class JournalController extends StateNotifier<AsyncValue<List<VisualAssetData>>> {
  final Ref _ref;

  JournalController(this._ref) : super(const AsyncValue.loading()) {
    loadAssets();
  }

  Future<void> loadAssets() async {
    try {
      final repo = _ref.read(journalRepositoryProvider);
      final assets = await repo.getAllAssets();
      state = AsyncValue.data(assets);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<String> _calculateFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> saveAssetToHomeList({
    required String mediaPath,
    required AssetType type,
  }) async {
    final repo = _ref.read(journalRepositoryProvider);
    final hash = await _calculateFileHash(mediaPath);
    final autoTag = DateFormat('yy-MM-dd-HH-mm').format(DateTime.now());

    final asset = VisualAssetData(
      id: const Uuid().v4(),
      assetType: type,
      localPath: mediaPath,
      thumbnailPath: mediaPath, // For simple MVP, using main media path as thumbnail
      autoTag: autoTag,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.notBackedUp,
      assetHash: hash,
    );

    await repo.saveAsset(asset);
    await loadAssets();
  }

  Future<void> saveAssetToFolder({
    required String mediaPath,
    required AssetType type,
    required String folderId,
  }) async {
    final repo = _ref.read(journalRepositoryProvider);
    final hash = await _calculateFileHash(mediaPath);

    // Fetch current sequence number and increment it
    final folder = await repo.getFolderById(folderId);
    if (folder == null) return;

    final nextSequence = folder.sequenceCounter + 1;
    await repo.incrementFolderSequence(folderId);

    // Apply the sequence tag (e.g. #1, #2...)
    final autoTag = '#$nextSequence';

    final asset = VisualAssetData(
      id: const Uuid().v4(),
      assetType: type,
      localPath: mediaPath,
      thumbnailPath: mediaPath,
      folderId: folderId,
      autoTag: autoTag,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.notBackedUp,
      assetHash: hash,
    );

    await repo.saveAsset(asset);
    
    // Refresh folder list state and main assets state
    _ref.read(foldersControllerProvider.notifier).loadFolders();
    await loadAssets();
  }

  Future<void> deleteAsset(String assetId) async {
    final repo = _ref.read(journalRepositoryProvider);
    await repo.deleteAsset(assetId);
    await loadAssets();
  }
}

final journalControllerProvider = StateNotifierProvider<JournalController, AsyncValue<List<VisualAssetData>>>((ref) {
  return JournalController(ref);
});
