import 'package:drift/drift.dart';

import '../../domain/sleep.dart' show minutesOf;
import '../local/app_database.dart';

/// Reads and writes the sleep log: one night per morning. It only ever
/// touches the local database. Sync copies the changes to the server in the
/// background.
class SleepRepository {
  SleepRepository(this._db, {required this._stableId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;

  /// The same id for the same text on every device: a night's id comes
  /// from the user and the morning, so there is one night per morning.
  final String Function(String key) _stableId;
  final DateTime Function() _now;

  String _timestamp() => _now().toUtc().toIso8601String();

  static String _time(String value, String field) {
    if (minutesOf(value) == null) {
      throw ArgumentError.value(value, field, 'Must be HH:MM');
    }
    return value;
  }

  /// The user's nights, newest morning first. Deleted ones are left out.
  Stream<List<SleepLog>> watchNights(String userId) {
    final query = _db.select(_db.sleepLogs)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.day)]);
    return query.watch();
  }

  /// Saves the night that ended on the morning [day] (`YYYY-MM-DD`). A
  /// night already saved for that morning is replaced.
  Future<void> saveNight({
    required String userId,
    required String day,
    required String bedTime,
    required String wakeTime,
    String? rested,
    String? note,
  }) {
    if (rested != null && !Rested.all.contains(rested)) {
      throw ArgumentError.value(rested, 'rested', 'Unknown value');
    }
    final bed = _time(bedTime, 'bedTime');
    final wake = _time(wakeTime, 'wakeTime');
    final trimmedNote = note?.trim() ?? '';
    final cleanNote = trimmedNote.isEmpty ? null : trimmedNote;
    final id = _stableId('sleep:$userId:$day');
    return _db.transaction(() async {
      final timestamp = _timestamp();
      final existing = await (_db.select(
        _db.sleepLogs,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.sleepLogs)
            .insert(
              SleepLogsCompanion.insert(
                id: id,
                userId: userId,
                day: day,
                bedTime: bed,
                wakeTime: wake,
                rested: Value(rested),
                note: Value(cleanNote),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
        return;
      }
      await (_db.update(
        _db.sleepLogs,
      )..where((row) => row.id.equals(id))).write(
        SleepLogsCompanion(
          bedTime: Value(bed),
          wakeTime: Value(wake),
          rested: Value(rested),
          note: Value(cleanNote),
          deletedAt: const Value(null),
          updatedAt: Value(timestamp),
        ),
      );
    });
  }

  /// Soft delete: the row is marked, so other devices learn of it.
  Future<void> deleteNight(String id) {
    final timestamp = _timestamp();
    return (_db.update(_db.sleepLogs)..where((row) => row.id.equals(id))).write(
      SleepLogsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }
}
