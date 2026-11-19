import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/capture_repository.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';
import 'package:orbito/domain/today.dart';
import 'package:orbito/ui/ember.dart';

const _user = 'user-a';

late AppDatabase _db;
late PlanRepository _plan;
late TaskRepository _tasks;
late CaptureRepository _capture;

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

Future<void> _pump(WidgetTester tester, AppPage page) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(_db),
        planRepositoryProvider.overrideWithValue(_plan),
        taskRepositoryProvider.overrideWithValue(_tasks),
        captureRepositoryProvider.overrideWithValue(_capture),
        userIdProvider.overrideWithValue(_user),
        firstSyncDoneProvider.overrideWithValue(true),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 11, 12)),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
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

void _test(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    var counter = 0;
    _db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    String newId() => 'id-${++counter}';
    DateTime now() => DateTime.utc(2026, 11, 11, 10, 0, counter);
    _plan = PlanRepository(_db, newId: newId, now: now);
    _tasks = TaskRepository(_db, newId: newId, now: now);
    _capture = CaptureRepository(
      _db,
      newId: newId,
      stableId: (key) => 'stable-$key',
      now: now,
    );
    // The app needs one life area, or it shows the first-run setup.
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

Future<List<Note>> _notes(WidgetTester tester) =>
    _read(tester, () => _capture.watchNotes(_user).first);

Future<List<Project>> _projects(WidgetTester tester) =>
    _read(tester, () => _plan.watchProjects(_user).first);

void main() {
  group('day bar', () {
    test('starts at the wake time and runs for 24 hours', () {
      final atWake = dayProgress(
        DateTime(2026, 11, 11, 7),
        wake: '07:00',
        bed: '23:00',
      );
      expect(atWake.share, 0);
      expect(atWake.pastBed, isFalse);

      final evening = dayProgress(
        DateTime(2026, 11, 11, 19),
        wake: '07:00',
        bed: '23:00',
      );
      expect(evening.share, 0.5);
      expect(evening.bedShare, closeTo(16 / 24, 1e-9));
      expect(evening.percent, 50);
    });

    test('keeps running past bedtime and into the next morning', () {
      final late = dayProgress(
        DateTime(2026, 11, 11, 23, 30),
        wake: '07:00',
        bed: '23:00',
      );
      expect(late.pastBed, isTrue);
      expect(late.share, closeTo(16.5 / 24, 1e-9));

      // 3 AM: the day that began yesterday at 7:00 is still running.
      final night = dayProgress(
        DateTime(2026, 11, 12, 3),
        wake: '07:00',
        bed: '23:00',
      );
      expect(night.share, closeTo(20 / 24, 1e-9));
      expect(night.pastBed, isTrue);
    });

    test('puts the bedtime dot right when bedtime is after midnight', () {
      final progress = dayProgress(
        DateTime(2026, 11, 11, 12),
        wake: '09:00',
        bed: '01:00',
      );
      expect(progress.bedShare, closeTo(16 / 24, 1e-9));
    });
  });

  group('notes and deadlines', () {
    _test('notes are added, changed, linked and removed', (tester) async {
      final project = await _read(
        tester,
        () => _plan.addProject(userId: _user, name: 'Korea', color: 'blue'),
      );
      expect(
        () => _capture.addNote(userId: _user),
        throwsA(isA<ArgumentError>()),
      );
      final id = await _read(
        tester,
        () => _capture.addNote(
          userId: _user,
          title: ' Visa ',
          body: 'Ask about D-2',
          projectId: project,
        ),
      );
      var notes = await _notes(tester);
      expect(notes.single.title, 'Visa');
      expect(notes.single.projectId, project);

      await _read(
        tester,
        () => _capture.updateNote(
          id,
          title: 'Visa',
          body: 'Changed',
          projectId: null,
        ),
      );
      notes = await _notes(tester);
      expect(notes.single.body, 'Changed');
      expect(notes.single.projectId, isNull);

      await _read(tester, () => _capture.deleteNote(id));
      expect(await _notes(tester), isEmpty);
    });

    _test('deleting a project keeps its notes but cuts the link', (
      tester,
    ) async {
      final project = await _read(
        tester,
        () => _plan.addProject(userId: _user, name: 'Korea', color: 'blue'),
      );
      await _read(
        tester,
        () =>
            _capture.addNote(userId: _user, title: 'Visa', projectId: project),
      );
      await _read(
        tester,
        () => _plan.deleteProject(project, linked: LinkedItems.keep),
      );
      expect((await _notes(tester)).single.projectId, isNull);
    });

    _test('a project deadline can be added, changed and cleared', (
      tester,
    ) async {
      final id = await _read(
        tester,
        () => _plan.addProject(userId: _user, name: 'Korea', color: 'blue'),
      );
      expect((await _projects(tester)).single.deadline, isNull);

      Future<void> save(String? deadline) => _plan.updateProject(
        id,
        name: 'Korea',
        color: 'blue',
        icon: 'folder',
        goalId: null,
        deadline: deadline,
      );
      await _read(tester, () => save('2027-03-01'));
      expect((await _projects(tester)).single.deadline, '2027-03-01');

      await _read(tester, () => save(null));
      expect((await _projects(tester)).single.deadline, isNull);
    });

    _test('wake and bed times are saved and read back', (tester) async {
      var times = await _read(
        tester,
        () => _capture.watchDayTimes(_user).first,
      );
      expect(times.wake, isNull);
      await _read(
        tester,
        () => _capture.saveDayTimes(userId: _user, wake: '06:30', bed: '22:45'),
      );
      times = await _read(tester, () => _capture.watchDayTimes(_user).first);
      expect((times.wake, times.bed), ('06:30', '22:45'));

      // Changing the Today sections does not wipe the times.
      await _read(
        tester,
        () => _capture.saveTodaySections(userId: _user, sections: 'habits'),
      );
      times = await _read(tester, () => _capture.watchDayTimes(_user).first);
      expect((times.wake, times.bed), ('06:30', '22:45'));
    });
  });

  group('pages', () {
    _test('the Notes page writes a note linked to a project', (tester) async {
      await _read(
        tester,
        () => _plan.addProject(userId: _user, name: 'Korea', color: 'blue'),
      );
      await _pump(tester, AppPage.notes);
      expect(find.text('No notes yet'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('note-title')), 'Visa');
      await tester.enterText(find.byKey(const Key('note-body')), 'Ask D-2');
      await _tap(tester, 'note-project');
      await tester.pump();
      await tester.tap(find.text('Korea').last);
      await tester.pump();
      await _tap(tester, 'note-save');
      await _settle(tester);

      final notes = await _notes(tester);
      expect(notes.single.title, 'Visa');
      expect(notes.single.body, 'Ask D-2');
      expect(notes.single.projectId, isNotNull);
      expect(find.text('Edit note'), findsOneWidget);
    });

    _test('an empty note is not saved', (tester) async {
      await _pump(tester, AppPage.notes);
      await _tap(tester, 'note-save');
      await _settle(tester);
      expect(find.text('Write a title or some text.'), findsOneWidget);
      expect(await _notes(tester), isEmpty);
    });

    _test('Today: a click on a date shows the tasks due that day', (
      tester,
    ) async {
      await _read(
        tester,
        () => _tasks.addTask(
          userId: _user,
          title: 'Pay rent',
          dueDate: '2026-11-20',
        ),
      );
      await _read(
        tester,
        () => _tasks.addTask(
          userId: _user,
          title: 'Other day',
          dueDate: '2026-11-21',
        ),
      );
      await _pump(tester, AppPage.today);
      expect(find.text('Today · 0'), findsOneWidget);

      // The Tasks section switches to the clicked day.
      await _tap(tester, 'today-day-2026-11-20');
      await _settle(tester);
      expect(find.byKey(const Key('today-tasks-back')), findsOneWidget);
      expect(find.text('Pay rent'), findsOneWidget);
      expect(find.text('Other day'), findsNothing);

      await _tap(tester, 'today-day-2026-11-22');
      await _settle(tester);
      expect(find.text('No tasks due this day.'), findsOneWidget);

      // "Add one" turns into a box in place; the task gets the picked day.
      await _tap(tester, 'today-add-task');
      await tester.enterText(find.byKey(const Key('today-add-field')), 'Gym');
      await _tap(tester, 'today-add-save');
      await _settle(tester);
      final added = await _read(tester, () => _tasks.watchTasks(_user).first);
      expect(
        added.singleWhere((task) => task.title == 'Gym').dueDate,
        '2026-11-22',
      );
      expect(find.byKey(const Key('today-add-field')), findsNothing);
      expect(find.text('Gym'), findsOneWidget);

      await _tap(tester, 'today-tasks-back');
      await _settle(tester);
      expect(find.text('Today · 0'), findsOneWidget);
    });

    _test('Today: a project opens that project, not the list', (tester) async {
      final id = await _read(
        tester,
        () => _plan.addProject(
          userId: _user,
          name: 'Korea',
          color: 'blue',
          deadline: '2026-12-01',
        ),
      );
      await _pump(tester, AppPage.today);
      expect(find.textContaining('Due '), findsWidgets);

      await _tap(tester, 'today-project-$id');
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PageHost)),
      );
      expect(container.read(openProjectRequestProvider), id);
      expect(container.read(currentPageProvider), AppPage.projects);
    });

    _test('Today shows the day progress and the bedtime from Settings', (
      tester,
    ) async {
      await _read(
        tester,
        () => _capture.saveDayTimes(userId: _user, wake: '06:00', bed: '22:00'),
      );
      await _pump(tester, AppPage.today);
      // The clock is 12:00, six hours after waking: 25%.
      expect(find.text('Day progress · 25%'), findsOneWidget);
      expect(find.text('Bedtime 10:00 PM'), findsOneWidget);
    });

    _test('the Projects page opens the project another page asked for', (
      tester,
    ) async {
      final id = await _read(
        tester,
        () => _plan.addProject(userId: _user, name: 'Korea', color: 'blue'),
      );
      await _pump(tester, AppPage.projects);
      expect(find.byKey(const Key('project-back')), findsNothing);

      ProviderScope.containerOf(tester.element(find.byType(PageHost)))
          .read(openProjectRequestProvider.notifier)
          .ask(id);
      await _settle(tester);
      expect(find.byKey(const Key('project-back')), findsOneWidget);
    });
  });
}
