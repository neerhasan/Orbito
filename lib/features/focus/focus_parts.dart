import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/focus_report.dart';
import '../../domain/sleep.dart' show formatTime, timeOf;
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The colour for time with no project: a quiet grey (orange is kept for
/// "now").
const noProjectSwatch = Swatch(Ember.ink3, Ember.neutral, Ember.ink2);

/// The colour a session shows in: its project's colour, or grey.
Swatch swatchOfProject(String? projectId, Map<String, Project> projects) {
  final project = projects[projectId];
  return project == null ? noProjectSwatch : ProjectColors.of(project.color);
}

/// `9:05 AM` from minutes after midnight.
String clockOfMinute(int minute) => formatTime(timeOf(minute % 1440));

/// `9:05 AM` from a stored time.
String clockOfStored(String stored) {
  final moment = parseStoredTime(stored);
  if (moment == null) return '';
  return clockOfMinute(moment.hour * 60 + moment.minute);
}

/// Today's sessions on a line: a thin 24-hour strip with a coloured mark
/// per session, then one row per session with its start time, task and
/// length (the inspiration's "Today's Focus Time Records").
class FocusDayRecords extends StatelessWidget {
  const FocusDayRecords({
    super.key,
    required this.sessions,
    required this.day,
    required this.tasks,
    required this.projects,
  });

  /// All sessions; the ones on [day] are shown.
  final List<FocusSession> sessions;
  final String day;
  final Map<String, Task> tasks;
  final Map<String, Project> projects;

  @override
  Widget build(BuildContext context) {
    final blocks = blocksOn(sessions, day);
    if (blocks.isEmpty) {
      return Text('No sessions yet today.', style: Ember.meta);
    }
    Swatch swatchOf(FocusSession session) =>
        swatchOfProject(projectOfSession(session, tasks), projects);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The whole day, midnight to midnight.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Container(
              height: 10,
              decoration: BoxDecoration(
                color: Ember.tile,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Stack(
                children: [
                  for (final block in blocks)
                    Positioned(
                      left: width * block.startMinute / 1440,
                      width: math.max(
                        3,
                        width * (block.endMinute - block.startMinute) / 1440,
                      ),
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: swatchOf(block.session).dot,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['12 AM', '6 AM', '12 PM', '6 PM', '12 AM'])
              Text(label, style: Ember.caption),
          ],
        ),
        const SizedBox(height: 12),
        for (final block in blocks.reversed)
          Padding(
            key: Key('focus-record-${block.session.id}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 66,
                  child: Text(
                    clockOfMinute(block.startMinute),
                    style: Ember.meta,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: swatchOf(block.session).soft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: swatchOf(block.session).dot,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tasks[block.session.taskId]?.title ?? 'No task',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ember.text(
                              12,
                              15,
                              color: swatchOf(block.session).text,
                            ),
                          ),
                        ),
                        Text(
                          formatWorked(block.session.focusSeconds),
                          style: Ember.text(
                            12,
                            15,
                            weight: 600,
                            color: swatchOf(block.session).text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small dots, one per session done on a task today (at most 8 shown).
class SessionDots extends StatelessWidget {
  const SessionDots({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final shown = math.min(count, 8);
    return Semantics(
      label: countOf(count, 'session'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ColorDot(color, size: 6),
            ),
          if (count > shown) Text('+${count - shown}', style: Ember.caption),
        ],
      ),
    );
  }
}

/// One open task in the Focus side panel: a done ring, the title with its
/// project and today's session dots, and a start button. Tapping the row
/// picks the task for the timer.
class FocusTaskRow extends StatelessWidget {
  const FocusTaskRow({
    super.key,
    required this.task,
    required this.project,
    required this.sessionsToday,
    required this.picked,
    required this.onPick,
    required this.onStart,
    required this.onDone,
  });

  final Task task;
  final Project? project;
  final int sessionsToday;
  final bool picked;
  final VoidCallback onPick;
  final VoidCallback onStart;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final swatch = project == null
        ? noProjectSwatch
        : ProjectColors.of(project!.color);
    return Tile(
      key: Key('focus-pick-${task.id}'),
      selected: picked,
      onTap: onPick,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          TaskRing(
            done: false,
            priority: task.priority,
            label: 'Complete ${task.title}',
            onTap: onDone,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.item.copyWith(color: Ember.ink),
                ),
                if (project != null || sessionsToday > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (project != null)
                        Flexible(
                          child: Text(
                            project!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ember.text(11, 13, color: swatch.text),
                          ),
                        ),
                      if (project != null && sessionsToday > 0)
                        const SizedBox(width: 8),
                      SessionDots(count: sessionsToday, color: swatch.dot),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: Key('focus-start-${task.id}'),
            tooltip: 'Start focus on ${task.title}',
            visualDensity: VisualDensity.compact,
            onPressed: onStart,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
            color: Ember.ink2,
          ),
        ],
      ),
    );
  }
}
