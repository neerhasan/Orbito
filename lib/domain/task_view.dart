/// How the Tasks page filters, sorts and groups tasks, counts completed
/// tasks for the chart, and lays out a month. Plain functions, no screen.
library;

import '../data/local/app_database.dart';
import 'dates.dart';

enum StatusFilter {
  open('Open'),
  done('Done'),
  all('All tasks');

  const StatusFilter(this.label);
  final String label;
}

enum TaskGrouping {
  dueDate('Due date'),
  project('Project'),
  goal('Goal'),
  priority('Priority'),
  none('None');

  const TaskGrouping(this.label);
  final String label;
}

enum TaskSorting {
  dueDate('Due date'),
  priority('Priority'),
  newest('Newest'),
  title('Title');

  const TaskSorting(this.label);
  final String label;
}

/// Which tasks to show. A null project, goal or priority means "any".
class TaskFilter {
  const TaskFilter({
    this.status = StatusFilter.open,
    this.projectId,
    this.goalId,
    this.priority,
  });

  final StatusFilter status;
  final String? projectId;
  final String? goalId;
  final String? priority;
}

/// The goal a task serves: the goal of its project. A task never links to
/// a goal itself.
String? goalIdOfTask(Task task, List<Project> projects) {
  for (final project in projects) {
    if (project.id == task.projectId) return project.goalId;
  }
  return null;
}

List<Task> filterTasks(
  List<Task> tasks,
  TaskFilter filter, {
  required List<Project> projects,
}) {
  return [
    for (final task in tasks)
      if ((filter.status == StatusFilter.all ||
              (filter.status == StatusFilter.done) ==
                  (task.status == TaskStatus.done)) &&
          (filter.projectId == null || task.projectId == filter.projectId) &&
          (filter.goalId == null ||
              goalIdOfTask(task, projects) == filter.goalId) &&
          (filter.priority == null || task.priority == filter.priority))
        task,
  ];
}

int _priorityRank(String priority) => switch (priority) {
  TaskPriority.high => 0,
  TaskPriority.medium => 1,
  _ => 2,
};

/// Tasks with a date come first, earliest first. Tasks without one are last.
int _byDueDate(Task a, Task b) {
  final dateA = a.dueDate;
  final dateB = b.dueDate;
  if (dateA == null && dateB == null) return 0;
  if (dateA == null) return 1;
  if (dateB == null) return -1;
  return dateA.compareTo(dateB);
}

int _byCreated(Task a, Task b) {
  final byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// A sorted copy of [tasks]. Ties keep the order the tasks were made in.
List<Task> sortTasks(List<Task> tasks, TaskSorting sorting) {
  int compare(Task a, Task b) {
    final first = switch (sorting) {
      TaskSorting.dueDate => _byDueDate(a, b),
      TaskSorting.priority => _priorityRank(
        a.priority,
      ).compareTo(_priorityRank(b.priority)),
      TaskSorting.newest => _byCreated(b, a),
      TaskSorting.title => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
    };
    if (first != 0) return first;
    if (sorting == TaskSorting.priority) {
      final byDate = _byDueDate(a, b);
      if (byDate != 0) return byDate;
    }
    return _byCreated(a, b);
  }

  return [...tasks]..sort(compare);
}

/// One block of the task list, with the heading above it.
class TaskGroup {
  const TaskGroup(this.label, this.tasks, {this.now = false});

  /// Empty when the list is not grouped.
  final String label;
  final List<Task> tasks;

  /// True for "Overdue" and "Today": the groups that need attention now.
  final bool now;
}

/// Splits [tasks] into groups and keeps the order of the tasks inside each
/// group. Groups without tasks are left out. [today] is a day key.
List<TaskGroup> groupTasks(
  List<Task> tasks,
  TaskGrouping grouping, {
  required String today,
  required List<Project> projects,
  required List<Goal> goals,
}) {
  if (tasks.isEmpty) return const [];

  List<TaskGroup> build(
    List<(String key, String label, bool now)> order,
    String Function(Task) keyOf,
  ) {
    final byKey = <String, List<Task>>{};
    for (final task in tasks) {
      byKey.putIfAbsent(keyOf(task), () => []).add(task);
    }
    return [
      for (final (key, label, now) in order)
        if (byKey[key] != null) TaskGroup(label, byKey[key]!, now: now),
    ];
  }

  switch (grouping) {
    case TaskGrouping.none:
      return [TaskGroup('', tasks)];
    case TaskGrouping.priority:
      return build(const [
        (TaskPriority.high, 'High', false),
        (TaskPriority.medium, 'Medium', false),
        (TaskPriority.none, 'No priority', false),
      ], (task) => task.priority);
    case TaskGrouping.project:
      final known = {for (final project in projects) project.id};
      return build([
        for (final project in projects) (project.id, project.name, false),
        ('', 'No project', false),
      ], (task) => known.contains(task.projectId) ? task.projectId! : '');
    case TaskGrouping.goal:
      final known = {for (final goal in goals) goal.id};
      return build(
        [
          for (final goal in goals) (goal.id, goal.title, false),
          ('', 'No goal', false),
        ],
        (task) {
          final goalId = goalIdOfTask(task, projects);
          return known.contains(goalId) ? goalId! : '';
        },
      );
    case TaskGrouping.dueDate:
      final tomorrow = addDays(today, 1);
      final weekEnd = addDays(today, 7);
      return build(
        const [
          ('overdue', 'Overdue', true),
          ('today', 'Today', true),
          ('tomorrow', 'Tomorrow', false),
          ('week', 'Next 7 days', false),
          ('later', 'Later', false),
          ('earlier', 'Earlier', false),
          ('none', 'No date', false),
        ],
        (task) {
          final due = task.dueDate;
          if (due == null) return 'none';
          if (due.compareTo(today) < 0) {
            return task.status == TaskStatus.done ? 'earlier' : 'overdue';
          }
          if (due == today) return 'today';
          if (due == tomorrow) return 'tomorrow';
          return due.compareTo(weekEnd) <= 0 ? 'week' : 'later';
        },
      );
  }
}

/// True when an open task is due today or earlier.
bool isDueNow(Task task, String today) {
  final due = task.dueDate;
  return due != null &&
      task.status != TaskStatus.done &&
      due.compareTo(today) <= 0;
}

/// How far back the "tasks completed" chart looks.
enum ChartRange {
  week('Week', 'Last 7 days'),
  twoWeeks('2 weeks', 'Last 14 days'),
  month('Month', 'Last 30 days'),
  year('Year', 'Last 12 months');

  const ChartRange(this.label, this.title);
  final String label;
  final String title;

  /// The number of points: days, or months for [year].
  int get points => switch (this) {
    week => 7,
    twoWeeks => 14,
    month => 30,
    year => 12,
  };
}

class ChartPoint {
  const ChartPoint(this.label, this.count, {this.current = false});

  /// The day of the month, or the short month name for a year.
  final String label;
  final int count;

  /// True for today, or for this month in the year chart.
  final bool current;
}

/// Tasks completed per day (per month for a year), oldest first, ending
/// today. A task counts on the day it was completed, in the device's time
/// zone. [today] is a day key.
List<ChartPoint> completionSeries(
  List<Task> tasks,
  ChartRange range, {
  required String today,
}) {
  final perDay = <String, int>{};
  for (final task in tasks) {
    if (task.status != TaskStatus.done) continue;
    final day = dayKeyOfStoredTime(task.completedAt);
    if (day != null) perDay[day] = (perDay[day] ?? 0) + 1;
  }

  if (range == ChartRange.year) {
    final now = parseDayKey(today)!;
    return [
      for (var back = range.points - 1; back >= 0; back--)
        () {
          final month = DateTime(now.year, now.month - back);
          final prefix = dayKey(month).substring(0, 7);
          var count = 0;
          perDay.forEach((day, done) {
            if (day.startsWith(prefix)) count += done;
          });
          return ChartPoint(
            monthNames[month.month - 1].substring(0, 3),
            count,
            current: back == 0,
          );
        }(),
    ];
  }

  return [
    for (var back = range.points - 1; back >= 0; back--)
      () {
        final day = addDays(today, -back);
        return ChartPoint(
          '${parseDayKey(day)!.day}',
          perDay[day] ?? 0,
          current: back == 0,
        );
      }(),
  ];
}

/// The line under the chart title, for example
/// `Last 14 days · 3 done · 0.2 a day`.
String chartSummary(ChartRange range, List<ChartPoint> points) {
  final total = points.fold(0, (sum, point) => sum + point.count);
  final average = points.isEmpty ? 0.0 : total / points.length;
  final unit = range == ChartRange.year ? 'a month' : 'a day';
  return '${range.title} · $total done · ${average.toStringAsFixed(1)} $unit';
}

/// The cells of a month calendar, week by week, Monday first. Each cell is
/// a day key, or null for the empty cells before the 1st and after the
/// last day.
List<String?> monthCells(int year, int month) {
  final first = DateTime(year, month);
  final days = DateTime(year, month + 1, 0).day;
  final cells = <String?>[
    for (var i = 1; i < first.weekday; i++) null,
    for (var day = 1; day <= days; day++) dayKey(DateTime(year, month, day)),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}
