import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/event_repository.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';
import 'package:orbito/domain/calendar.dart';
import 'package:orbito/ui/ember.dart';

const _user = 'user-a';

late AppDatabase _db;
late PlanRepository _plan;
late TaskRepository _tasks;
late EventRepository _events;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(_db),
        planRepositoryProvider.overrideWithValue(_plan),
        taskRepositoryProvider.overrideWithValue(_tasks),
        eventRepositoryProvider.overrideWithValue(_events),
        userIdProvider.overrideWithValue(_user),
        firstSyncDoneProvider.overrideWithValue(true),
        // Wednesday 11 November 2026, noon.
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 11, 12)),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: PageHost(page: AppPage.calendar)),
      ),
    ),
  );
  await _settle(tester);
}

void _test(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    var counter = 0;
    _db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    String newId() => 'id-${++counter}';
    DateTime now() => DateTime.utc(2026, 11, 11, 10, 0, counter);
    _plan = PlanRepository(_db, newId: newId, now: now);
    _tasks = TaskRepository(_db, newId: newId, now: now);
    _events = EventRepository(_db, newId: newId, now: now);
    await _read(
      tester,
      () => _plan.addArea(userId: _user, name: 'Health', color: 'green'),
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

Future<List<CalendarEvent>> _saved(WidgetTester tester) =>
    _read(tester, () => _events.watchEvents(_user).first);

void main() {
  group('calendar rules', () {
    test('a week starts on Sunday; n-day views start on the day', () {
      expect(shownDays(CalendarView.week, '2026-11-11'), [
        '2026-11-08',
        '2026-11-09',
        '2026-11-10',
        '2026-11-11',
        '2026-11-12',
        '2026-11-13',
        '2026-11-14',
      ]);
      expect(shownDays(CalendarView.three, '2026-11-11'), [
        '2026-11-11',
        '2026-11-12',
        '2026-11-13',
      ]);
      final month = shownDays(CalendarView.month, '2026-11-11');
      expect(month.length, 42);
      expect(month.first, '2026-11-01');
    });

    test('steps by a month, a week or the number of days', () {
      expect(stepAnchor(CalendarView.month, '2026-11-11', 1), '2026-12-01');
      expect(stepAnchor(CalendarView.month, '2026-01-20', -1), '2025-12-01');
      expect(stepAnchor(CalendarView.week, '2026-11-11', 1), '2026-11-18');
      expect(stepAnchor(CalendarView.two, '2026-11-11', -1), '2026-11-09');
    });

    test('the heading names the week and the days', () {
      final week = calendarTitle(CalendarView.week, '2026-11-11');
      expect(week.title, 'November 2026');
      expect(week.subtitle, 'Week 46 · 8 to 14 November');
      expect(
        rangeLabel(shownDays(CalendarView.week, '2026-11-30')),
        '29 November to 5 December',
      );
      expect(calendarTitle(CalendarView.month, '2026-11-11').subtitle, '');
    });

    test('blocks that overlap sit side by side; touching ones do not', () {
      final placed = {
        for (final p in layoutBlocks(const [
          TimeBlock('a', 540, 600),
          TimeBlock('b', 570, 660),
          TimeBlock('c', 600, 690),
          TimeBlock('d', 720, 780),
        ]))
          p.block.id: (p.column, p.columns),
      };
      expect(placed['a'], (0, 2));
      expect(placed['b'], (1, 2));
      expect(placed['c'], (0, 2));
      expect(placed['d'], (0, 1));

      final touching = layoutBlocks(const [
        TimeBlock('x', 540, 600),
        TimeBlock('y', 600, 660),
      ]);
      expect(touching.every((p) => p.columns == 1), isTrue);
    });

    test('a focus session becomes a block on the day it started', () {
      final start = DateTime(2026, 11, 11, 9);
      final session = FocusSession(
        id: 's1',
        userId: _user,
        taskId: null,
        startedAt: start.toUtc().toIso8601String(),
        endedAt: start
            .add(const Duration(minutes: 45))
            .toUtc()
            .toIso8601String(),
        focusSeconds: 45 * 60,
        createdAt: '',
        updatedAt: '',
      );
      final blocks = focusBlocksOn('2026-11-11', [session]);
      expect(blocks.single.start, 540);
      expect(blocks.single.end, 585);
      expect(focusBlocksOn('2026-11-12', [session]), isEmpty);
    });

    test('an event needs a name and an end after its start', () {
      expect(
        () => EventRepository.check(
          title: ' ',
          day: '2026-11-11',
          startTime: '09:00',
          endTime: '10:00',
        ),
        throwsArgumentError,
      );
      expect(
        () => EventRepository.check(
          title: 'Call',
          day: '2026-11-11',
          startTime: '10:00',
          endTime: '10:00',
        ),
        throwsArgumentError,
      );
      EventRepository.check(
        title: 'Call',
        day: '2026-11-11',
        startTime: '10:00',
        endTime: '10:30',
      );
    });
  });

  group('the Calendar page', () {
    _test('adds an event, opens it, changes it and deletes it', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Week 46 · 8 to 14 November'), findsOneWidget);
      expect(find.text('New event'), findsOneWidget);

      // A new event starts at the next full hour, for one hour.
      await tester.enterText(
        find.byKey(const Key('event-title')),
        'Client call',
      );
      await _tap(tester, 'event-save');
      await _settle(tester);
      var saved = await _saved(tester);
      expect(saved.single.title, 'Client call');
      expect(saved.single.day, '2026-11-11');
      expect((saved.single.startTime, saved.single.endTime), (
        '13:00',
        '14:00',
      ));
      expect(find.text('Edit event'), findsOneWidget);
      expect(find.byKey(Key('event-${saved.single.id}')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('event-title')), 'Call');
      await _tap(tester, 'event-save');
      await _settle(tester);
      saved = await _saved(tester);
      expect(saved.single.title, 'Call');

      await _tap(tester, 'event-delete');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(await _saved(tester), isEmpty);
      expect(find.text('New event'), findsOneWidget);
    });

    _test('an empty name is not saved', (tester) async {
      await _pump(tester);
      await _tap(tester, 'event-save');
      await _settle(tester);
      expect(find.text('Give the event a name.'), findsOneWidget);
      expect(await _saved(tester), isEmpty);
    });

    _test('a click on the grid starts an event at that time', (tester) async {
      await _pump(tester);
      final slot = find.byKey(const Key('calendar-slot-2026-11-12'));
      await tester.ensureVisible(slot);
      await tester.pump();
      // 3.2 hours below the top of the grid (it starts at 7 AM): 10:00.
      await tester.tapAt(tester.getTopLeft(slot) + const Offset(20, 48 * 3.2));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('event-start')),
          matching: find.text('10:00 AM'),
        ),
        findsOneWidget,
      );
      expect(find.text('Thursday, 12 November'), findsWidgets);
    });

    _test('shows tasks due and project deadlines on their day', (
      tester,
    ) async {
      final task = await _read(
        tester,
        () => _tasks.addTask(
          userId: _user,
          title: 'Pay rent',
          dueDate: '2026-11-12',
        ),
      );
      final project = await _read(
        tester,
        () => _plan.addProject(
          userId: _user,
          name: 'Korea',
          color: 'blue',
          deadline: '2026-11-13',
        ),
      );
      await _pump(tester);
      expect(find.byKey(Key('calendar-task-$task')), findsOneWidget);
      expect(find.byKey(Key('calendar-deadline-$project')), findsOneWidget);
      expect(find.text('Due: Korea'), findsOneWidget);
    });

    _test('shows a past focus session as a block', (tester) async {
      final start = DateTime(2026, 11, 11, 9);
      await _read(
        tester,
        () => _db
            .into(_db.focusSessions)
            .insert(
              FocusSessionsCompanion.insert(
                id: 'session-1',
                userId: _user,
                startedAt: start.toUtc().toIso8601String(),
                endedAt: start
                    .add(const Duration(minutes: 50))
                    .toUtc()
                    .toIso8601String(),
                focusSeconds: 50 * 60,
                createdAt: start.toUtc().toIso8601String(),
                updatedAt: start.toUtc().toIso8601String(),
              ),
            ),
      );
      await _pump(tester);
      expect(find.byKey(const Key('focus-block-session-1')), findsOneWidget);
    });

    _test('moves between weeks and switches to the month view', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, 'calendar-next');
      expect(find.text('Week 47 · 15 to 21 November'), findsOneWidget);
      await _tap(tester, 'calendar-today');
      expect(find.text('Week 46 · 8 to 14 November'), findsOneWidget);

      await _tap(tester, 'calendar-view-four');
      expect(find.text('11 to 14 November'), findsOneWidget);

      await _tap(tester, 'calendar-view-month');
      expect(find.byKey(const Key('calendar-month')), findsOneWidget);
      await _tap(tester, 'calendar-day-2026-11-20');
      expect(find.text('Friday, 20 November'), findsWidgets);
      await _tap(tester, 'calendar-next');
      expect(find.text('December 2026'), findsOneWidget);
    });
  });
}
