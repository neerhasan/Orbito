import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/capture_repository.dart';
import 'package:orbito/data/repositories/focus_repository.dart';
import 'package:orbito/data/repositories/habit_repository.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/sleep_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';
import 'package:orbito/data/sync/sync_status_text.dart';
import 'package:orbito/domain/today.dart';
import 'package:orbito/ui/ember.dart';

const _user = 'user-a';

late AppDatabase _db;
late PlanRepository _plan;
late TaskRepository _tasks;
late HabitRepository _habits;
late SleepRepository _sleep;
late FocusRepository _focus;
late CaptureRepository _capture;

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
        captureRepositoryProvider.overrideWithValue(_capture),
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
    _capture = CaptureRepository(
      _db,
      newId: newId,
      stableId: stableId,
      now: now,
    );

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

/// Shows the whole app frame (side menu and pages), as after sign-in.
Future<void> _pumpApp(WidgetTester tester) async {
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
        captureRepositoryProvider.overrideWithValue(_capture),
        userIdProvider.overrideWithValue(_user),
        firstSyncDoneProvider.overrideWithValue(true),
        clockProvider.overrideWithValue(() => _clock),
        syncStatusTextProvider.overrideWithValue(
          const SyncStatusText('Synced'),
        ),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const AppShell(email: 'a@example.com', pageBuilder: buildPage),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets [time] pass on the app's clock and redraws the moving clocks.
Future<void> _wait(WidgetTester tester, Duration time) async {
  _clock = _clock.add(time);
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

void main() {
  group('M3: the Quick Launcher, the Inbox, Settings and Today', () {
    _testPage('the Quick Launcher makes a task and keeps the rest', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);

      await _tap(tester, 'search');
      await tester.pump();
      expect(find.byKey(const Key('launcher')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('launcher-line')),
        'task call bank tomorrow high',
      );
      await tester.pump();
      // The user sees what will be created before confirming.
      expect(find.text('Tomorrow'), findsWidgets);
      expect(find.text('High priority'), findsOneWidget);
      await _tap(tester, 'launcher-run');
      await _settle(tester);

      final tasks = await _read(tester, () => _tasks.watchTasks(_user).first);
      expect(tasks.single.title, 'Call bank');
      expect(tasks.single.dueDate, '2026-11-14');
      expect(tasks.single.priority, TaskPriority.high);
      expect(find.byKey(const Key('launcher')), findsNothing);

      // A line it cannot sort goes to the Inbox; nothing is lost.
      await _tap(tester, 'search');
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('launcher-line')),
        'maybe learn the guitar',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      final inbox = await _read(tester, () => _capture.watchInbox(_user).first);
      expect(inbox.single.body, 'maybe learn the guitar');
    });

    _testPage('an Inbox line becomes a task', (tester) async {
      await _read(
        tester,
        () => _capture.addToInbox(userId: _user, text: 'call bank tomorrow'),
      );
      await _pumpPage(tester, AppPage.inbox);
      final item = (await _read(
        tester,
        () => _capture.watchInbox(_user).first,
      )).single;
      expect(find.text('call bank tomorrow'), findsOneWidget);

      await _tap(tester, 'inbox-task-${item.id}');
      await _settle(tester);
      final tasks = await _read(tester, () => _tasks.watchTasks(_user).first);
      expect(tasks.single.title, 'Call bank');
      expect(tasks.single.dueDate, '2026-11-14');
      expect(find.text('Nothing waiting'), findsOneWidget);
    });

    _testPage('Settings switch a Today section off; the choice is kept', (
      tester,
    ) async {
      await _pumpPage(tester, AppPage.settings);
      await _tap(tester, 'section-switch-greeting');
      await _settle(tester);
      final stored = await _read(
        tester,
        () => _capture.watchTodaySections(_user).first,
      );
      expect(readSections(stored).contains(TodaySection.greeting), isFalse);
    });

    _testPage('Today with every section off offers the defaults', (
      tester,
    ) async {
      await _read(
        tester,
        () => _capture.saveTodaySections(
          userId: _user,
          sections: writeSections(const []),
        ),
      );
      await _pumpPage(tester, AppPage.today);
      expect(find.text('No sections are switched on'), findsOneWidget);
      await _tap(tester, 'today-restore');
      await _settle(tester);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      expect(find.byKey(const Key('today-section-calendar')), findsOneWidget);
    });
  });

  group('the focus timer', () {
    _testPage('start on a task, pause, leave, come back, stop and save', (
      tester,
    ) async {
      final task = await _read(
        tester,
        () => _tasks.addTask(userId: _user, title: 'Write the plan'),
      );
      await _pumpApp(tester);

      await _tap(tester, 'menu-focus');
      await _settle(tester);
      expect(find.text('No sessions yet today.'), findsOneWidget);
      await _tap(tester, 'focus-length-45');
      await _tap(tester, 'focus-start-$task');
      await _settle(tester);

      // Focus mode fills the window.
      expect(find.byKey(const Key('focus-mode')), findsOneWidget);
      expect(find.text('Write the plan'), findsOneWidget);
      expect(find.text('of 45:00'), findsOneWidget);

      await _wait(tester, const Duration(minutes: 5));
      expect(find.text('05:00'), findsOneWidget);

      // Paused time is not counted.
      await _tap(tester, 'focus-pause');
      await _settle(tester);
      expect(find.textContaining('Paused'), findsOneWidget);
      await _wait(tester, const Duration(minutes: 10));
      expect(find.text('05:00'), findsOneWidget);
      await _tap(tester, 'focus-pause');
      await _settle(tester);

      // Back to the app: the timer stays in the side menu.
      await _tap(tester, 'focus-exit');
      await _settle(tester);
      expect(find.byKey(const Key('focus-mode')), findsNothing);
      expect(find.byKey(const Key('focus-pill')), findsOneWidget);

      await _wait(tester, const Duration(minutes: 2));
      await _tap(tester, 'focus-pill');
      await _settle(tester);
      expect(find.text('07:00'), findsOneWidget);

      await _tap(tester, 'focus-stop');
      await _settle(tester);
      final sessions = await _read(
        tester,
        () => _focus.watchSessions(_user).first,
      );
      expect(sessions.single.taskId, task);
      expect(sessions.single.focusSeconds, 7 * 60);
      expect(find.byKey(const Key('focus-mode')), findsNothing);
      expect(find.text('7m focused · 1 session'), findsOneWidget);

      // The task stays open.
      final tasks = await _read(tester, () => _tasks.watchTasks(_user).first);
      expect(tasks.single.status, TaskStatus.open);
    });

    _testPage('task done completes the task; notes save from focus mode', (
      tester,
    ) async {
      final task = await _read(
        tester,
        () => _tasks.addTask(userId: _user, title: 'Sort files'),
      );
      await _read(tester, () => _focus.start(userId: _user, taskId: task));
      await _pumpApp(tester);

      // A timer that was running when the app closed is still there.
      expect(find.byKey(const Key('focus-pill')), findsOneWidget);
      await _tap(tester, 'focus-pill');
      await _settle(tester);

      await tester.enterText(
        find.byKey(const Key('focus-notes')),
        'Scan first',
      );
      await _tap(tester, 'focus-notes-save');
      await _settle(tester);

      await _wait(tester, const Duration(minutes: 3));
      await _tap(tester, 'focus-done');
      await _settle(tester);

      final saved = (await _read(
        tester,
        () => _tasks.watchTasks(_user).first,
      )).single;
      expect(saved.status, TaskStatus.done);
      expect(saved.notes, 'Scan first');
      final sessions = await _read(
        tester,
        () => _focus.watchSessions(_user).first,
      );
      expect(sessions.single.focusSeconds, 3 * 60);
    });
  });

  group('the Sleep page', () {
    _testPage('opens on the month; Log sleep saves a night', (tester) async {
      await _pumpPage(tester, AppPage.sleep);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('No sleep logged this month'), findsOneWidget);
      expect(find.text('Goal is 8h or more'), findsOneWidget);

      // The dialog starts at the target times: 11:00 PM to 7:00 AM.
      await _tap(tester, 'sleep-log');
      expect(find.text('Log sleep'), findsWidgets);
      expect(find.text('13 - Nov - 2026'), findsOneWidget);
      expect(find.text('8h of sleep, goal met'), findsOneWidget);

      // AM or PM switches with one click: 11 AM to 7 AM is 20h, too long.
      await _tap(tester, 'sleep-bed-ampm');
      expect(find.text('20h of sleep, goal met'), findsOneWidget);
      await _tap(tester, 'sleep-save');
      await _settle(tester);
      expect(
        find.text('That is over 16 hours. Check the times.'),
        findsOneWidget,
      );
      await _tap(tester, 'sleep-bed-ampm');
      await _tap(tester, 'sleep-save');
      await _settle(tester);

      final nights = await _read(tester, () => _sleep.watchNights(_user).first);
      expect(nights.single.day, '2026-11-13');
      expect(nights.single.bedTime, '23:00');
      expect(nights.single.wakeTime, '07:00');
      expect(nights.single.rested, isNull);
      expect(nights.single.note, isNull);
      // The tracking list shows the month, newest first.
      expect(find.byKey(const Key('night-2026-11-13')), findsOneWidget);
      expect(find.byKey(const Key('night-2026-11-01')), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
    });

    _testPage('a morning that has a night opens it to edit', (tester) async {
      await _read(
        tester,
        () => _sleep.saveNight(
          userId: _user,
          day: '2026-11-13',
          bedTime: '00:30',
          wakeTime: '06:00',
        ),
      );
      await _pumpPage(tester, AppPage.sleep);
      await _tap(tester, 'sleep-log');
      expect(find.text('Edit night'), findsOneWidget);
      expect(find.text('5h 30m of sleep, 2h 30m short'), findsOneWidget);
      await _tap(tester, 'sleep-cancel');
      await _settle(tester);

      // An empty morning in the list starts a new night for that day.
      await _tap(tester, 'night-2026-11-11');
      expect(find.text('Log sleep'), findsWidgets);
      expect(find.text('11 - Nov - 2026'), findsOneWidget);
      expect(find.byKey(const Key('sleep-delete')), findsNothing);
    });

    _testPage('a night can be changed and deleted', (tester) async {
      await _read(
        tester,
        () => _sleep.saveNight(
          userId: _user,
          day: '2026-11-12',
          bedTime: '23:00',
          wakeTime: '06:00',
        ),
      );
      await _pumpPage(tester, AppPage.sleep);

      await _tap(tester, 'night-2026-11-12');
      expect(find.text('Edit night'), findsOneWidget);
      expect(find.text('7h of sleep, 1h short'), findsOneWidget);
      await _tap(tester, 'sleep-delete');
      await _settle(tester);
      final nights = await _read(tester, () => _sleep.watchNights(_user).first);
      expect(nights, isEmpty);
      expect(find.text('Edit night'), findsNothing);
    });

    _testPage('week, month, year and the arrows change the numbers', (
      tester,
    ) async {
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
      Finder average(String text) => find.descendant(
        of: find.byKey(const Key('sleep-average')),
        matching: find.text(text),
      );
      expect(find.text('November 2026'), findsOneWidget);
      expect(average('7h'), findsOneWidget, reason: '(8h + 6h) / 2');

      await _tap(tester, 'sleep-view-week');
      expect(find.text('Nov 9 to 15, 2026'), findsOneWidget);
      expect(average('8h'), findsOneWidget);
      await _tap(tester, 'sleep-view-year');
      expect(find.text('Average sleep by month'), findsOneWidget);
      expect(find.text('Every night'), findsOneWidget);

      // Back to weeks: one week back is empty, two weeks back has the 6h.
      await _tap(tester, 'sleep-view-week');
      await _tap(tester, 'sleep-prev');
      expect(find.text('Nov 2 to 8, 2026'), findsOneWidget);
      expect(find.text('No sleep logged this week'), findsOneWidget);
      await _tap(tester, 'sleep-prev');
      expect(find.text('Oct 26 to Nov 1, 2026'), findsOneWidget);
      expect(average('6h'), findsOneWidget);
      await _tap(tester, 'sleep-today');
      expect(find.text('Nov 9 to 15, 2026'), findsOneWidget);
    });
  });

  group('the Habits page', () {
    _testPage('adds a habit, marks it done, skips and unskips', (tester) async {
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

      // The log shows the last 7 days, named like a diary.
      for (final label in ['Yesterday', 'Wednesday', 'Last Saturday']) {
        expect(find.text(label), findsOneWidget);
      }

      // One click on today's box marks it done.
      final todayBox = 'habit-cell-${habit.id}-2026-11-13';
      await _tap(tester, todayBox);
      await _settle(tester);
      var logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs.single.day, '2026-11-13');
      expect(logs.single.status, 'done');
      expect(find.text('Friday, 13 November · 1 of 1 done'), findsOneWidget);
      expect(find.bySemanticsLabel('Read, Today: done'), findsOneWidget);

      // Clicking again opens the day again.
      await _tap(tester, todayBox);
      await _settle(tester);
      logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs, isEmpty);

      // A long press (or right-click) skips; again un-skips.
      await tester.longPress(find.byKey(Key(todayBox)));
      await _settle(tester);
      logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs.single.status, 'skip');
      expect(find.bySemanticsLabel('Read, Today: skipped'), findsOneWidget);
      await tester.longPress(find.byKey(Key(todayBox)));
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
      expect(find.bySemanticsLabel('Walk, Today: day off'), findsOneWidget);
      expect(find.text('Rest day'), findsOneWidget);
    });

    _testPage('one click logs a habit on a day that was forgotten', (
      tester,
    ) async {
      final id = await _read(
        tester,
        () => _habits.addHabit(userId: _user, name: 'Gym'),
      );
      await _pumpPage(tester, AppPage.habits);

      // Gym yesterday, logged today.
      await _tap(tester, 'habit-cell-$id-2026-11-12');
      await _settle(tester);
      final logs = await _read(tester, () => _habits.watchLogs(_user).first);
      expect(logs.single.day, '2026-11-12');
      expect(logs.single.status, 'done');
      expect(find.bySemanticsLabel('Gym, Yesterday: done'), findsOneWidget);
      // Today is still open.
      expect(find.text('Friday, 13 November · 0 of 1 done'), findsOneWidget);
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
