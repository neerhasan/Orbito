import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/progress.dart';

const _time = '2026-11-11T10:00:00.000Z';

Task _task(String id, {String? projectId, String? goalId, bool done = false}) =>
    Task(
      id: id,
      userId: 'user-a',
      title: 'Task $id',
      projectId: projectId,
      goalId: goalId,
      priority: TaskPriority.none,
      status: done ? TaskStatus.done : TaskStatus.open,
      createdAt: _time,
      updatedAt: _time,
    );

Project _project(String id, {String? goalId}) => Project(
  id: id,
  userId: 'user-a',
  name: 'Project $id',
  goalId: goalId,
  color: 'blue',
  createdAt: _time,
  updatedAt: _time,
);

void main() {
  group('percentDone', () {
    test('is 0 with no tasks', () {
      expect(percentDone(const []), 0);
    });

    test('is the rounded share of tasks done', () {
      final tasks = [_task('1', done: true), _task('2'), _task('3')];
      expect(percentDone(tasks), 33);
      expect(percentDone([_task('1', done: true)]), 100);
    });
  });

  group('tasksOfGoal', () {
    test('takes only the tasks of the goal\'s projects', () {
      final projects = [
        _project('p1', goalId: 'g1'),
        _project('p2', goalId: 'g2'),
        _project('p3'),
      ];
      final tasks = [
        _task('direct', goalId: 'g1'),
        _task('through-project', projectId: 'p1'),
        _task('other-goal', projectId: 'p2'),
        _task('other-direct', goalId: 'g2'),
        _task('no-goal', projectId: 'p3'),
        _task('loose'),
      ];

      final found = tasksOfGoal('g1', projects: projects, tasks: tasks);

      // 'direct' carries an old link straight to the goal. It does not count.
      expect(found.map((task) => task.id), ['through-project']);
    });

    test('counts a task once when it also carries an old goal link', () {
      final projects = [_project('p1', goalId: 'g1')];
      final tasks = [_task('both', projectId: 'p1', goalId: 'g1')];

      expect(tasksOfGoal('g1', projects: projects, tasks: tasks), hasLength(1));
    });
  });
}
