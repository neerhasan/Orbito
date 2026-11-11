import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/app.dart';
import 'package:orbito/app/providers.dart';
import 'package:orbito/app/shell.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';
import 'package:orbito/ui/ember.dart';

const _user = 'user-a';

late AppDatabase _db;
late PlanRepository _plan;
late TaskRepository _tasks;

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

/// Shows one page of the app on top of a real, empty, in-memory database.
Future<void> _pumpPage(WidgetTester tester, AppPage page) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(_db),
        planRepositoryProvider.overrideWithValue(_plan),
        taskRepositoryProvider.overrideWithValue(_tasks),
        userIdProvider.overrideWithValue(_user),
        firstSyncDoneProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: Ember.theme(),
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
    _db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    String newId() => 'id-${++counter}';
    DateTime now() => DateTime.utc(2026, 11, 11, 10, 0, counter);
    _plan = PlanRepository(_db, newId: newId, now: now);
    _tasks = TaskRepository(_db, newId: newId, now: now);

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
  group('first-run setup', () {
    _testPage('adds the picked areas, then shows the page', (tester) async {
      await _pumpPage(tester, AppPage.areas);
      expect(
        find.text('Which parts of your life do you want to look after?'),
        findsOneWidget,
      );
      expect(find.text('Pick at least one area'), findsOneWidget);
      expect(find.byKey(const Key('setup-waiting')), findsNothing);

      await _tap(tester, 'suggest-Health');
      await _tap(tester, 'suggest-Mind');
      expect(find.text('Add 2 areas'), findsOneWidget);

      await _tap(tester, 'setup-add');
      await _settle(tester);

      final saved = await _read(tester, () => _plan.watchAreas(_user).first);
      expect(saved.map((area) => area.name), ['Health', 'Mind']);
      expect(saved.map((area) => area.color).toSet().length, 2);
      expect(find.text('Life areas'), findsOneWidget);
      expect(find.text('2 areas'), findsOneWidget);
    });

    _testPage('can be skipped', (tester) async {
      await _pumpPage(tester, AppPage.areas);

      await _tap(tester, 'setup-skip');
      await _settle(tester);

      expect(find.text('No life areas yet'), findsOneWidget);
      final saved = await _read(tester, () => _plan.watchAreas(_user).first);
      expect(saved, isEmpty);
    });
  });

  group('the Life areas page', () {
    _testPage('adds an area and refuses an empty name', (tester) async {
      await _read(
        tester,
        () => _plan.addArea(userId: _user, name: 'Health', color: 'green'),
      );
      await _pumpPage(tester, AppPage.areas);
      expect(find.text('1 area'), findsOneWidget);

      await _tap(tester, 'area-save');
      expect(find.text('Give the area a name.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('area-name')), 'Money');
      await _tap(tester, 'area-save');
      await _settle(tester);

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('2 areas'), findsOneWidget);
      expect(find.text('Give the area a name.'), findsNothing);
    });

    _testPage('deleting an area can keep its goals', (tester) async {
      final ids = await _read(tester, () async {
        final area = await _plan.addArea(
          userId: _user,
          name: 'Health',
          color: 'green',
        );
        await _plan.addArea(userId: _user, name: 'Mind', color: 'blue');
        await _plan.addGoal(
          userId: _user,
          title: 'Run 10 km',
          lifeAreaId: area,
        );
        return area;
      });
      await _pumpPage(tester, AppPage.areas);
      expect(find.text('1 goal'), findsOneWidget);

      await _tap(tester, 'area-$ids');
      await _tap(tester, 'area-delete');
      expect(find.textContaining('1 goal belong'), findsOneWidget);
      await _tap(tester, 'linked-keep');
      await _settle(tester);

      expect(find.byKey(Key('area-$ids')), findsNothing);
      expect(find.text('1 area'), findsOneWidget);
      final goals = await _read(tester, () => _plan.watchGoals(_user).first);
      expect(goals.single.title, 'Run 10 km');
      expect(goals.single.lifeAreaId, isNull);
    });
  });

  group('the Projects page', () {
    _testPage('adds a project with a colour, then a task', (tester) async {
      await _read(
        tester,
        () => _plan.addArea(userId: _user, name: 'Health', color: 'green'),
      );
      await _pumpPage(tester, AppPage.projects);
      expect(find.text('No projects yet'), findsOneWidget);

      await _tap(tester, 'project-save');
      expect(find.text('Give the project a name.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('project-name')),
        'Training plan',
      );
      await _tap(tester, 'color-teal');
      await _tap(tester, 'project-save');
      await _settle(tester);

      final projects = await _read(
        tester,
        () => _plan.watchProjects(_user).first,
      );
      expect(projects.single.name, 'Training plan');
      expect(projects.single.color, 'teal');
      expect(find.text('Training plan'), findsOneWidget);
      expect(find.text('0 of 0 tasks'), findsOneWidget);

      await _tap(tester, 'project-${projects.single.id}');
      expect(find.text('Edit project'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('project-new-task')),
        'Buy shoes',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(find.text('Buy shoes'), findsOneWidget);
      expect(find.text('0 of 1 task'), findsOneWidget);
    });
  });
}
