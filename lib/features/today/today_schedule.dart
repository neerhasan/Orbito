import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show AppPage, currentPageProvider;
import '../../data/local/app_database.dart';
import '../../domain/calendar.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/habits.dart' show isPlanned;
import '../../domain/sleep.dart' show formatTime, minutesOf, timeOf;
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import '../focus/focus_page.dart' show startFocus;

/// One hour on the schedule (the design's 60 px per hour).
const _hourHeight = 60.0;

/// The hour labels on the left.
const _gutter = 44.0;

/// How tall the schedule may grow before it scrolls (the design's 612 px).
const _viewport = 612.0;

/// A habit block's length.
const _habitMinutes = 30;

int _snap(int minutes) => (minutes / 15).round() * 15;

int _lengthOf(Task task) => math.max(15, task.durationMinutes ?? 30);

String _hours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// The Schedule section of Today (design: `Main.dc.html`, "Schedule"):
/// the day hour by hour, from waking to bedtime. It shows the same things
/// as the Calendar: events, tasks with a time and habits with a usual time.
/// Tasks are dragged here from the Tasks list (or moved, or made longer by
/// their bottom edge); a click on a task opens its options.
class TodaySchedule extends ConsumerStatefulWidget {
  const TodaySchedule({super.key, required this.day});

  /// The day shown (the day picked in the calendar on the right).
  final String day;

  @override
  ConsumerState<TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends ConsumerState<TodaySchedule> {
  final _scroll = ScrollController();
  Timer? _tick;

  /// Where a dragged task would land, and how long it is.
  int? _hoverStart;
  var _hoverLength = 30;

  /// A task whose bottom edge is being dragged, with its new end.
  ({String id, int end})? _resize;
  double _resizeDy = 0;

  var _scrolledOnce = false;

  @override
  void initState() {
    super.initState();
    // The orange line and a running timer move once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  Future<void> _schedule(Task task, int start) => _guard(
    () => ref
        .read(taskRepositoryProvider)
        .scheduleTask(
          task.id,
          day: widget.day,
          time: timeOf(start.clamp(0, 24 * 60 - _lengthOf(task) - 1)),
        ),
  );

  void _jumpTo(int hour, int firstHour) {
    if (!_scroll.hasClients) return;
    final target = ((hour - firstHour) * _hourHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (Motion.reduced(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: Motion.base, curve: Motion.move);
    }
  }

  /// The task's options, opened where it was clicked (the founder's
  /// "task options").
  Future<void> _options(Task task, Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [_TaskOptions(task: task)],
    );
    if (choice == null || !mounted) return;
    final tasks = ref.read(taskRepositoryProvider);
    switch (choice) {
      case 'done':
        await _guard(
          () => tasks.setDone(task.id, done: task.status != TaskStatus.done),
        );
      case 'focus':
        if (mounted) await startFocus(context, ref, taskId: task.id);
      case 'time':
        final start = minutesOf(task.dueTime ?? '') ?? 9 * 60;
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
        );
        if (picked != null) {
          await _schedule(task, picked.hour * 60 + picked.minute);
        }
      case 'unschedule':
        await _guard(
          () => tasks.scheduleTask(task.id, day: widget.day, time: null),
        );
      case 'open':
        ref.read(currentPageProvider.notifier).open(AppPage.tasks);
      default:
        if (choice.startsWith('length-')) {
          final minutes = int.parse(choice.substring(7));
          await _guard(() => tasks.setTaskDuration(task.id, minutes));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final day = widget.day;
    final times = ref.watch(dayTimesProvider).value;
    final wake = minutesOf(times?.wake ?? '') ?? 7 * 60;
    final bed = minutesOf(times?.bed ?? '') ?? 23 * 60;
    final allTasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final events = ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final logs = ref.watch(habitLogsProvider).value ?? const <HabitLog>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final timer = ref.watch(focusTimerProvider).value;

    final tasks = {
      for (final task in allTasks)
        if (task.dueDate == day && minutesOf(task.dueTime ?? '') != null)
          task.id: task,
    };
    final dayEvents = {
      for (final event in events)
        if (event.day == day) event.id: event,
    };
    final dayHabits = {
      for (final habit in habits)
        if (minutesOf(habit.usualTime ?? '') != null && isPlanned(habit, day))
          'habit-${habit.id}': habit,
    };
    final doneHabits = {
      for (final log in logs)
        if (log.day == day && log.status == HabitMark.done) log.habitId,
    };

    final resize = _resize;
    final blocks = <TimeBlock>[
      ...eventBlocksOn(day, events),
      for (final task in tasks.values)
        TimeBlock(
          task.id,
          minutesOf(task.dueTime!)!,
          math.min(
            resize != null && resize.id == task.id
                ? resize.end
                : minutesOf(task.dueTime!)! + _lengthOf(task),
            24 * 60 - 1,
          ),
        ),
      for (final entry in dayHabits.entries)
        TimeBlock(
          entry.key,
          minutesOf(entry.value.usualTime!)!,
          minutesOf(entry.value.usualTime!)! + _habitMinutes,
        ),
    ];

    // From the waking hour to bedtime, wider when something lies outside.
    var firstHour = wake ~/ 60;
    var lastHour = bed > wake ? (bed / 60).ceil() : 24;
    for (final block in blocks) {
      firstHour = math.min(firstHour, block.start ~/ 60);
      lastHour = math.max(lastHour, (block.end / 60).ceil());
    }
    lastHour = math.min(24, math.max(lastHour, firstHour + 2));
    final hours = lastHour - firstHour;
    final height = hours * _hourHeight;
    final isToday = day == today;
    final nowMinutes = now.hour * 60 + now.minute;

    if (!_scrolledOnce) {
      _scrolledOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final hour = isToday ? math.max(firstHour, now.hour - 1) : firstHour;
        _scroll.jumpTo(
          ((hour - firstHour) * _hourHeight).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      });
    }

    double top(int minutes) => (minutes / 60 - firstHour) * _hourHeight;

    return Column(
      key: const Key('schedule'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.calendar_today_outlined,
          title: 'Schedule',
          trailing: Tag(isToday ? 'Time blocks' : formatLongDay(day)),
        ),
        // Jump to an hour.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var h = firstHour; h < lastHour; h++)
              _HourChip(
                key: Key('schedule-hour-$h'),
                hour: h,
                now: isToday && now.hour == h,
                onTap: () => _jumpTo(h, firstHour),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: math.min(height + 12, _viewport),
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - _gutter;
                  final placed = layoutBlocks(blocks);
                  return DragTarget<Task>(
                    key: const Key('schedule-slot'),
                    onMove: (details) {
                      final box = context.findRenderObject()! as RenderBox;
                      final local = box.globalToLocal(details.offset);
                      setState(() {
                        _hoverLength = _lengthOf(details.data);
                        _hoverStart = _snap(
                          (local.dy / _hourHeight * 60).round() +
                              firstHour * 60,
                        ).clamp(0, 24 * 60 - _hoverLength - 1);
                      });
                    },
                    onLeave: (_) => setState(() => _hoverStart = null),
                    onAcceptWithDetails: (details) {
                      final start = _hoverStart;
                      setState(() => _hoverStart = null);
                      if (start != null) _schedule(details.data, start);
                    },
                    builder: (context, candidates, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var h = 0; h <= hours; h++) ...[
                          Positioned(
                            left: _gutter,
                            right: 0,
                            top: h * _hourHeight,
                            child: Container(height: 1, color: Ember.line),
                          ),
                          if (h < hours)
                            Positioned(
                              left: 0,
                              top: h * _hourHeight - 6,
                              child: Text(
                                formatTime(timeOf((firstHour + h) * 60)),
                                style: Ember.text(
                                  11,
                                  13,
                                  weight: 400,
                                  color: Ember.ink3,
                                ),
                              ),
                            ),
                        ],
                        if (candidates.isNotEmpty && _hoverStart != null)
                          Positioned(
                            key: const Key('schedule-drop-preview'),
                            left: _gutter + 2,
                            right: 2,
                            top: top(_hoverStart!) + 1,
                            height: math.max(
                              24,
                              _hoverLength / 60 * _hourHeight - 2,
                            ),
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                                decoration: BoxDecoration(
                                  color: Ember.ink.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Ember.ink,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  formatTime(timeOf(_hoverStart!)),
                                  style: Ember.text(11, 13, weight: 600),
                                ),
                              ),
                            ),
                          ),
                        for (final item in placed)
                          Positioned(
                            left:
                                _gutter +
                                2 +
                                item.column * (width - 4) / item.columns,
                            width: (width - 4) / item.columns - 2,
                            top: top(item.block.start) + 2,
                            height: math.max(
                              26,
                              (item.block.end - item.block.start) /
                                      60 *
                                      _hourHeight -
                                  4,
                            ),
                            child: switch ((
                              tasks[item.block.id],
                              dayEvents[item.block.id],
                              dayHabits[item.block.id],
                            )) {
                              (final Task task, _, _) => _taskBlock(
                                task,
                                item.block,
                                projects: projects,
                                timer: timer?.taskId == task.id ? timer : null,
                                now: now,
                              ),
                              (_, final CalendarEvent event, _) => _EventBlock(
                                event: event,
                                block: item.block,
                                project: projects
                                    .where((p) => p.id == event.projectId)
                                    .firstOrNull,
                              ),
                              (_, _, final Habit habit) => _HabitBlock(
                                habit: habit,
                                block: item.block,
                                done: doneHabits.contains(habit.id),
                                day: day,
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                        if (isToday &&
                            nowMinutes >= firstHour * 60 &&
                            nowMinutes < lastHour * 60)
                          Positioned(
                            key: const Key('schedule-now'),
                            left: 0,
                            right: 0,
                            top: top(nowMinutes) - 9,
                            child: IgnorePointer(
                              child: Row(
                                children: [
                                  Container(
                                    width: _gutter - 6,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Ember.now,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '${now.hour % 12 == 0 ? 12 : now.hour % 12}:'
                                      '${now.minute.toString().padLeft(2, '0')}',
                                      style: Ember.text(
                                        10.5,
                                        13,
                                        weight: 600,
                                        color: Ember.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 1.5,
                                      color: Ember.now,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Nothing planned yet. Drag a task from the list on the right '
              'onto a time.',
              style: Ember.meta,
            ),
          ),
      ],
    );
  }

  /// A task with a time: drag it to move it, drag its bottom edge to make
  /// it longer, click it for its options.
  Widget _taskBlock(
    Task task,
    TimeBlock block, {
    required List<Project> projects,
    required FocusTimer? timer,
    required DateTime now,
  }) {
    final project = projects.where((p) => p.id == task.projectId).firstOrNull;
    final look = _TaskBlockLook(
      task: task,
      block: block,
      project: project,
      timer: timer,
      now: now,
      onToggle: () => _guard(
        () => ref
            .read(taskRepositoryProvider)
            .setDone(task.id, done: task.status != TaskStatus.done),
      ),
      onPause: () =>
          _guard(() => ref.read(focusRepositoryProvider).togglePause()),
    );
    final start = minutesOf(task.dueTime!)!;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: Draggable<Task>(
              data: task,
              dragAnchorStrategy: childDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: look,
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: look),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: GestureDetector(
                  key: Key('schedule-task-${task.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _options(task, details.globalPosition),
                  child: look,
                ),
              ),
            ),
          ),
          // The bottom edge: drag it for a longer or shorter task.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 7,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                key: Key('schedule-task-bottom-${task.id}'),
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onVerticalDragStart: (_) {
                  _resizeDy = 0;
                  setState(
                    () => _resize = (id: task.id, end: start + _lengthOf(task)),
                  );
                },
                onVerticalDragUpdate: (details) {
                  _resizeDy += details.delta.dy;
                  final delta = (_resizeDy / _hourHeight * 60).round();
                  setState(
                    () => _resize = (
                      id: task.id,
                      end: _snap(start + _lengthOf(task) + delta)
                          .clamp(start + 15, 24 * 60 - 1),
                    ),
                  );
                },
                onVerticalDragEnd: (_) async {
                  final done = _resize;
                  if (done == null) return;
                  final minutes = done.end - start;
                  if (minutes != _lengthOf(task)) {
                    await _guard(
                      () => ref
                          .read(taskRepositoryProvider)
                          .setTaskDuration(task.id, minutes),
                    );
                  }
                  if (mounted) setState(() => _resize = null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    super.key,
    required this.hour,
    required this.now,
    required this.onTap,
  });

  final int hour;
  final bool now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = hour % 12 == 0 ? '12' : '${hour % 12}';
    return Tooltip(
      message: formatTime(timeOf(hour * 60)),
      child: Material(
        color: now ? Ember.ink : Ember.tile,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text(
                label,
                style: Ember.text(
                  12,
                  15,
                  weight: now ? 600 : 500,
                  color: now ? Ember.onInk : Ember.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How a task block looks: a done ring, the title and times, its project
/// and notes; orange with a progress line while its focus timer runs.
class _TaskBlockLook extends StatelessWidget {
  const _TaskBlockLook({
    required this.task,
    required this.block,
    required this.project,
    required this.timer,
    required this.now,
    required this.onToggle,
    required this.onPause,
  });

  final Task task;
  final TimeBlock block;
  final Project? project;
  final FocusTimer? timer;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final running = timer;
    final length = block.end - block.start;
    final tall = length >= 50;
    final swatch = project == null ? null : ProjectColors.of(project!.color);
    final hasNote = (task.notes ?? '').trim().isNotEmpty;
    final title = Row(
      children: [
        TaskRing(
          done: done,
          priority: task.priority,
          size: 16,
          label: '${done ? 'Undo' : 'Complete'} ${task.title}',
          onTap: onToggle,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ember.text(
              13,
              16,
              weight: 600,
              color: done ? Ember.ink3 : Ember.ink,
            ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatTime(timeOf(block.start))} to '
          '${formatTime(timeOf(block.end))}',
          style: Ember.text(11.5, 14, weight: 400, color: Ember.ink2),
        ),
      ],
    );
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: running != null ? Ember.nowTint : Ember.tile,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          top: BorderSide(
            color: running != null ? Ember.now : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (tall && (swatch != null || hasNote)) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (swatch != null)
                        Tag(
                          project!.name,
                          background: swatch.soft,
                          foreground: swatch.text,
                        ),
                      if (hasNote) const Tag('1 note'),
                    ],
                  ),
                ),
              ],
              if (running != null && length >= 75) ...[
                const SizedBox(height: 10),
                _RunningLine(timer: running, now: now, onPause: onPause),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A running focus timer inside its task block: pause, the bar, the time.
class _RunningLine extends StatelessWidget {
  const _RunningLine({
    required this.timer,
    required this.now,
    required this.onPause,
  });

  final FocusTimer timer;
  final DateTime now;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final worked = workedMs(timer, now);
    final target = timer.targetMinutes;
    final share = target == null
        ? (worked % 3600000) / 3600000
        : math.min(1.0, worked / (target * 60000));
    final running = isRunning(timer);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          Material(
            color: Ember.now,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('schedule-pause'),
              customBorder: const CircleBorder(),
              onTap: onPause,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: Ember.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 4,
                color: Ember.now,
                backgroundColor: Ember.nowSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            target == null
                ? formatClock(worked)
                : '${formatClock(worked)} of ${formatClock(target * 60000)}',
            style: Ember.text(11.5, 14, weight: 600, color: Ember.nowInk),
          ),
        ],
      ),
    );
  }
}

/// An event from the Calendar; a click opens the Calendar.
class _EventBlock extends ConsumerWidget {
  const _EventBlock({
    required this.event,
    required this.block,
    required this.project,
  });

  final CalendarEvent event;
  final TimeBlock block;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swatch = project == null ? null : ProjectColors.of(project!.color);
    final background = swatch?.soft ?? Ember.blueBg;
    final foreground = swatch?.text ?? Ember.blueInk;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('schedule-event-${event.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            ref.read(currentPageProvider.notifier).open(AppPage.calendar),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 10, 4),
          child: ClipRect(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.text(13, 16, weight: 600, color: foreground),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatTime(timeOf(block.start))} to '
                  '${formatTime(timeOf(block.end))}',
                  style: Ember.text(11.5, 14, weight: 400, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A habit at its usual time; the ring marks it done for the day.
class _HabitBlock extends ConsumerWidget {
  const _HabitBlock({
    required this.habit,
    required this.block,
    required this.done,
    required this.day,
  });

  final Habit habit;
  final TimeBlock block;
  final bool done;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> toggle() async {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;
      try {
        await ref
            .read(habitRepositoryProvider)
            .setMark(
              userId: userId,
              habitId: habit.id,
              day: day,
              status: done ? null : HabitMark.done,
            );
      } catch (error) {
        if (context.mounted) showMessage(context, 'Could not save. ($error)');
      }
    }

    return Container(
      key: Key('schedule-habit-${habit.id}'),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRect(
        child: Row(
          children: [
            TaskRing(
              done: done,
              priority: 'none',
              size: 16,
              label: '${done ? 'Undo' : 'Mark done'} ${habit.name}',
              onTap: toggle,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ember.text(
                  13,
                  16,
                  weight: 600,
                  color: done ? Ember.ink3 : Ember.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTime(timeOf(block.start)),
              style: Ember.text(11.5, 14, weight: 400, color: Ember.ink2),
            ),
            const Spacer(),
            Tag('Habit', background: Ember.goodBg, foreground: Ember.goodInk),
          ],
        ),
      ),
    );
  }
}

/// The options of a scheduled task, in one small card that opens where
/// the task was clicked.
class _TaskOptions extends PopupMenuEntry<String> {
  const _TaskOptions({required this.task});

  final Task task;

  @override
  double get height => 260;

  @override
  bool represents(String? value) => false;

  @override
  State<_TaskOptions> createState() => _TaskOptionsState();
}

class _TaskOptionsState extends State<_TaskOptions> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final done = task.status == TaskStatus.done;
    final length = _lengthOf(task);
    void pick(String value) => Navigator.pop(context, value);

    Widget action(String value, IconData icon, String label) => InkWell(
      key: Key('task-option-$value'),
      onTap: () => pick(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Ember.ink2),
            const SizedBox(width: 10),
            Text(label, style: Ember.text(13, 16, weight: 400)),
          ],
        ),
      ),
    );

    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ember.h3,
            ),
          ),
          action(
            'done',
            done ? Icons.undo : Icons.check_circle_outline,
            done ? 'Mark as not done' : 'Mark as done',
          ),
          action('focus', Icons.timer_outlined, 'Start focus'),
          action('time', Icons.schedule, 'Change the time…'),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Text('Length', style: Ember.caption),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final minutes in const [15, 30, 45, 60, 90, 120, 180])
                  InkWell(
                    key: Key('task-option-length-$minutes'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => pick('length-$minutes'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: minutes == length ? Ember.ink : Ember.tile,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _hours(minutes),
                        style: Ember.text(
                          11.5,
                          14,
                          color: minutes == length ? Ember.onInk : Ember.ink2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Ember.line),
          action('unschedule', Icons.event_busy_outlined, 'Remove the time'),
          action('open', Icons.open_in_new, 'Open in Tasks'),
        ],
      ),
    );
  }
}
