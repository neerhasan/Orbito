import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/domain/task_view.dart';

const _today = '2026-11-11';

/// Noon in the device's time zone on [day], as a stored time. Noon keeps
/// the day the same in every time zone the tests may run in.
String _noon(String day) {
  final parts = day.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2], 12).toUtc().toIso8601String();
}

Task _task(
  String id, {
  String? title,
  String? projectId,
  String? goalId,
  String? due,
  String priority = TaskPriority.none,
  String? doneOn,
  String created = '2026-11-01T10:00:00.000Z',
}) => Task(
  id: id,
  userId: 'user-a',
  title: title ?? 'Task $id',
  projectId: projectId,
  goalId: goalId,
  dueDate: due,
  priority: priority,
  status: doneOn == null ? TaskStatus.open : TaskStatus.done,
  completedAt: doneOn == null ? null : _noon(doneOn),
  createdAt: created,
  updatedAt: created,
);

Project _project(String id, {String? goalId}) => Project(
  id: id,
  userId: 'user-a',
  name: 'Project $id',
  goalId: goalId,
  color: 'blue',
  createdAt: '2026-11-01T10:00:00.000Z',
  updatedAt: '2026-11-01T10:00:00.000Z',
);

Goal _goal(String id) => Goal(
  id: id,
  userId: 'user-a',
  title: 'Goal $id',
  progress: 0,
  createdAt: '2026-11-01T10:00:00.000Z',
  updatedAt: '2026-11-01T10:00:00.000Z',
);

List<String> _ids(List<Task> tasks) => [for (final task in tasks) task.id];

void main() {
  group('filterTasks', () {
    final projects = [_project('p1', goalId: 'g1'), _project('p2')];
    final tasks = [
      _task('open'),
      _task('done', doneOn: _today),
      _task('in-p1', projectId: 'p1'),
      _task('direct-g1', goalId: 'g1'),
      _task('high', priority: TaskPriority.high, projectId: 'p2'),
    ];

    test('shows open tasks by default', () {
      final found = filterTasks(tasks, const TaskFilter(), projects: projects);
      expect(_ids(found), ['open', 'in-p1', 'direct-g1', 'high']);
    });

    test('filters by status', () {
      expect(
        _ids(
          filterTasks(
            tasks,
            const TaskFilter(status: StatusFilter.done),
            projects: projects,
          ),
        ),
        ['done'],
      );
      expect(
        filterTasks(
          tasks,
          const TaskFilter(status: StatusFilter.all),
          projects: projects,
        ),
        hasLength(5),
      );
    });

    test('filters by project', () {
      final found = filterTasks(
        tasks,
        const TaskFilter(projectId: 'p1'),
        projects: projects,
      );
      expect(_ids(found), ['in-p1']);
    });

    test('a goal filter also finds tasks of the goal\'s projects', () {
      final found = filterTasks(
        tasks,
        const TaskFilter(goalId: 'g1'),
        projects: projects,
      );
      expect(_ids(found), ['in-p1', 'direct-g1']);
    });

    test('filters by priority, and filters combine', () {
      expect(
        _ids(
          filterTasks(
            tasks,
            const TaskFilter(priority: TaskPriority.high),
            projects: projects,
          ),
        ),
        ['high'],
      );
      expect(
        filterTasks(
          tasks,
          const TaskFilter(priority: TaskPriority.high, projectId: 'p1'),
          projects: projects,
        ),
        isEmpty,
      );
    });
  });

  group('sortTasks', () {
    final tasks = [
      _task('b', title: 'banana', due: '2026-11-20', created: '2026-11-02'),
      _task(
        'a',
        title: 'Apple',
        priority: TaskPriority.high,
        created: '2026-11-03',
      ),
      _task(
        'c',
        title: 'cherry',
        due: '2026-11-12',
        priority: TaskPriority.medium,
        created: '2026-11-01',
      ),
    ];

    test('by due date puts tasks without a date last', () {
      expect(_ids(sortTasks(tasks, TaskSorting.dueDate)), ['c', 'b', 'a']);
    });

    test('by priority goes high, medium, none', () {
      expect(_ids(sortTasks(tasks, TaskSorting.priority)), ['a', 'c', 'b']);
    });

    test('by newest and by title', () {
      expect(_ids(sortTasks(tasks, TaskSorting.newest)), ['a', 'b', 'c']);
      expect(_ids(sortTasks(tasks, TaskSorting.title)), ['a', 'b', 'c']);
    });

    test('does not change the list it was given', () {
      sortTasks(tasks, TaskSorting.dueDate);
      expect(_ids(tasks), ['b', 'a', 'c']);
    });
  });

  group('groupTasks', () {
    List<String> labels(List<TaskGroup> groups) => [
      for (final group in groups)
        '${group.label}:${_ids(group.tasks).join(',')}',
    ];

    test('by due date', () {
      final groups = groupTasks(
        [
          _task('late', due: '2026-11-10'),
          _task('today', due: _today),
          _task('tomorrow', due: '2026-11-12'),
          _task('week', due: '2026-11-18'),
          _task('later', due: '2026-11-19'),
          _task('none'),
          _task('done-late', due: '2026-11-01', doneOn: '2026-11-02'),
        ],
        TaskGrouping.dueDate,
        today: _today,
        projects: const [],
        goals: const [],
      );

      expect(labels(groups), [
        'Overdue:late',
        'Today:today',
        'Tomorrow:tomorrow',
        'Next 7 days:week',
        'Later:later',
        'Earlier:done-late',
        'No date:none',
      ]);
      expect(
        [for (final group in groups) group.now],
        [true, true, false, false, false, false, false],
      );
    });

    test('by project, goal and priority, leaving out empty groups', () {
      final projects = [_project('p1', goalId: 'g1'), _project('p2')];
      final goals = [_goal('g1'), _goal('g2')];
      final tasks = [
        _task('1', projectId: 'p1'),
        _task('2', goalId: 'g2', priority: TaskPriority.high),
        _task('3'),
      ];

      expect(
        labels(
          groupTasks(
            tasks,
            TaskGrouping.project,
            today: _today,
            projects: projects,
            goals: goals,
          ),
        ),
        ['Project p1:1', 'No project:2,3'],
      );
      expect(
        labels(
          groupTasks(
            tasks,
            TaskGrouping.goal,
            today: _today,
            projects: projects,
            goals: goals,
          ),
        ),
        ['Goal g1:1', 'Goal g2:2', 'No goal:3'],
      );
      expect(
        labels(
          groupTasks(
            tasks,
            TaskGrouping.priority,
            today: _today,
            projects: projects,
            goals: goals,
          ),
        ),
        ['High:2', 'No priority:1,3'],
      );
    });

    test('with no grouping gives one group without a heading', () {
      final groups = groupTasks(
        [_task('1'), _task('2')],
        TaskGrouping.none,
        today: _today,
        projects: const [],
        goals: const [],
      );
      expect(labels(groups), [':1,2']);
    });

    test('with no tasks gives no groups', () {
      expect(
        groupTasks(
          const [],
          TaskGrouping.none,
          today: _today,
          projects: const [],
          goals: const [],
        ),
        isEmpty,
      );
    });
  });

  group('completionSeries', () {
    final tasks = [
      _task('1', doneOn: _today),
      _task('2', doneOn: _today),
      _task('3', doneOn: '2026-11-05'),
      _task('4', doneOn: '2026-10-20'),
      _task('5', doneOn: '2025-12-31'),
      _task('open'),
    ];

    test('counts completed tasks per day, ending today', () {
      final week = completionSeries(tasks, ChartRange.week, today: _today);
      expect([for (final point in week) point.count], [1, 0, 0, 0, 0, 0, 2]);
      expect([for (final point in week) point.label].first, '5');
      expect(week.last.label, '11');
      expect(week.last.current, isTrue);
      expect(week.where((point) => point.current), hasLength(1));
    });

    test('has 14 and 30 points for 2 weeks and a month', () {
      final twoWeeks = completionSeries(
        tasks,
        ChartRange.twoWeeks,
        today: _today,
      );
      final month = completionSeries(tasks, ChartRange.month, today: _today);
      expect(twoWeeks, hasLength(14));
      expect(month, hasLength(30));
      expect(month.fold(0, (sum, point) => sum + point.count), 4);
    });

    test('counts per month for a year', () {
      final year = completionSeries(tasks, ChartRange.year, today: _today);
      expect(year, hasLength(12));
      expect(year.first.label, 'Dec');
      expect(year.first.count, 1);
      expect(year.last.label, 'Nov');
      expect(year.last.count, 3);
      expect(year[10].count, 1);
    });

    test('the summary names the range, total and average', () {
      final week = completionSeries(tasks, ChartRange.week, today: _today);
      expect(
        chartSummary(ChartRange.week, week),
        'Last 7 days · 3 done · 0.4 a day',
      );
      final year = completionSeries(tasks, ChartRange.year, today: _today);
      expect(
        chartSummary(ChartRange.year, year),
        'Last 12 months · 5 done · 0.4 a month',
      );
    });
  });

  group('monthCells', () {
    test('starts on Monday and fills whole weeks', () {
      // 1 November 2026 is a Sunday.
      final cells = monthCells(2026, 11);
      expect(cells.length % 7, 0);
      expect(cells.take(6), everyElement(isNull));
      expect(cells[6], '2026-11-01');
      expect(cells.whereType<String>(), hasLength(30));
      expect(cells.whereType<String>().last, '2026-11-30');
    });

    test('handles a leap February', () {
      expect(monthCells(2028, 2).whereType<String>(), hasLength(29));
    });
  });

  test('isDueNow is true only for open tasks due today or earlier', () {
    expect(isDueNow(_task('1', due: _today), _today), isTrue);
    expect(isDueNow(_task('2', due: '2026-11-01'), _today), isTrue);
    expect(isDueNow(_task('3', due: '2026-11-12'), _today), isFalse);
    expect(isDueNow(_task('4'), _today), isFalse);
    expect(isDueNow(_task('5', due: _today, doneOn: _today), _today), isFalse);
  });
}
