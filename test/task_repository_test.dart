import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late int counter;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    tasks = TaskRepository(
      db,
      newId: () => 'task-${++counter}',
      now: () => DateTime.utc(2026, 11, 11, 10, 0, counter),
    );
  });

  tearDown(() => db.close());

  test('a new task is open, trimmed and has no completion time', () async {
    final id = await tasks.addTask(
      userId: 'user-a',
      title: '  Call the bank  ',
      projectId: 'project-1',
      dueDate: '2026-11-20',
      priority: TaskPriority.high,
    );

    final task = (await tasks.watchTasks('user-a').first).single;
    expect(task.id, id);
    expect(task.title, 'Call the bank');
    expect(task.projectId, 'project-1');
    expect(task.goalId, isNull);
    expect(task.dueDate, '2026-11-20');
    expect(task.priority, TaskPriority.high);
    expect(task.status, TaskStatus.open);
    expect(task.completedAt, isNull);
    expect(task.createdAt, '2026-11-11T10:00:01.000Z');
    expect(task.deletedAt, isNull);
  });

  test('an empty title is refused and nothing is saved', () async {
    await expectLater(
      tasks.addTask(userId: 'user-a', title: '   '),
      throwsArgumentError,
    );
    expect(await tasks.watchTasks('user-a').first, isEmpty);
  });

  test('an unknown priority is refused', () async {
    await expectLater(
      tasks.addTask(userId: 'user-a', title: 'Task', priority: 'urgent'),
      throwsArgumentError,
    );
  });

  test('a task can be edited, and links can be removed', () async {
    final id = await tasks.addTask(
      userId: 'user-a',
      title: 'Old',
      projectId: 'project-1',
      dueDate: '2026-11-20',
    );

    await tasks.updateTask(
      id,
      title: 'New',
      projectId: null,
      dueDate: null,
      priority: TaskPriority.medium,
    );

    final task = (await tasks.watchTasks('user-a').first).single;
    expect(task.title, 'New');
    expect(task.projectId, isNull);
    expect(task.dueDate, isNull);
    expect(task.priority, TaskPriority.medium);
  });

  test('editing to an empty title is refused and keeps the old one', () async {
    final id = await tasks.addTask(userId: 'user-a', title: 'Keep me');

    expect(
      () => tasks.updateTask(
        id,
        title: ' ',
        projectId: null,
        dueDate: null,
        priority: TaskPriority.none,
      ),
      throwsArgumentError,
    );
    expect((await tasks.watchTasks('user-a').first).single.title, 'Keep me');
  });

  test(
    'completing sets the status and the time; undoing clears them',
    () async {
      final id = await tasks.addTask(userId: 'user-a', title: 'Task');

      await tasks.setDone(id, done: true);
      var task = (await tasks.watchTasks('user-a').first).single;
      expect(task.status, TaskStatus.done);
      expect(task.completedAt, '2026-11-11T10:00:01.000Z');

      await tasks.setDone(id, done: false);
      task = (await tasks.watchTasks('user-a').first).single;
      expect(task.status, TaskStatus.open);
      expect(task.completedAt, isNull);
    },
  );

  test('a deleted task is hidden but stays in the database', () async {
    final id = await tasks.addTask(userId: 'user-a', title: 'Gone');
    await tasks.addTask(userId: 'user-a', title: 'Kept');

    await tasks.deleteTask(id);

    final visible = await tasks.watchTasks('user-a').first;
    expect(visible.map((task) => task.title), ['Kept']);
    final all = await db.select(db.tasks).get();
    expect(all, hasLength(2));
    expect(all.firstWhere((task) => task.id == id).deletedAt, isNotNull);
  });

  test('a user never sees another user\'s tasks', () async {
    await tasks.addTask(userId: 'user-a', title: 'Private to a');
    await tasks.addTask(userId: 'user-b', title: 'Private to b');

    final forA = await tasks.watchTasks('user-a').first;
    final forB = await tasks.watchTasks('user-b').first;
    expect(forA.map((task) => task.title), ['Private to a']);
    expect(forB.map((task) => task.title), ['Private to b']);
  });

  test('the list updates by itself when a task is added', () async {
    final updates = tasks.watchTasks('user-a').map((rows) => rows.length);
    final seen = expectLater(updates, emitsInOrder([0, 1]));
    await pumpEventQueue();
    await tasks.addTask(userId: 'user-a', title: 'Live');
    await seen;
  });
}
