import 'package:drift/drift.dart';

import '../../domain/focus.dart';
import '../local/app_database.dart';

/// The focus timer and the sessions it saves.
///
/// The running timer lives in a table kept only on this device, so it
/// survives the app closing: on the next start the clock carries on from
/// where it was. Finished sessions are synced like everything else.
class FocusRepository {
  FocusRepository(this._db, {required this._newId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// There is at most one running timer per device.
  static const _timerId = 'current';

  String _timestamp([DateTime? moment]) =>
      (moment ?? _now()).toUtc().toIso8601String();

  /// The timer running on this device for [userId], or null.
  Stream<FocusTimer?> watchTimer(String userId) {
    final query = _db.select(_db.focusTimers)
      ..where((row) => row.userId.equals(userId));
    return query.watch().map((rows) => rows.firstOrNull);
  }

  /// All of the user's saved sessions, newest first.
  Stream<List<FocusSession>> watchSessions(String userId) {
    final query = _db.select(_db.focusSessions)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    return query.watch();
  }

  Future<FocusTimer?> _current() => (_db.select(
    _db.focusTimers,
  )..where((row) => row.id.equals(_timerId))).getSingleOrNull();

  /// Starts a session on [taskId] (or on no task). A timer that is already
  /// running is stopped and saved first.
  Future<void> start({
    required String userId,
    String? taskId,
    int? targetMinutes,
  }) {
    return _db.transaction(() async {
      if (await _current() != null) await _stop(completeTask: false);
      final now = _timestamp();
      await _db
          .into(_db.focusTimers)
          .insert(
            FocusTimersCompanion.insert(
              id: _timerId,
              userId: userId,
              taskId: Value(taskId),
              startedAt: now,
              runningSince: Value(now),
              workedMs: 0,
              targetMinutes: Value(targetMinutes),
            ),
          );
    });
  }

  /// Pauses a running clock, or starts a paused one again.
  Future<void> togglePause() {
    return _db.transaction(() async {
      final timer = await _current();
      if (timer == null) return;
      final now = _now();
      await (_db.update(
        _db.focusTimers,
      )..where((row) => row.id.equals(_timerId))).write(
        isRunning(timer)
            ? FocusTimersCompanion(
                workedMs: Value(workedMs(timer, now)),
                runningSince: const Value(null),
              )
            : FocusTimersCompanion(runningSince: Value(_timestamp(now))),
      );
    });
  }

  /// Stops the timer and saves the time to its task. With [completeTask]
  /// the task is also marked done. Returns the seconds saved, or null when
  /// the session was too short to save (under a minute).
  Future<int?> stop({bool completeTask = false}) =>
      _db.transaction(() => _stop(completeTask: completeTask));

  Future<int?> _stop({required bool completeTask}) async {
    final timer = await _current();
    if (timer == null) return null;
    final now = _now();
    final seconds = workedMs(timer, now) ~/ 1000;
    final timestamp = _timestamp(now);
    final taskId = timer.taskId;
    int? saved;
    if (seconds >= minimumSessionSeconds) {
      await _db
          .into(_db.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              id: _newId(),
              userId: timer.userId,
              taskId: Value(taskId),
              startedAt: timer.startedAt,
              endedAt: timestamp,
              focusSeconds: seconds,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      saved = seconds;
    }
    if (completeTask && taskId != null) {
      await (_db.update(
        _db.tasks,
      )..where((row) => row.id.equals(taskId))).write(
        TasksCompanion(
          status: const Value(TaskStatus.done),
          completedAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
    }
    await (_db.delete(
      _db.focusTimers,
    )..where((row) => row.id.equals(_timerId))).go();
    return saved;
  }
}
