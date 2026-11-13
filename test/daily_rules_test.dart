import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/focus.dart';
import 'package:orbito/domain/habits.dart';
import 'package:orbito/domain/sleep.dart';

// 2026-11-13 is a Friday.
const _today = '2026-11-13';

Habit _habit({String days = allDays, String created = '2026-11-01'}) => Habit(
  id: 'h1',
  userId: 'u',
  name: 'Read',
  days: days,
  createdAt: '${created}T08:00:00.000',
  updatedAt: '${created}T08:00:00.000',
);

HabitLog _mark(String day, String status, {String habitId = 'h1'}) => HabitLog(
  id: '$habitId-$day',
  userId: 'u',
  habitId: habitId,
  day: day,
  status: status,
  createdAt: '',
  updatedAt: '',
);

SleepLog _night(String day, String bed, String wake) => SleepLog(
  id: day,
  userId: 'u',
  day: day,
  bedTime: bed,
  wakeTime: wake,
  createdAt: '',
  updatedAt: '',
);

void main() {
  group('habits', () {
    test('a day is planned only on the chosen weekdays', () {
      final weekdays = _habit(days: '12345');
      expect(isPlanned(weekdays, _today), isTrue); // Friday
      expect(isPlanned(weekdays, '2026-11-14'), isFalse); // Saturday
    });

    test('describes the planned days in plain words', () {
      expect(describeDays('1234567'), 'Every day');
      expect(describeDays('12345'), 'Weekdays');
      expect(describeDays('67'), 'Weekends');
      expect(describeDays('531'), 'Mon, Wed, Fri');
    });

    test('each day shows done, skipped, missed, open or off', () {
      final habit = _habit(days: '12345', created: '2026-11-09');
      final marks = marksOf('h1', [
        _mark('2026-11-10', HabitMark.done),
        _mark('2026-11-11', HabitMark.skip),
      ]);
      HabitDay on(String day) => dayState(habit, marks, day, today: _today);

      expect(on('2026-11-08'), HabitDay.off, reason: 'before it existed');
      expect(on('2026-11-09'), HabitDay.missed);
      expect(on('2026-11-10'), HabitDay.done);
      expect(on('2026-11-11'), HabitDay.skipped);
      expect(on(_today), HabitDay.open);
      expect(on('2026-11-14'), HabitDay.off, reason: 'in the future');
      expect(lastDays(habit, marks, today: _today), hasLength(7));
    });

    test('skipped days and today while open do not count', () {
      final habit = _habit(created: '2026-11-10');
      final marks = marksOf('h1', [
        _mark('2026-11-10', HabitMark.done),
        _mark('2026-11-11', HabitMark.skip),
        // 2026-11-12 missed, today open.
      ]);
      final kept = keptOver(habit, marks, end: _today, today: _today);
      expect(kept.done, 1);
      expect(kept.counted, 2);
      expect(kept.percent, 50);
    });

    test('with nothing counted yet there is no percent', () {
      final habit = _habit(created: _today);
      final kept = keptOver(habit, const {}, end: _today, today: _today);
      expect(kept.percent, isNull);
    });

    test('today progress and the most kept habit', () {
      final read = _habit();
      const walk = Habit(
        id: 'h2',
        userId: 'u',
        name: 'Walk',
        days: allDays,
        createdAt: '2026-11-11T08:00:00.000',
        updatedAt: '',
      );
      final logs = [
        _mark(_today, HabitMark.done),
        _mark('2026-11-12', HabitMark.done, habitId: 'h2'),
        _mark('2026-11-11', HabitMark.done, habitId: 'h2'),
      ];
      final today = todayProgress([read, walk], logs, today: _today);
      expect(today.done, 1);
      expect(today.planned, 2);
      expect(mostKept([read, walk], logs, today: _today)!.habit.name, 'Walk');
    });
  });

  group('sleep', () {
    test('a night across midnight is counted correctly', () {
      expect(sleepMinutes('23:30', '06:40'), 430);
      expect(sleepMinutes('01:00', '08:00'), 420);
      expect(formatMinutes(430), '7h 10m');
      expect(formatMinutes(420), '7h');
      expect(formatMinutes(45), '45m');
    });

    test('times on a 12-hour clock', () {
      expect(formatTime('23:30'), '11:30 PM');
      expect(formatTime('00:05'), '12:05 AM');
      expect(formatTime('12:00'), '12:00 PM');
    });

    test('a night of 0 or over 16 hours asks to check the times', () {
      expect(needsCheck(sleepMinutes('23:00', '23:00')), isTrue);
      expect(needsCheck(sleepMinutes('07:00', '23:30')), isTrue);
      expect(needsCheck(sleepMinutes('23:00', '07:00')), isFalse);
    });

    test('average, usual times and consistency', () {
      final nights = [
        _night('2026-11-10', '23:30', '06:30'), // 7h
        _night('2026-11-11', '23:50', '06:50'), // 7h
        _night('2026-11-12', '00:10', '07:10'), // 7h
        _night('2026-11-13', '02:00', '08:00'), // 6h, late
      ];
      final last = nightsBefore(nights, end: _today, count: 7);
      expect(last, hasLength(7));
      expect(averageMinutes(last), 405);
      expect(usualTimes(last), (bed: '00:10', wake: '07:10'));
      // 3 of 4 bedtimes within 45 minutes of the usual one.
      expect(consistency(last), 75);
    });

    test('with no nights there are no numbers', () {
      expect(averageMinutes(const [null, null]), isNull);
      expect(consistency(const []), isNull);
      expect(usualTimes(const []), isNull);
    });
  });

  group('focus', () {
    final start = DateTime.utc(2026, 11, 13, 9);
    FocusTimer timer({required int worked, DateTime? since}) => FocusTimer(
      id: 'current',
      userId: 'u',
      startedAt: start.toIso8601String(),
      runningSince: since?.toIso8601String(),
      workedMs: worked,
    );

    test('a running clock adds the time since it last started', () {
      final running = timer(worked: 60000, since: start);
      final now = start.add(const Duration(minutes: 5));
      expect(workedMs(running, now), 6 * 60000);
      expect(isRunning(running), isTrue);
    });

    test('a paused clock does not move', () {
      final paused = timer(worked: 90000);
      expect(workedMs(paused, start.add(const Duration(hours: 1))), 90000);
      expect(isRunning(paused), isFalse);
    });

    test('clock and worked time formats', () {
      expect(formatClock(309000), '05:09');
      expect(formatClock(3909000), '1:05:09');
      expect(formatWorked(4800), '1h 20m');
      expect(formatWorked(1500), '25m');
    });

    test('time adds up per task, project and goal', () {
      FocusSession session(String? task, int seconds) => FocusSession(
        id: '$task$seconds',
        userId: 'u',
        taskId: task,
        startedAt: '2026-11-13T09:00:00.000Z',
        endedAt: '',
        focusSeconds: seconds,
        createdAt: '',
        updatedAt: '',
      );
      final byTask = secondsByTask([
        session('t1', 600),
        session('t1', 300),
        session('t2', 120),
        session(null, 999),
      ]);
      expect(byTask, {'t1': 900, 't2': 120});

      Task task(String id, String project) => Task(
        id: id,
        userId: 'u',
        title: id,
        projectId: project,
        priority: 'none',
        status: 'open',
        createdAt: '',
        updatedAt: '',
      );
      final tasks = [task('t1', 'p1'), task('t2', 'p2')];
      expect(secondsOfProject('p1', tasks, byTask), 900);
      const project = Project(
        id: 'p1',
        userId: 'u',
        name: 'P',
        goalId: 'g1',
        color: 'blue',
        createdAt: '',
        updatedAt: '',
      );
      expect(secondsOfGoal('g1', [project], tasks, byTask), 900);
    });
  });
}
