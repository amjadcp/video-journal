import 'package:video_journal/core/storage/database.dart';

abstract class JournalRepository {
  // Visual Asset Operations
  Future<List<VisualAssetData>> getAllAssets();
  Future<VisualAssetData?> getAssetById(String id);
  Future<void> saveAsset(VisualAssetData asset);
  Future<void> updateAsset(VisualAssetData asset);
  Future<void> deleteAsset(String id);
  Future<List<VisualAssetData>> getAssetsInFolder(String folderId);

  // Folder Operations
  Future<List<FolderData>> getAllFolders();
  Future<FolderData?> getFolderById(String id);
  Future<void> saveFolder(FolderData folder);
  Future<void> updateFolder(FolderData folder);
  Future<void> deleteFolder(String id);
  Future<void> incrementFolderSequence(String folderId);

  // Tag Operations
  Future<List<TagData>> getAllTags();
  Future<List<TagData>> getTagsForAsset(String assetId);
  Future<void> addTag(TagData tag);
  Future<void> deleteTag(String tagId);
  Future<void> updateTag(String tagId, String newName);
  Future<List<VisualAssetData>> searchAssetsByTag(String tagName);
}
