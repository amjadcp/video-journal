import 'package:drift/drift.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/journal/domain/journal_repository.dart';

class JournalRepositoryImpl implements JournalRepository {
  final JournalDatabase _db;

  JournalRepositoryImpl(this._db);

  @override
  Future<List<VisualAssetData>> getAllAssets() {
    return (_db.select(_db.visualAssets)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  @override
  Future<VisualAssetData?> getAssetById(String id) {
    return (_db.select(_db.visualAssets)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  @override
  Future<void> saveAsset(VisualAssetData asset) {
    return _db.into(_db.visualAssets).insert(asset, mode: InsertMode.insertOrReplace);
  }

  @override
  Future<void> updateAsset(VisualAssetData asset) {
    return _db.update(_db.visualAssets).replace(asset);
  }

  @override
  Future<void> deleteAsset(String id) async {
    await (_db.update(_db.visualAssets)..where((t) => t.id.equals(id)))
        .write(const VisualAssetsCompanion(isDeleted: Value(true)));
  }

  @override
  Future<List<VisualAssetData>> getAssetsInFolder(String folderId) {
    return (_db.select(_db.visualAssets)
          ..where((t) => t.folderId.equals(folderId) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  @override
  Future<List<FolderData>> getAllFolders() {
    return (_db.select(_db.folders)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  @override
  Future<FolderData?> getFolderById(String id) {
    return (_db.select(_db.folders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<void> saveFolder(FolderData folder) {
    return _db.into(_db.folders).insert(folder, mode: InsertMode.insertOrReplace);
  }

  @override
  Future<void> updateFolder(FolderData folder) {
    return _db.update(_db.folders).replace(folder);
  }

  @override
  Future<void> deleteFolder(String id) async {
    await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> incrementFolderSequence(String folderId) async {
    await _db.customUpdate(
      'UPDATE folders SET sequence_counter = sequence_counter + 1, updated_at = ? WHERE id = ?',
      variables: [Variable(DateTime.now()), Variable(folderId)],
    );
  }

  @override
  Future<List<TagData>> getAllTags() {
    return _db.select(_db.tags).get();
  }

  @override
  Future<List<TagData>> getTagsForAsset(String assetId) {
    return (_db.select(_db.tags)..where((t) => t.visualAssetId.equals(assetId))).get();
  }

  @override
  Future<void> addTag(TagData tag) {
    return _db.into(_db.tags).insert(tag, mode: InsertMode.insertOrReplace);
  }

  @override
  Future<void> deleteTag(String tagId) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(tagId))).go();
  }

  @override
  Future<void> updateTag(String tagId, String newName) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tagId))).write(
      TagsCompanion(
        name: Value(newName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<List<VisualAssetData>> searchAssetsByTag(String tagName) async {
    final query = _db.select(_db.visualAssets).join([
      leftOuterJoin(_db.tags, _db.tags.visualAssetId.equalsExp(_db.visualAssets.id)),
    ])
      ..where(
        (_db.visualAssets.autoTag.lower().equals(tagName) | _db.tags.name.equals(tagName))
        & _db.visualAssets.isDeleted.equals(false)
      )
      ..orderBy([OrderingTerm(expression: _db.visualAssets.createdAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    final Map<String, VisualAssetData> assetMap = {};
    for (final row in rows) {
      final asset = row.readTable(_db.visualAssets);
      assetMap[asset.id] = asset;
    }
    return assetMap.values.toList();
  }
}
