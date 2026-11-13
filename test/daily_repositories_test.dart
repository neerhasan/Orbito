import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/focus_repository.dart';
import 'package:orbito/data/repositories/habit_repository.dart';
import 'package:orbito/data/repositories/sleep_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late int counter;
  late DateTime clock;
  DateTime now() => clock;
  String newId() => 'id-${++counter}';
  String stableId(String key) => 'stable:$key';

  setUp(() {
    counter = 0;
    clock = DateTime.utc(2026, 11, 13, 9);
    db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
  });

  tearDown(() => db.close());

  group('habits', () {
    late HabitRepository habits;
    setUp(() {
      habits = HabitRepository(db, newId: newId, stableId: stableId, now: now);
    });

    test('a habit is saved with its days sorted and checked', () async {
      final id = await habits.addHabit(
        userId: 'u',
        name: '  Read  ',
        days: '531',
        usualTime: '07:00',
      );
      final saved = (await habits.watchHabits('u').first).single;
      expect(saved.id, id);
      expect(saved.name, 'Read');
      expect(saved.days, '135');
      expect(saved.usualTime, '07:00');

      expect(
        () => habits.addHabit(userId: 'u', name: 'X', days: ''),
        throwsArgumentError,
      );
      expect(
        () => habits.addHabit(userId: 'u', name: ' '),
        throwsArgumentError,
      );
    });

    test('a day is marked done, skipped and cleared on one row', () async {
      final id = await habits.addHabit(userId: 'u', name: 'Read');
      Future<List<HabitLog>> logs() => habits.watchLogs('u').first;

      await habits.setMark(
        userId: 'u',
        habitId: id,
        day: '2026-11-13',
        status: HabitMark.done,
      );
      expect((await logs()).single.status, HabitMark.done);

      await habits.setMark(
        userId: 'u',
        habitId: id,
        day: '2026-11-13',
        status: HabitMark.skip,
      );
      expect((await logs()).single.status, HabitMark.skip);

      await habits.setMark(
        userId: 'u',
        habitId: id,
        day: '2026-11-13',
        status: null,
      );
      expect(await logs(), isEmpty);

      // Marked again: the same row comes back.
      await habits.setMark(
        userId: 'u',
        habitId: id,
        day: '2026-11-13',
        status: HabitMark.done,
      );
      final all = await db.select(db.habitLogs).get();
      expect(all, hasLength(1));
      expect(all.single.id, 'stable:habit-log:$id:2026-11-13');
      expect(all.single.deletedAt, isNull);
    });

    test('deleting a habit also deletes its marks', () async {
      final id = await habits.addHabit(userId: 'u', name: 'Read');
      await habits.setMark(
        userId: 'u',
        habitId: id,
        day: '2026-11-13',
        status: HabitMark.done,
      );
      await habits.deleteHabit(id);
      expect(await habits.watchHabits('u').first, isEmpty);
      expect(await habits.watchLogs('u').first, isEmpty);
    });
  });

  group('sleep', () {
    late SleepRepository sleep;
    setUp(() => sleep = SleepRepository(db, stableId: stableId, now: now));

    test('one night per morning: saving again replaces it', () async {
      await sleep.saveNight(
        userId: 'u',
        day: '2026-11-13',
        bedTime: '23:30',
        wakeTime: '06:40',
        rested: 'good',
        note: '  late coffee ',
      );
      await sleep.saveNight(
        userId: 'u',
        day: '2026-11-13',
        bedTime: '23:00',
        wakeTime: '07:00',
      );
      final nights = await sleep.watchNights('u').first;
      expect(nights, hasLength(1));
      expect(nights.single.bedTime, '23:00');
      expect(nights.single.rested, isNull);
      expect(nights.single.note, isNull);
    });

    test('bad times are refused; a night can be deleted', () async {
      expect(
        () => sleep.saveNight(
          userId: 'u',
          day: '2026-11-13',
          bedTime: '25:00',
          wakeTime: '07:00',
        ),
        throwsArgumentError,
      );
      await sleep.saveNight(
        userId: 'u',
        day: '2026-11-12',
        bedTime: '23:00',
        wakeTime: '07:00',
      );
      final night = (await sleep.watchNights('u').first).single;
      await sleep.deleteNight(night.id);
      expect(await sleep.watchNights('u').first, isEmpty);
    });
  });

  group('focus', () {
    late FocusRepository focus;
    late TaskRepository tasks;
    setUp(() {
      focus = FocusRepository(db, newId: newId, now: now);
      tasks = TaskRepository(db, newId: newId, now: now);
    });

    test('start, pause, resume and stop saves the worked time', () async {
      final task = await tasks.addTask(userId: 'u', title: 'Write');
      await focus.start(userId: 'u', taskId: task, targetMinutes: 25);
      expect((await focus.watchTimer('u').first)!.targetMinutes, 25);

      clock = clock.add(const Duration(minutes: 10));
      await focus.togglePause(); // paused after 10 minutes
      clock = clock.add(const Duration(minutes: 30)); // not counted
      await focus.togglePause(); // running again
      clock = clock.add(const Duration(minutes: 5));

      final saved = await focus.stop();
      expect(saved, 15 * 60);
      expect(await focus.watchTimer('u').first, isNull);
      final session = (await focus.watchSessions('u').first).single;
      expect(session.taskId, task);
      expect(session.focusSeconds, 15 * 60);
      final stillOpen = (await tasks.watchTasks('u').first).single;
      expect(stillOpen.status, TaskStatus.open);
    });

    test('the timer survives the app closing', () async {
      await focus.start(userId: 'u');
      // The app closes; a new repository on the same database opens it.
      clock = clock.add(const Duration(minutes: 20));
      final reopened = FocusRepository(db, newId: newId, now: now);
      final timer = await reopened.watchTimer('u').first;
      expect(timer, isNotNull);
      expect(await reopened.stop(), 20 * 60);
    });

    test('under a minute is not saved', () async {
      await focus.start(userId: 'u');
      clock = clock.add(const Duration(seconds: 40));
      expect(await focus.stop(), isNull);
      expect(await focus.watchSessions('u').first, isEmpty);
    });

    test('task done saves the time and completes the task', () async {
      final task = await tasks.addTask(userId: 'u', title: 'Write');
      await focus.start(userId: 'u', taskId: task);
      clock = clock.add(const Duration(minutes: 3));
      await focus.stop(completeTask: true);
      final done = (await tasks.watchTasks('u').first).single;
      expect(done.status, TaskStatus.done);
      expect(done.completedAt, isNotNull);
    });

    test('starting a new session saves the running one first', () async {
      await focus.start(userId: 'u');
      clock = clock.add(const Duration(minutes: 2));
      await focus.start(userId: 'u');
      expect(await focus.watchSessions('u').first, hasLength(1));
      expect(await focus.watchTimer('u').first, isNotNull);
    });
  });
}
