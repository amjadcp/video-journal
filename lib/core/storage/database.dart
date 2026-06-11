import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_journal/shared/enums/enums.dart';

part 'database.g.dart';

@DataClassName('VisualAssetData')
class VisualAssets extends Table {
  TextColumn get id => text()();
  TextColumn get assetType => textEnum<AssetType>()();
  TextColumn get localPath => text()();
  TextColumn get thumbnailPath => text()();
  TextColumn get folderId => text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  TextColumn get autoTag => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => textEnum<SyncStatus>()();
  TextColumn get driveFileId => text().nullable()();
  TextColumn get assetHash => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FolderData')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sequenceCounter => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagData')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get visualAssetId => text().references(VisualAssets, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [VisualAssets, Folders, Tags])
class JournalDatabase extends _$JournalDatabase {
  JournalDatabase() : super(_openConnection());

  JournalDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Enable foreign keys in SQLite (important for cascade deletes)
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'journal.db'));
    return NativeDatabase.createInBackground(file);
  });
}
