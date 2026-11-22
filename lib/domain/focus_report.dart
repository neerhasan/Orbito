/// The rules behind the Focus report: day, week, month and year ranges,
/// focus time per day, project and task, the blocks on the records grid,
/// and the focus goal. Plain functions, so they are easy to test.
///
/// Every total is built from `focusSeconds` (paused time is not counted).
/// A session's time belongs to the day it started, in the device's time
/// zone. Weeks start on Monday, as on the Sleep page.
library;

import 'dart:math' as math;

import '../data/local/app_database.dart';
import 'dates.dart';
import 'sleep_view.dart' show mondayOf, SleepView, sleepRange, sleepPeriodLabel;

/// Day, week, month or year in the report.
enum FocusPeriod { day, week, month, year }

/// The focus goal used until the user sets one: 4 hours a day.
const defaultFocusGoalMinutes = 4 * 60;

/// The goals offered, in minutes.
const focusGoalChoices = <int>[60, 120, 180, 240, 300, 360, 480];

/// The first and last day of the day, week (Monday to Sunday), month or year
/// that [anchor] is in.
({String start, String end}) focusRange(FocusPeriod period, String anchor) {
  return switch (period) {
    FocusPeriod.day => (start: anchor, end: anchor),
    FocusPeriod.week => sleepRange(SleepView.week, anchor),
    FocusPeriod.month => sleepRange(SleepView.month, anchor),
    FocusPeriod.year => sleepRange(SleepView.year, anchor),
  };
}

/// [anchor] moved one period back (-1) or forward (1).
String shiftFocusAnchor(FocusPeriod period, String anchor, int step) {
  final date = parseDayKey(anchor)!;
  return switch (period) {
    FocusPeriod.day => addDays(anchor, step),
    FocusPeriod.week => addDays(anchor, 7 * step),
    FocusPeriod.month => dayKey(DateTime(date.year, date.month + step)),
    FocusPeriod.year => dayKey(DateTime(date.year + step)),
  };
}

/// `Today`, `Yesterday`, `20 Nov`, `Nov 16 to 22, 2026`, `November 2026`,
/// `2026`.
String focusPeriodLabel(
  FocusPeriod period,
  String anchor, {
  required String today,
}) {
  if (period == FocusPeriod.day) {
    return formatRelativeDay(anchor, today: today);
  }
  final view = switch (period) {
    FocusPeriod.week => SleepView.week,
    FocusPeriod.month => SleepView.month,
    _ => SleepView.year,
  };
  return sleepPeriodLabel(view, focusRange(period, anchor));
}

/// True when [day] is inside [range] (both ends included).
bool inRange(String day, ({String start, String end}) range) =>
    day.compareTo(range.start) >= 0 && day.compareTo(range.end) <= 0;

/// The day a session belongs to: the day it started.
String sessionDay(FocusSession session) =>
    dayKeyOfStoredTime(session.startedAt) ?? '';

/// The sessions that started inside [range].
List<FocusSession> sessionsIn(
  Iterable<FocusSession> sessions,
  ({String start, String end}) range,
) => sessions.where((session) => inRange(sessionDay(session), range)).toList();

/// Seconds of focus in [sessions].
int totalSeconds(Iterable<FocusSession> sessions) =>
    sessions.fold(0, (sum, session) => sum + session.focusSeconds);

/// Seconds of focus on each day that has some.
Map<String, int> secondsByDay(Iterable<FocusSession> sessions) {
  final totals = <String, int>{};
  for (final session in sessions) {
    final day = sessionDay(session);
    totals[day] = (totals[day] ?? 0) + session.focusSeconds;
  }
  return totals;
}

/// The project a session counts for (through its task), or null for a
/// session with no task or a task with no project.
String? projectOfSession(FocusSession session, Map<String, Task> tasksById) =>
    tasksById[session.taskId]?.projectId;

/// Seconds of focus per project, biggest first. The null key holds the
/// time with no project.
List<MapEntry<String?, int>> secondsByProject(
  Iterable<FocusSession> sessions,
  Map<String, Task> tasksById,
) {
  final totals = <String?, int>{};
  for (final session in sessions) {
    final project = projectOfSession(session, tasksById);
    totals[project] = (totals[project] ?? 0) + session.focusSeconds;
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Seconds of focus per task, biggest first. The null key holds the time
/// with no task.
List<MapEntry<String?, int>> secondsByTaskSorted(
  Iterable<FocusSession> sessions,
) {
  final totals = <String?, int>{};
  for (final session in sessions) {
    totals[session.taskId] =
        (totals[session.taskId] ?? 0) + session.focusSeconds;
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// One coloured block on the records grid: minutes after midnight.
class FocusBlock {
  const FocusBlock(this.session, this.startMinute, this.endMinute);

  final FocusSession session;
  final int startMinute;
  final int endMinute;
}

/// The part of each session that falls on [day], from its start to its end
/// time (pauses inside a session are not shown). A session that runs past
/// midnight shows on both days.
List<FocusBlock> blocksOn(Iterable<FocusSession> sessions, String day) {
  final dayStart = parseDayKey(day)!;
  final dayEnd = parseDayKey(addDays(day, 1))!;
  final blocks = <FocusBlock>[];
  for (final session in sessions) {
    final start = parseStoredTime(session.startedAt);
    final end = parseStoredTime(session.endedAt);
    if (start == null || end == null) continue;
    if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) continue;
    final from = start.isBefore(dayStart) ? dayStart : start;
    final to = end.isAfter(dayEnd) ? dayEnd : end;
    final startMinute = from.difference(dayStart).inMinutes;
    // Very short blocks still get one minute, so they can be seen.
    final endMinute = math.max(
      startMinute + 1,
      math.min(1440, (to.difference(dayStart).inSeconds / 60).ceil()),
    );
    blocks.add(FocusBlock(session, startMinute, endMinute));
  }
  blocks.sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return blocks;
}

/// The tasks completed inside [range].
int completedIn(Iterable<Task> tasks, ({String start, String end}) range) =>
    tasks.where((task) {
      if (task.status != TaskStatus.done) return false;
      final day = dayKeyOfStoredTime(task.completedAt);
      return day != null && inRange(day, range);
    }).length;

/// All completed tasks.
int completedEver(Iterable<Task> tasks) =>
    tasks.where((task) => task.status == TaskStatus.done).length;

/// The numbers under the goal calendar for one month.
class FocusGoalStats {
  const FocusGoalStats({
    required this.focusDays,
    required this.goalDays,
    required this.daysCounted,
  });

  /// Days with any focus.
  final int focusDays;

  /// Days that reached the goal.
  final int goalDays;

  /// Days of the month up to today (all of them for a past month, none for
  /// a future one).
  final int daysCounted;

  /// Goal days out of the days counted, 0 to 100.
  int get rate => daysCounted == 0 ? 0 : (goalDays * 100 / daysCounted).round();
}

/// The goal numbers for the month [anchor] is in.
FocusGoalStats focusGoalStats(
  Map<String, int> byDay,
  String anchor, {
  required int goalMinutes,
  required String today,
}) {
  final range = focusRange(FocusPeriod.month, anchor);
  var focusDays = 0;
  var goalDays = 0;
  var counted = 0;
  for (
    var day = range.start;
    day.compareTo(range.end) <= 0;
    day = addDays(day, 1)
  ) {
    if (day.compareTo(today) > 0) break;
    counted++;
    final seconds = byDay[day] ?? 0;
    if (seconds > 0) focusDays++;
    if (reachedGoal(seconds, goalMinutes)) goalDays++;
  }
  return FocusGoalStats(
    focusDays: focusDays,
    goalDays: goalDays,
    daysCounted: counted,
  );
}

/// True when [seconds] of focus reach the goal.
bool reachedGoal(int seconds, int goalMinutes) =>
    goalMinutes > 0 && seconds >= goalMinutes * 60;

/// The days of the month grid for the month [anchor] is in: whole weeks,
/// Monday first, including the days of the months around it.
List<String> monthGridDays(String anchor) {
  final range = focusRange(FocusPeriod.month, anchor);
  final first = mondayOf(range.start);
  final last = addDays(mondayOf(range.end), 6);
  return [
    for (var day = first; day.compareTo(last) <= 0; day = addDays(day, 1)) day,
  ];
}

/// The bars of the "focus by day" chart: one per day of the week for a day
/// or a week, one per day for a month, one per month for a year. Each has
/// a short label and the days it covers.
List<({String label, ({String start, String end}) range})> chartBuckets(
  FocusPeriod period,
  String anchor,
) {
  if (period == FocusPeriod.year) {
    final year = parseDayKey(anchor)!.year;
    return [
      for (var month = 1; month <= 12; month++)
        (
          label: monthNames[month - 1].substring(0, 3),
          range: focusRange(FocusPeriod.month, dayKey(DateTime(year, month))),
        ),
    ];
  }
  final range = period == FocusPeriod.month
      ? focusRange(FocusPeriod.month, anchor)
      : focusRange(FocusPeriod.week, anchor);
  return [
    for (
      var day = range.start;
      day.compareTo(range.end) <= 0;
      day = addDays(day, 1)
    )
      (
        label: period == FocusPeriod.month
            ? '${parseDayKey(day)!.day}'
            : weekdayShort[parseDayKey(day)!.weekday - 1],
        range: (start: day, end: day),
      ),
  ];
}
