import 'package:drift/drift.dart';

import '../../domain/habits.dart' show allDays;
import '../local/app_database.dart';

/// Reads and writes habits and their daily marks. It only ever touches the
/// local database. Sync copies the changes to the server in the background.
class HabitRepository {
  HabitRepository(
    this._db, {
    required this._newId,
    required this._stableId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;

  /// The same id for the same text on every device. A habit's mark for a
  /// day gets its id from the habit and the day, so two devices marking the
  /// same day write the same row.
  final String Function(String key) _stableId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  static String _name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Must not be empty');
    }
    return trimmed;
  }

  /// The weekday digits, sorted and without repeats. At least one day.
  static String _days(String value) {
    final digits = value.split('').where(allDays.contains).toSet().toList()
      ..sort();
    if (digits.isEmpty) {
      throw ArgumentError.value(value, 'days', 'Pick at least one day');
    }
    return digits.join();
  }

  static String? _time(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The user's habits, oldest first. Deleted ones are left out.
  Stream<List<Habit>> watchHabits(String userId) {
    final query = _db.select(_db.habits)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch();
  }

  /// All of the user's habit marks. Removed ones are left out.
  Stream<List<HabitLog>> watchLogs(String userId) {
    final query = _db.select(_db.habitLogs)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
    return query.watch();
  }

  Future<String> addHabit({
    required String userId,
    required String name,
    String? lifeAreaId,
    String? usualTime,
    String days = allDays,
  }) async {
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.habits)
        .insert(
          HabitsCompanion.insert(
            id: id,
            userId: userId,
            name: _name(name),
            lifeAreaId: Value(lifeAreaId),
            usualTime: Value(_time(usualTime)),
            days: _days(days),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateHabit(
    String id, {
    required String name,
    required String? lifeAreaId,
    required String? usualTime,
    required String days,
  }) {
    return (_db.update(_db.habits)..where((row) => row.id.equals(id))).write(
      HabitsCompanion(
        name: Value(_name(name)),
        lifeAreaId: Value(lifeAreaId),
        usualTime: Value(_time(usualTime)),
        days: Value(_days(days)),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Deletes the habit and its history (soft delete, so other devices
  /// learn of it).
  Future<void> deleteHabit(String id) {
    return _db.transaction(() async {
      final timestamp = _timestamp();
      await (_db.update(
        _db.habitLogs,
      )..where((row) => row.habitId.equals(id) & row.deletedAt.isNull())).write(
        HabitLogsCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
      await (_db.update(_db.habits)..where((row) => row.id.equals(id))).write(
        HabitsCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }

  /// Marks [day] (`YYYY-MM-DD`) as `done` or `skip`, or clears the mark
  /// when [status] is null.
  Future<void> setMark({
    required String userId,
    required String habitId,
    required String day,
    required String? status,
  }) {
    if (status != null &&
        status != HabitMark.done &&
        status != HabitMark.skip) {
      throw ArgumentError.value(status, 'status', 'Unknown mark');
    }
    final id = _stableId('habit-log:$habitId:$day');
    return _db.transaction(() async {
      final timestamp = _timestamp();
      final existing = await (_db.select(
        _db.habitLogs,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        if (status == null) return;
        await _db
            .into(_db.habitLogs)
            .insert(
              HabitLogsCompanion.insert(
                id: id,
                userId: userId,
                habitId: habitId,
                day: day,
                status: status,
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
        return;
      }
      await (_db.update(
        _db.habitLogs,
      )..where((row) => row.id.equals(id))).write(
        status == null
            ? HabitLogsCompanion(
                deletedAt: Value(timestamp),
                updatedAt: Value(timestamp),
              )
            : HabitLogsCompanion(
                status: Value(status),
                deletedAt: const Value(null),
                updatedAt: Value(timestamp),
              ),
      );
    });
  }
}
