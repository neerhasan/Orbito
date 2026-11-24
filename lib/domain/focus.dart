/// The rules for the focus timer and the time it saves. Plain functions, so
/// they are easy to test.
library;

import 'dart:math' as math;

import '../data/local/app_database.dart';
import 'dates.dart';

/// A session shorter than this is not saved.
const minimumSessionSeconds = 60;

/// The planned lengths offered when a session starts, in minutes. Null
/// means no planned length.
const targetChoices = <int?>[null, 25, 45, 60, 90];

/// Milliseconds worked so far: the time before the last pause plus the time
/// since the clock last started.
int workedMs(FocusTimer timer, DateTime now) {
  final since = parseStoredTime(timer.runningSince);
  final running = since == null ? 0 : now.difference(since).inMilliseconds;
  return timer.workedMs + (running < 0 ? 0 : running);
}

/// The milliseconds a stop saves. A countdown (a timer with a planned
/// length) never saves more than its planned length, so a timer left
/// running after it ended, or while the app was closed, does not add
/// hours that were not worked. A stopwatch saves all of it.
int savedMs(FocusTimer timer, DateTime now) {
  final worked = workedMs(timer, now);
  final target = timer.targetMinutes;
  return target == null ? worked : math.min(worked, target * 60000);
}

/// Milliseconds left on a countdown, never below 0; null for a stopwatch.
int? remainingMs(FocusTimer timer, DateTime now) {
  final target = timer.targetMinutes;
  if (target == null) return null;
  return math.max(0, target * 60000 - workedMs(timer, now));
}

/// True while the clock is running (not paused).
bool isRunning(FocusTimer timer) => timer.runningSince != null;

/// A clock: `05:09`, or `1:05:09` from one hour on.
String formatClock(int milliseconds) {
  final total = milliseconds ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// A clock that always shows hours: `0:05:09`, `1:05:09`.
String formatClockWithHours(int milliseconds) {
  final total = milliseconds ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '$hours:${two(minutes)}:${two(seconds)}';
}

/// Time worked as words: `1h 20m`, `25m`, `0m`.
String formatWorked(int seconds) {
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// Seconds of focus saved to each task.
Map<String, int> secondsByTask(List<FocusSession> sessions) {
  final totals = <String, int>{};
  for (final session in sessions) {
    final task = session.taskId;
    if (task == null) continue;
    totals[task] = (totals[task] ?? 0) + session.focusSeconds;
  }
  return totals;
}

/// Seconds of focus saved to the tasks of a project.
int secondsOfProject(
  String projectId,
  List<Task> tasks,
  Map<String, int> byTask,
) {
  var total = 0;
  for (final task in tasks) {
    if (task.projectId == projectId) total += byTask[task.id] ?? 0;
  }
  return total;
}

/// Seconds of focus saved to the tasks of the projects that serve a goal.
int secondsOfGoal(
  String goalId,
  List<Project> projects,
  List<Task> tasks,
  Map<String, int> byTask,
) {
  var total = 0;
  for (final project in projects) {
    if (project.goalId == goalId) {
      total += secondsOfProject(project.id, tasks, byTask);
    }
  }
  return total;
}

/// The sessions that started on [day], newest first.
List<FocusSession> sessionsOn(List<FocusSession> sessions, String day) =>
    sessions
        .where((session) => dayKeyOfStoredTime(session.startedAt) == day)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
