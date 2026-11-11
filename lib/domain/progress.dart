/// How far a project or a goal is. Progress always comes from tasks done;
/// nobody sets it by hand. The rules live here so they are easy to change.
library;

import '../data/local/app_database.dart';

/// The share of [tasks] that are done, from 0 to 100.
int percentDone(List<Task> tasks) {
  if (tasks.isEmpty) return 0;
  final done = tasks.where((task) => task.status == TaskStatus.done).length;
  return (done * 100 / tasks.length).round();
}

/// The tasks that count for a goal: tasks linked straight to the goal, and
/// tasks of the projects that serve the goal. Each task counts once.
List<Task> tasksOfGoal(
  String goalId, {
  required List<Project> projects,
  required List<Task> tasks,
}) {
  final projectIds = {
    for (final project in projects)
      if (project.goalId == goalId) project.id,
  };
  return [
    for (final task in tasks)
      if (task.goalId == goalId || projectIds.contains(task.projectId)) task,
  ];
}
