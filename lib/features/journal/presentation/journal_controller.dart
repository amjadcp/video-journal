import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_journal/app/dependency_injection/providers.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/folders/presentation/folders_controller.dart';
import 'package:video_journal/features/sync/data/drive_service.dart';
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
    String? caption,
  }) async {
    final repo = _ref.read(journalRepositoryProvider);
    final hash = await _calculateFileHash(mediaPath);
    final autoTag = DateFormat('yy-MM-dd-HH-mm').format(DateTime.now());
    final assetId = const Uuid().v4();

    final asset = VisualAssetData(
      id: assetId,
      assetType: type,
      localPath: mediaPath,
      thumbnailPath: mediaPath, // For simple MVP, using main media path as thumbnail
      autoTag: autoTag,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.notBackedUp,
      assetHash: hash,
      isDeleted: false,
    );

    await repo.saveAsset(asset);

    if (caption != null && caption.trim().isNotEmpty) {
      final tag = TagData(
        id: const Uuid().v4(),
        visualAssetId: assetId,
        name: caption.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.addTag(tag);
      _ref.invalidate(firstTagsProvider);
    }

    await loadAssets();
  }

  Future<void> saveAssetToFolder({
    required String mediaPath,
    required AssetType type,
    required String folderId,
    String? caption,
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
    final assetId = const Uuid().v4();

    final asset = VisualAssetData(
      id: assetId,
      assetType: type,
      localPath: mediaPath,
      thumbnailPath: mediaPath,
      folderId: folderId,
      autoTag: autoTag,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.notBackedUp,
      assetHash: hash,
      isDeleted: false,
    );

    await repo.saveAsset(asset);

    if (caption != null && caption.trim().isNotEmpty) {
      final tag = TagData(
        id: const Uuid().v4(),
        visualAssetId: assetId,
        name: caption.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.addTag(tag);
      _ref.invalidate(firstTagsProvider);
    }
    
    // Refresh folder list state and main assets state
    _ref.read(foldersControllerProvider.notifier).loadFolders();
    await loadAssets();
  }

  Future<void> deleteAsset(String assetId) async {
    final repo = _ref.read(journalRepositoryProvider);
    
    // Retrieve the asset before soft-deleting it so we have its paths and driveFileId
    final asset = await repo.getAssetById(assetId);
    
    // Soft-delete local entry in the database
    await repo.deleteAsset(assetId);

    if (asset != null) {
      // 1. Delete local physical files from disk
      try {
        final localFile = File(asset.localPath);
        if (await localFile.exists()) {
          await localFile.delete();
        }
        final thumbFile = File(asset.thumbnailPath);
        if (await thumbFile.exists() && asset.thumbnailPath != asset.localPath) {
          await thumbFile.delete();
        }
      } catch (e) {
        // Silence filesystem deletion errors so database deletion remains robust
      }

      // 2. If the asset is backed up to Drive, delete it if enabled
      if (asset.driveFileId != null) {
        final settingsRepo = _ref.read(settingsRepositoryProvider);
        final deleteCloud = await settingsRepo.isDeleteCloudCopyEnabled();
        
        if (deleteCloud) {
          final authRepo = _ref.read(authRepositoryProvider);
          final token = await authRepo.getAccessToken();
          if (token != null) {
            try {
              final api = DriveService.getDriveApi(token);
              await api.files.delete(asset.driveFileId!);
            } catch (e) {
              // Silence cloud deletion errors
            }
          }
        }
      }
    }
    
    await loadAssets();
  }

  Future<void> deleteAssets(List<String> assetIds) async {
    final repo = _ref.read(journalRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final authRepo = _ref.read(authRepositoryProvider);
    
    final deleteCloud = await settingsRepo.isDeleteCloudCopyEnabled();
    final token = await authRepo.getAccessToken();
    final api = token != null ? DriveService.getDriveApi(token) : null;

    for (final id in assetIds) {
      final asset = await repo.getAssetById(id);
      await repo.deleteAsset(id);

      if (asset != null) {
        try {
          final localFile = File(asset.localPath);
          if (await localFile.exists()) {
            await localFile.delete();
          }
          final thumbFile = File(asset.thumbnailPath);
          if (await thumbFile.exists() && asset.thumbnailPath != asset.localPath) {
            await thumbFile.delete();
          }
        } catch (_) {}

        if (asset.driveFileId != null && deleteCloud && api != null) {
          try {
            await api.files.delete(asset.driveFileId!);
          } catch (_) {}
        }
      }
    }

    await loadAssets();
    _ref.read(foldersControllerProvider.notifier).loadFolders();
  }

  Future<void> moveAssetsToFolder(List<String> assetIds, String? folderId) async {
    final repo = _ref.read(journalRepositoryProvider);

    if (folderId == null) {
      // Move to Home Journal
      for (final id in assetIds) {
        final asset = await repo.getAssetById(id);
        if (asset != null) {
          final autoTag = DateFormat('yy-MM-dd-HH-mm').format(DateTime.now());
          final updated = asset.copyWith(
            folderId: const Value(null),
            autoTag: autoTag,
            updatedAt: DateTime.now(),
          );
          await repo.updateAsset(updated);
        }
      }
    } else {
      // Move to specified folder
      final folder = await repo.getFolderById(folderId);
      if (folder == null) return;

      var currentSequence = folder.sequenceCounter;

      for (final id in assetIds) {
        final asset = await repo.getAssetById(id);
        if (asset != null) {
          currentSequence++;
          await repo.incrementFolderSequence(folderId);
          final autoTag = '#$currentSequence';
          final updated = asset.copyWith(
            folderId: Value(folderId),
            autoTag: autoTag,
            updatedAt: DateTime.now(),
          );
          await repo.updateAsset(updated);
        }
      }
    }

    await loadAssets();
    _ref.read(foldersControllerProvider.notifier).loadFolders();
  }
}

final journalControllerProvider = StateNotifierProvider<JournalController, AsyncValue<List<VisualAssetData>>>((ref) {
  return JournalController(ref);
});

final firstTagsProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(journalRepositoryProvider);
  final tags = await repo.getAllTags();
  final Map<String, String> firstTags = {};
  for (final tag in tags) {
    if (!firstTags.containsKey(tag.visualAssetId)) {
      firstTags[tag.visualAssetId] = tag.name;
    }
  }
  return firstTags;
});
