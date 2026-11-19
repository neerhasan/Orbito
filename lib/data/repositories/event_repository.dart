import 'package:drift/drift.dart';

import '../../domain/sleep.dart' show minutesOf;
import '../local/app_database.dart';

/// Reads and writes calendar events. It only ever touches the local
/// database. Sync copies the changes to the server in the background.
class EventRepository {
  EventRepository(this._db, {required this._newId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  /// The user's events, by day and start time. Deleted ones are left out.
  Stream<List<CalendarEvent>> watchEvents(String userId) {
    final query = _db.select(_db.calendarEvents)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([
        (row) => OrderingTerm.asc(row.day),
        (row) => OrderingTerm.asc(row.startTime),
      ]);
    return query.watch();
  }

  /// Checks an event before it is saved: a title, a day, and an end after
  /// the start.
  static void check({
    required String title,
    required String day,
    required String startTime,
    required String endTime,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty');
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw ArgumentError.value(day, 'day', 'Must be YYYY-MM-DD');
    }
    final start = minutesOf(startTime);
    final end = minutesOf(endTime);
    if (start == null || end == null) {
      throw ArgumentError.value(startTime, 'startTime', 'Must be HH:MM');
    }
    if (end <= start) {
      throw ArgumentError.value(endTime, 'endTime', 'Must be after the start');
    }
  }

  Future<String> addEvent({
    required String userId,
    required String title,
    required String day,
    required String startTime,
    required String endTime,
    String? projectId,
    String note = '',
  }) async {
    check(title: title, day: day, startTime: startTime, endTime: endTime);
    final id = _newId();
    final timestamp = _timestamp();
    await _db
        .into(_db.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: id,
            userId: userId,
            title: title.trim(),
            day: day,
            startTime: startTime,
            endTime: endTime,
            projectId: Value(projectId),
            note: note,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return id;
  }

  Future<void> updateEvent(
    String id, {
    required String title,
    required String day,
    required String startTime,
    required String endTime,
    required String? projectId,
    required String note,
  }) {
    check(title: title, day: day, startTime: startTime, endTime: endTime);
    return (_db.update(
      _db.calendarEvents,
    )..where((row) => row.id.equals(id))).write(
      CalendarEventsCompanion(
        title: Value(title.trim()),
        day: Value(day),
        startTime: Value(startTime),
        endTime: Value(endTime),
        projectId: Value(projectId),
        note: Value(note),
        updatedAt: Value(_timestamp()),
      ),
    );
  }

  /// Removes an event (soft delete).
  Future<void> deleteEvent(String id) {
    final timestamp = _timestamp();
    return (_db.update(
      _db.calendarEvents,
    )..where((row) => row.id.equals(id))).write(
      CalendarEventsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }
}
