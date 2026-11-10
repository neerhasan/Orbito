import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// M0 test table. It exists only to prove that sign-in and sync work.
///
/// Timestamps are kept as text (ISO 8601, UTC) because that is how PowerSync
/// stores them on the device.
@DataClassName('SyncTestRow')
class SyncTestRows extends Table {
  @override
  String get tableName => 'sync_test';

  /// UUID made on the device.
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// The SQL column is called `text`. It is named `body` in Dart because
  /// `text` is already the name of Drift's column builder.
  TextColumn get body => text().named('text')();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  /// Set when the row is deleted (soft delete), so other devices learn of it.
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [SyncTestRows])
class AppDatabase extends _$AppDatabase {
  /// In the app, PowerSync creates and owns the tables, so Drift must not
  /// create them. Tests pass `tablesManagedBySync: false` to get plain tables
  /// in an in-memory database.
  AppDatabase(super.e, {this.tablesManagedBySync = true});

  final bool tablesManagedBySync;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      if (!tablesManagedBySync) await m.createAll();
    },
  );
}
