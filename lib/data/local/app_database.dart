import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The columns every synced table has.
///
/// Timestamps are kept as text (ISO 8601, UTC) because that is how PowerSync
/// stores them on the device.
mixin SyncColumns on Table {
  /// UUID made on the device.
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get createdAt => text()();

  /// The device time is only a placeholder. The server replaces it with its
  /// own time when the row is uploaded.
  TextColumn get updatedAt => text()();

  /// Set when the row is deleted (soft delete), so other devices learn of it.
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// M0 test table. It exists only to prove that sign-in and sync work.
@DataClassName('SyncTestRow')
class SyncTestRows extends Table with SyncColumns {
  @override
  String get tableName => 'sync_test';

  /// The SQL column is called `text`. It is named `body` in Dart because
  /// `text` is already the name of Drift's column builder.
  TextColumn get body => text().named('text')();
}

/// A part of life the user looks after, for example Health or Career.
@DataClassName('LifeArea')
class LifeAreas extends Table with SyncColumns {
  @override
  String get tableName => 'life_areas';

  TextColumn get name => text()();

  /// A colour name from `AreaColors`, for example `green`.
  TextColumn get color => text()();

  /// An icon name from `ItemIcons`. Empty when the user picked none; the
  /// app then shows a coloured dot.
  TextColumn get icon => text().nullable()();
}

/// Something the user wants to reach. It may belong to one life area.
@DataClassName('Goal')
class Goals extends Table with SyncColumns {
  @override
  String get tableName => 'goals';

  TextColumn get title => text()();
  TextColumn get lifeAreaId => text().nullable()();

  /// A day as `YYYY-MM-DD`.
  TextColumn get targetDate => text().nullable()();

  /// One sign that tells the user the goal is reached.
  TextColumn get doneWhen => text().nullable()();

  /// 0 to 100, set by the user.
  IntColumn get progress => integer()();

  /// A colour name from `GoalColors`. Empty on rows made before goals had
  /// a colour; the app then uses the fallback colour.
  TextColumn get color => text().nullable()();

  /// An icon name from `ItemIcons`. Empty means the flag icon.
  TextColumn get icon => text().nullable()();
}

/// A group of tasks. It may serve one goal.
@DataClassName('Project')
class Projects extends Table with SyncColumns {
  @override
  String get tableName => 'projects';

  TextColumn get name => text()();
  TextColumn get goalId => text().nullable()();

  /// A colour name from `ProjectColors`, for example `blue`. Never orange:
  /// orange means "now".
  TextColumn get color => text()();

  /// An icon name from `ItemIcons`, for example `folder`. Empty on rows
  /// made before icons existed; the app then shows the folder.
  TextColumn get icon => text().nullable()();
}

/// One thing to do. It may belong to a project. The project serves the
/// goal; the `goalId` column is no longer written by the app.
@DataClassName('Task')
class Tasks extends Table with SyncColumns {
  @override
  String get tableName => 'tasks';

  TextColumn get title => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get goalId => text().nullable()();

  /// A day as `YYYY-MM-DD`.
  TextColumn get dueDate => text().nullable()();

  /// One of `TaskPriority`: `none`, `medium`, `high`.
  TextColumn get priority => text()();

  /// One of `TaskStatus`: `open`, `done`.
  TextColumn get status => text()();

  /// When the task was completed (ISO 8601, UTC). Empty while it is open.
  TextColumn get completedAt => text().nullable()();

  /// Free text the user writes about this task. Empty when there is none.
  TextColumn get notes => text().nullable()();
}

/// The values the `priority` column of a task may hold.
abstract final class TaskPriority {
  static const none = 'none';
  static const medium = 'medium';
  static const high = 'high';
  static const all = [none, medium, high];
}

/// The values the `status` column of a task may hold.
abstract final class TaskStatus {
  static const open = 'open';
  static const done = 'done';
}

@DriftDatabase(tables: [SyncTestRows, LifeAreas, Goals, Projects, Tasks])
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
