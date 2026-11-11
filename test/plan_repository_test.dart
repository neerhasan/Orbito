import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/plan_repository.dart';
import 'package:orbito/data/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late PlanRepository plan;
  late TaskRepository tasks;
  late int counter;

  const user = 'user-a';

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    String newId() => 'id-${++counter}';
    DateTime now() => DateTime.utc(2026, 11, 11, 10, 0, counter);
    plan = PlanRepository(db, newId: newId, now: now);
    tasks = TaskRepository(db, newId: newId, now: now);
  });

  tearDown(() => db.close());

  /// Builds area -> goal -> project -> task, plus a task linked straight to
  /// the goal. Returns the ids.
  Future<
    ({String area, String goal, String project, String task, String goalTask})
  >
  buildChain() async {
    final area = await plan.addArea(
      userId: user,
      name: 'Health',
      color: 'green',
    );
    final goal = await plan.addGoal(
      userId: user,
      title: 'Run 10 km',
      lifeAreaId: area,
    );
    final project = await plan.addProject(
      userId: user,
      name: 'Training plan',
      color: 'blue',
      goalId: goal,
    );
    final task = await tasks.addTask(
      userId: user,
      title: 'Buy shoes',
      projectId: project,
    );
    final goalTask = await tasks.addTask(
      userId: user,
      title: 'Book the race',
      goalId: goal,
    );
    return (
      area: area,
      goal: goal,
      project: project,
      task: task,
      goalTask: goalTask,
    );
  }

  group('create and edit', () {
    test('the full chain can be built and read back', () async {
      final ids = await buildChain();

      final area = (await plan.watchAreas(user).first).single;
      final goal = (await plan.watchGoals(user).first).single;
      final project = (await plan.watchProjects(user).first).single;
      expect(area.name, 'Health');
      expect(area.color, 'green');
      expect(goal.lifeAreaId, ids.area);
      expect(goal.progress, 0);
      expect(project.goalId, ids.goal);
      expect(project.color, 'blue');
    });

    test('names are trimmed and empty names are refused', () async {
      await plan.addArea(userId: user, name: '  Career  ', color: 'blue');
      expect((await plan.watchAreas(user).first).single.name, 'Career');

      await expectLater(
        plan.addArea(userId: user, name: ' ', color: 'blue'),
        throwsArgumentError,
      );
      await expectLater(
        plan.addGoal(userId: user, title: ''),
        throwsArgumentError,
      );
      await expectLater(
        plan.addProject(userId: user, name: '  ', color: 'blue'),
        throwsArgumentError,
      );
      expect(await plan.watchAreas(user).first, hasLength(1));
      expect(await plan.watchGoals(user).first, isEmpty);
      expect(await plan.watchProjects(user).first, isEmpty);
    });

    test('an area, a goal and a project can be edited', () async {
      final ids = await buildChain();
      final otherArea = await plan.addArea(
        userId: user,
        name: 'Career',
        color: 'blue',
      );

      await plan.updateArea(ids.area, name: 'Body', color: 'pink');
      await plan.updateGoal(
        ids.goal,
        title: 'Run 21 km',
        lifeAreaId: otherArea,
        targetDate: '2027-06-30',
        doneWhen: '  Finished a half marathon  ',
      );
      await plan.updateProject(
        ids.project,
        name: 'Plan B',
        color: 'teal',
        goalId: null,
      );

      final areas = await plan.watchAreas(user).first;
      final goal = (await plan.watchGoals(user).first).single;
      final project = (await plan.watchProjects(user).first).single;
      expect(areas.first.name, 'Body');
      expect(areas.first.color, 'pink');
      expect(goal.title, 'Run 21 km');
      expect(goal.lifeAreaId, otherArea);
      expect(goal.targetDate, '2027-06-30');
      expect(goal.doneWhen, 'Finished a half marathon');
      expect(project.name, 'Plan B');
      expect(project.color, 'teal');
      expect(project.goalId, isNull);
    });

    test('goal progress stays between 0 and 100', () async {
      final goal = await plan.addGoal(userId: user, title: 'Goal');

      await plan.setGoalProgress(goal, 45);
      expect((await plan.watchGoals(user).first).single.progress, 45);
      await plan.setGoalProgress(goal, 250);
      expect((await plan.watchGoals(user).first).single.progress, 100);
      await plan.setGoalProgress(goal, -5);
      expect((await plan.watchGoals(user).first).single.progress, 0);
    });

    test('a user never sees another user\'s items', () async {
      await buildChain();

      expect(await plan.watchAreas('user-b').first, isEmpty);
      expect(await plan.watchGoals('user-b').first, isEmpty);
      expect(await plan.watchProjects('user-b').first, isEmpty);
    });
  });

  group('the delete warning counts linked items', () {
    test('counts for an area, a goal and a project', () async {
      final ids = await buildChain();

      expect(await plan.countGoalsOfArea(ids.area), 1);
      expect(await plan.countLinkedToGoal(ids.goal), (projects: 1, tasks: 1));
      expect(await plan.countTasksOfProject(ids.project), 1);
    });

    test('deleted items are not counted', () async {
      final ids = await buildChain();
      await tasks.deleteTask(ids.task);

      expect(await plan.countTasksOfProject(ids.project), 0);
    });
  });

  group('deleting and keeping the linked items', () {
    test('a deleted project leaves its tasks without a project', () async {
      final ids = await buildChain();

      await plan.deleteProject(ids.project, linked: LinkedItems.keep);

      expect(await plan.watchProjects(user).first, isEmpty);
      final remaining = await tasks.watchTasks(user).first;
      expect(remaining, hasLength(2));
      expect(remaining.firstWhere((t) => t.id == ids.task).projectId, isNull);
    });

    test('a deleted goal unlinks its projects and tasks', () async {
      final ids = await buildChain();

      await plan.deleteGoal(ids.goal, linked: LinkedItems.keep);

      expect(await plan.watchGoals(user).first, isEmpty);
      expect((await plan.watchProjects(user).first).single.goalId, isNull);
      final remaining = await tasks.watchTasks(user).first;
      expect(remaining, hasLength(2));
      expect(remaining.firstWhere((t) => t.id == ids.goalTask).goalId, isNull);
      expect(
        remaining.firstWhere((t) => t.id == ids.task).projectId,
        ids.project,
      );
    });

    test('a deleted area unlinks its goals', () async {
      final ids = await buildChain();

      await plan.deleteArea(ids.area, linked: LinkedItems.keep);

      expect(await plan.watchAreas(user).first, isEmpty);
      expect((await plan.watchGoals(user).first).single.lifeAreaId, isNull);
      expect(await plan.watchProjects(user).first, hasLength(1));
      expect(await tasks.watchTasks(user).first, hasLength(2));
    });
  });

  group('deleting together with the linked items', () {
    test('a deleted project takes its tasks with it', () async {
      final ids = await buildChain();

      await plan.deleteProject(ids.project, linked: LinkedItems.delete);

      final remaining = await tasks.watchTasks(user).first;
      expect(remaining.map((t) => t.id), [ids.goalTask]);
    });

    test('a deleted goal takes its projects and all their tasks', () async {
      await buildChain();
      final goal = (await plan.watchGoals(user).first).single;

      await plan.deleteGoal(goal.id, linked: LinkedItems.delete);

      expect(await plan.watchGoals(user).first, isEmpty);
      expect(await plan.watchProjects(user).first, isEmpty);
      expect(await tasks.watchTasks(user).first, isEmpty);
      expect(await plan.watchAreas(user).first, hasLength(1));
    });

    test('a deleted area takes the whole chain below it', () async {
      final ids = await buildChain();
      final unrelated = await tasks.addTask(userId: user, title: 'Unrelated');

      await plan.deleteArea(ids.area, linked: LinkedItems.delete);

      expect(await plan.watchAreas(user).first, isEmpty);
      expect(await plan.watchGoals(user).first, isEmpty);
      expect(await plan.watchProjects(user).first, isEmpty);
      final remaining = await tasks.watchTasks(user).first;
      expect(remaining.map((t) => t.id), [unrelated]);
    });

    test('deleted rows stay in the database with a delete mark', () async {
      final ids = await buildChain();

      await plan.deleteArea(ids.area, linked: LinkedItems.delete);

      final allTasks = await db.select(db.tasks).get();
      final allGoals = await db.select(db.goals).get();
      expect(allTasks, hasLength(2));
      expect(allTasks.every((t) => t.deletedAt != null), isTrue);
      expect(allGoals.single.deletedAt, isNotNull);
    });
  });
}
