import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// Reads and writes tasks. It only ever touches the local database. Sync
/// copies the changes to the server in the background.
class TaskRepository {
  TaskRepository(this._db, {required this._newId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  static String _title(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'title', 'Must not be empty');
    }
    return trimmed;
  }

  static String _priority(String value) {
    if (!TaskPriority.all.contains(value)) {
      throw ArgumentError.value(value, 'priority', 'Unknown priority');
    }
    return value;
  }

  /// All of the user's tasks, open and done, oldest first. Deleted ones are
  /// left out. The Tasks page filters, sorts and groups them.
  Stream<List<Task>> watchTasks(String userId) {
    final query = _db.select(_db.tasks)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  /// Saves a new open task and returns its id. [dueDate] is `YYYY-MM-DD`.
  /// A task serves a project only; the project serves the goal.
  Future<String> addTask({
    required String userId,
    required String title,
    String? projectId,
    String? dueDate,
    String? dueTime,
    String priority = TaskPriority.none,
  }) async {
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            userId: userId,
            title: _title(title),
            projectId: Value(projectId),
            dueDate: Value(dueDate),
            dueTime: Value(dueDate == null ? null : dueTime),
            priority: _priority(priority),
            status: TaskStatus.open,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateTask(
    String id, {
    required String title,
    required String? projectId,
    required String? dueDate,
    required String priority,
    String? notes,
  }) {
    // Notes: null keeps the saved notes, an empty text removes them.
    final trimmedNotes = notes?.trim();
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(
        title: Value(_title(title)),
        projectId: Value(projectId),
        dueDate: Value(dueDate),
        // Without a day the time means nothing, so it goes too.
        dueTime: dueDate == null ? const Value(null) : const Value.absent(),
        priority: Value(_priority(priority)),
        notes: trimmedNotes == null
            ? const Value.absent()
            : Value(trimmedNotes.isEmpty ? null : trimmedNotes),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Puts a task on [day], at [time] (`HH:MM`) or at no set time (null).
  /// The Calendar page uses this when a task is dragged.
  Future<void> scheduleTask(
    String id, {
    required String day,
    required String? time,
  }) {
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(
        dueDate: Value(day),
        dueTime: Value(time),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// How long a task with a time takes on the Calendar, in minutes (at
  /// least 15).
  Future<void> setTaskDuration(String id, int minutes) {
    if (minutes < 15) {
      throw ArgumentError.value(minutes, 'minutes', 'At least 15 minutes');
    }
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(
        durationMinutes: Value(minutes),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Takes a task off the calendar: no date and no time.
  Future<void> unscheduleTask(String id) {
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(
        dueDate: const Value(null),
        dueTime: const Value(null),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Marks a task done, or open again. The completion time is kept so the
  /// chart can count tasks completed per day.
  Future<void> setDone(String id, {required bool done}) {
    final timestamp = _timestamp();
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(
        status: Value(done ? TaskStatus.done : TaskStatus.open),
        completedAt: Value(done ? timestamp : null),
        updatedAt: Value(timestamp),
      ),
    );
  }

  /// Soft delete: the row is marked, so other devices learn of it.
  Future<void> deleteTask(String id) {
    final timestamp = _timestamp();
    return (_db.update(_db.tasks)..where((row) => row.id.equals(id))).write(
      TasksCompanion(deletedAt: Value(timestamp), updatedAt: Value(timestamp)),
    );
  }
}
