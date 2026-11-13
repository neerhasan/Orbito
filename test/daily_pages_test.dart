import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/focus_repository.dart';
import 'package:orbito/data/repositories/habit_repository.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/sleep_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';
import 'package:orbito/ui/ember.dart';

const _user = 'user-a';

late AppDatabase _db;
late PlanRepository _plan;
late TaskRepository _tasks;
late HabitRepository _habits;
late SleepRepository _sleep;
late FocusRepository _focus;

/// The time the app sees: Friday 13 November 2026, 9:00.
late DateTime _clock;

/// Lets the database finish its work, then redraws the screen.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Runs a database call and waits until it has finished.
Future<T> _read<T>(WidgetTester tester, Future<T> Function() call) async {
  late T result;
  var done = false;
  Object? failure;
  call().then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object error) {
      failure = error;
      done = true;
    },
  );
  for (var i = 0; i < 20 && !done; i++) {
    await _settle(tester);
  }
  if (failure != null) fail('The database call failed: $failure');
  expect(done, isTrue, reason: 'The database call did not finish.');
  return result;
}

/// Shows one page on top of a real, in-memory database that already has
/// one life area (so the first-run setup does not show).
Future<void> _pumpPage(WidgetTester tester, AppPage page) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await _read(
    tester,
    () => _plan.addArea(userId: _user, name: 'Health', color: 'green'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(_db),
        planRepositoryProvider.overrideWithValue(_plan),
        taskRepositoryProvider.overrideWithValue(_tasks),
        habitRepositoryProvider.overrideWithValue(_habits),
        sleepRepositoryProvider.overrideWithValue(_sleep),
        focusRepositoryProvider.overrideWithValue(_focus),
        userIdProvider.overrideWithValue(_user),
        firstSyncDoneProvider.overrideWithValue(true),
        clockProvider.overrideWithValue(() => _clock),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
        // Animations off: the tests check the end state of each screen.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: PageHost(page: page)),
      ),
    ),
  );
  await _settle(tester);
}

/// A widget test with its own database. The page is taken down at the end
/// so the database can close cleanly.
void _testPage(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    var counter = 0;
    _clock = DateTime(2026, 11, 13, 9);
    _db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    String newId() => 'id-${++counter}';
    String stableId(String key) => 'stable:$key';
    DateTime now() => _clock;
    _plan = PlanRepository(_db, newId: newId, now: now);
    _tasks = TaskRepository(_db, newId: newId, now: now);
    _habits = HabitRepository(_db, newId: newId, stableId: stableId, now: now);
    _sleep = SleepRepository(_db, stableId: stableId, now: now);
    _focus = FocusRepository(_db, newId: newId, now: now);

    await body(tester);

    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    await _read(tester, _db.close);
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  group('the Sleep page', () {
    _testPage('logs a night and shows it in the numbers', (tester) async {
      await _pumpPage(tester, AppPage.sleep);
      expect(find.text('Not logged yet'), findsOneWidget);
      expect(find.text('No nights logged yet.'), findsOneWidget);

      // The form starts at 11:00 PM to 7:00 AM.
      expect(find.text('8h'), findsOneWidget);
      await _tap(tester, 'sleep-rested-good');
      await tester.enterText(find.byKey(const Key('sleep-note')), 'Quiet');
      await _tap(tester, 'sleep-save');
      await _settle(tester);

      final nights = await _read(tester, () => _sleep.watchNights(_user).first);
      expect(nights.single.day, '2026-11-13');
      expect(nights.single.bedTime, '23:00');
      expect(nights.single.wakeTime, '07:00');
      expect(nights.single.rested, 'good');
      expect(nights.single.note, 'Quiet');
      expect(find.text('11:00 PM to 7:00 AM'), findsOneWidget);
      expect(find.byKey(const Key('night-2026-11-13')), findsOneWidget);
    });

    _testPage('a night can be changed, checked and deleted', (tester) async {
      await _read(
        tester,
        () => _sleep.saveNight(
          userId: _user,
          day: '2026-11-12',
          bedTime: '07:00',
          wakeTime: '23:30',
        ),
      );
      await _pumpPage(tester, AppPage.sleep);

      await _tap(tester, 'night-2026-11-12');
      expect(find.text('Change a night'), findsOneWidget);
      expect(find.textContaining('Check the times'), findsOneWidget);

      // Saving an unusual night asks first.
      await _tap(tester, 'sleep-save');
      await tester.pump();
      expect(find.text('Save anyway'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pump();

      await _tap(tester, 'sleep-delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();
      await _settle(tester);
      final nights = await _read(tester, () => _sleep.watchNights(_user).first);
      expect(nights, isEmpty);
    });

    _testPage('the range switch changes the numbers', (tester) async {
      await _read(tester, () async {
        await _sleep.saveNight(
          userId: _user,
          day: '2026-11-13',
          bedTime: '23:00',
          wakeTime: '07:00',
        );
        await _sleep.saveNight(
          userId: _user,
          day: '2026-11-01',
          bedTime: '23:00',
          wakeTime: '05:00',
        );
      });
      await _pumpPage(tester, AppPage.sleep);
      expect(find.text('Average, 14 nights'), findsOneWidget);
      expect(find.text('7h'), findsOneWidget);

      await _tap(tester, 'sleep-range-7');
      expect(find.text('Average, 7 nights'), findsOneWidget);
      await _tap(tester, 'sleep-range-30');
      expect(find.text('Average, 30 nights'), findsOneWidget);
      expect(find.text('7h'), findsOneWidget, reason: '(8h + 6h) / 2');
    });
  });

  group('the Habits page', () {
    _testPage('adds a habit, marks it done, skips and unskips', (
      tester,
    ) async {
      await _pumpPage(tester, AppPage.habits);
      expect(find.text('No habits yet'), findsOneWidget);

      await _tap(tester, 'habit-save');
      expect(find.text('Give the habit a name.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
      await _tap(tester, 'habit-save');
      await _settle(tester);

      final habit = (await _read(
        tester,
        () => _habits.watchHabits(_user).first,
      )).single;
      expect(habit.name, 'Read');
      expect(habit.days, '1234567');
      expect(find.text('Friday, 13 November · 0 of 1 done'), findsOneWidget);

      // One tap on the ring marks today done.
      await tester.tap(find.bySemanticsLabel('Done Read'));
      await _settle(tester);
      var logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs.single.day, '2026-11-13');
      expect(logs.single.status, 'done');
      expect(find.text('Friday, 13 November · 1 of 1 done'), findsOneWidget);

      // Tapping again opens the day again.
      await tester.tap(find.bySemanticsLabel('Undo Read'));
      await _settle(tester);
      logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs, isEmpty);

      // Skip keeps a rest day fair; it can be undone.
      await _tap(tester, 'habit-skip-${habit.id}');
      await _settle(tester);
      logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs.single.status, 'skip');
      await _tap(tester, 'habit-unskip-${habit.id}');
      await _settle(tester);
      logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs, isEmpty);

      // The page never talks about streaks.
      expect(find.textContaining('streak'), findsNothing);
      expect(find.textContaining('A missed day is data'), findsOneWidget);
    });

    _testPage('a habit planned on weekdays is a day off on Saturday', (
      tester,
    ) async {
      _clock = DateTime(2026, 11, 14, 9); // Saturday
      await _read(
        tester,
        () => _habits.addHabit(userId: _user, name: 'Walk', days: '12345'),
      );
      await _pumpPage(tester, AppPage.habits);
      expect(find.text('Day off'), findsOneWidget);
      expect(find.text('Rest day'), findsOneWidget);
    });

    _testPage('a habit can be changed and deleted', (tester) async {
      final id = await _read(
        tester,
        () => _habits.addHabit(userId: _user, name: 'Read'),
      );
      await _pumpPage(tester, AppPage.habits);

      await _tap(tester, 'habit-$id');
      expect(find.text('Edit habit'), findsOneWidget);
      await _tap(tester, 'habit-day-6');
      await _tap(tester, 'habit-day-7');
      expect(find.text('Weekdays'), findsOneWidget);
      await _tap(tester, 'habit-save');
      await _settle(tester);
      var saved = await _read(tester, () => _habits.watchHabits(_user).first);
      expect(saved.single.days, '12345');

      await _tap(tester, 'habit-delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();
      await _settle(tester);
      saved = await _read(tester, () => _habits.watchHabits(_user).first);
      expect(saved, isEmpty);
    });
  });
}
