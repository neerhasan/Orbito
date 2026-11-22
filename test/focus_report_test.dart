import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/focus_report.dart';

/// A stored time for a local moment, as the app saves it (UTC).
String _at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute).toUtc().toIso8601String();

FocusSession _session(
  String id, {
  required String start,
  required String end,
  required int minutes,
  String? task,
}) => FocusSession(
  id: id,
  userId: 'u',
  taskId: task,
  startedAt: start,
  endedAt: end,
  focusSeconds: minutes * 60,
  createdAt: '',
  updatedAt: '',
);

Task _task(String id, {String? project, String? completedAt}) => Task(
  id: id,
  userId: 'u',
  createdAt: '',
  updatedAt: '',
  title: id,
  projectId: project,
  priority: 'none',
  status: completedAt == null ? TaskStatus.open : TaskStatus.done,
  completedAt: completedAt,
);

void main() {
  const today = '2026-11-20'; // Friday

  test('day, week, month and year ranges and their labels', () {
    expect(focusRange(FocusPeriod.day, today), (start: today, end: today));
    expect(focusRange(FocusPeriod.week, today), (
      start: '2026-11-16',
      end: '2026-11-22',
    ));
    expect(shiftFocusAnchor(FocusPeriod.day, today, -1), '2026-11-19');
    expect(shiftFocusAnchor(FocusPeriod.month, today, 1), '2026-12-01');
    expect(focusPeriodLabel(FocusPeriod.day, today, today: today), 'Today');
    expect(
      focusPeriodLabel(FocusPeriod.day, '2026-11-19', today: today),
      'Yesterday',
    );
    expect(
      focusPeriodLabel(FocusPeriod.month, today, today: today),
      'November 2026',
    );
  });

  test('totals use worked seconds, by day, project and task', () {
    final tasks = {
      'a': _task('a', project: 'p1'),
      'b': _task('b', project: 'p2'),
      'c': _task('c'),
    };
    final sessions = [
      // Ran 9:00 to 10:00 with a pause: only 40 minutes count.
      _session('1', start: _at(20, 9), end: _at(20, 10), minutes: 40, task: 'a'),
      _session('2', start: _at(20, 11), end: _at(20, 11, 30), minutes: 30, task: 'b'),
      _session('3', start: _at(19, 8), end: _at(19, 9), minutes: 60, task: 'a'),
      _session('4', start: _at(20, 14), end: _at(20, 14, 20), minutes: 20, task: 'c'),
      _session('5', start: _at(20, 15), end: _at(20, 15, 10), minutes: 10),
    ];

    final todays = sessionsIn(sessions, focusRange(FocusPeriod.day, today));
    expect(totalSeconds(todays), 100 * 60);
    expect(secondsByDay(sessions), {
      '2026-11-20': 100 * 60,
      '2026-11-19': 60 * 60,
    });

    final byProject = secondsByProject(todays, tasks);
    expect(byProject.first.key, 'p1');
    expect(byProject.first.value, 40 * 60);
    // A task with no project and no task at all both count as no project.
    expect(
      byProject.firstWhere((entry) => entry.key == null).value,
      30 * 60,
    );

    final byTask = secondsByTaskSorted(todays);
    expect(byTask.first.key, 'a');
    expect(byTask.firstWhere((entry) => entry.key == null).value, 10 * 60);
  });

  test('records blocks sit at their clock time and split at midnight', () {
    final late = _session(
      'late',
      start: _at(19, 23, 30),
      end: _at(20, 0, 45),
      minutes: 75,
    );
    final morning = _session(
      'morning',
      start: _at(20, 9, 15),
      end: _at(20, 9, 40),
      minutes: 25,
    );

    final yesterday = blocksOn([late, morning], '2026-11-19');
    expect(yesterday.single.startMinute, 23 * 60 + 30);
    expect(yesterday.single.endMinute, 1440);

    final blocks = blocksOn([late, morning], today);
    expect(blocks, hasLength(2));
    expect(blocks.first.startMinute, 0);
    expect(blocks.first.endMinute, 45);
    expect(blocks.last.startMinute, 9 * 60 + 15);
    expect(blocks.last.endMinute, 9 * 60 + 40);
  });

  test('completed tasks are counted by the day they were done', () {
    final tasks = [
      _task('a', completedAt: _at(20, 10)),
      _task('b', completedAt: _at(17, 10)),
      _task('c', completedAt: _at(2, 10)),
      _task('d'),
    ];
    expect(completedEver(tasks), 3);
    expect(completedIn(tasks, focusRange(FocusPeriod.day, today)), 1);
    expect(completedIn(tasks, focusRange(FocusPeriod.week, today)), 2);
  });

  test('goal days, focus days and the rate count days up to today', () {
    final byDay = {
      '2026-11-02': 5 * 3600,
      '2026-11-03': 1 * 3600,
      '2026-11-20': 4 * 3600,
      '2026-11-25': 6 * 3600, // the future does not count
    };
    final stats = focusGoalStats(
      byDay,
      today,
      goalMinutes: 4 * 60,
      today: today,
    );
    expect(stats.focusDays, 3);
    expect(stats.goalDays, 2);
    expect(stats.daysCounted, 20);
    expect(stats.rate, 10);

    final future = focusGoalStats(
      byDay,
      '2026-12-05',
      goalMinutes: 60,
      today: today,
    );
    expect(future.daysCounted, 0);
    expect(future.rate, 0);
  });

  test('the month grid is whole weeks starting on Monday', () {
    final days = monthGridDays(today);
    expect(days.first, '2026-10-26');
    expect(days.last, '2026-12-06');
    expect(days.length % 7, 0);
  });

  test('chart bars: week days, month days or months', () {
    final week = chartBuckets(FocusPeriod.week, today);
    expect(week.map((bar) => bar.label).first, 'Mon');
    expect(week, hasLength(7));
    expect(chartBuckets(FocusPeriod.day, today), hasLength(7));
    expect(chartBuckets(FocusPeriod.month, today), hasLength(30));
    final year = chartBuckets(FocusPeriod.year, today);
    expect(year, hasLength(12));
    expect(year.first.range.end, '2026-01-31');
  });
}
