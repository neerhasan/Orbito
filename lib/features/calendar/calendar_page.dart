import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart'
    show AppPage, currentPageProvider, openProjectRequestProvider;
import '../../data/local/app_database.dart';
import '../../domain/calendar.dart';
import '../../domain/dates.dart';
import '../../domain/sleep.dart' show formatTime, minutesOf, timeOf;
import '../../ui/ember.dart';
import '../../ui/widgets.dart';
import '../tasks/tasks_page.dart' show Segments;

/// The colours of an event block (the design's "ev" tag).
Color get _eventSoft => Ember.blueBg;
Color get _eventInk => Ember.blueInk;

/// How tall one hour is on the time grid.
const _hourHeight = 48.0;

/// The width of the hour labels on the left of the time grid.
const _gutter = 56.0;

/// How long a task with a time takes when it has no length of its own.
const _taskMinutes = 30;

/// How long [task] takes on the grid.
int _lengthOfTask(Task task) =>
    math.max(15, task.durationMinutes ?? _taskMinutes);

/// The last minute of a day (23:59): an event cannot end later.
const _lastMinute = 23 * 60 + 59;

/// Dragged times snap to a quarter of an hour.
int _snap(int minutes) => (minutes / 15).round() * 15;

/// What is being dragged on the calendar.
sealed class _Drag {
  const _Drag();
}

class _EventDrag extends _Drag {
  const _EventDrag(this.event);
  final CalendarEvent event;
}

class _TaskDrag extends _Drag {
  const _TaskDrag(this.task);
  final Task task;
}

/// What the time grid can ask the page to do.
class _GridActions {
  const _GridActions({
    required this.onSlot,
    required this.onEvent,
    required this.onTask,
    required this.onProject,
    required this.onMoveEvent,
    required this.onResizeEvent,
    required this.onScheduleTask,
    required this.onResizeTask,
  });

  final void Function(String day, int minutes) onSlot;
  final ValueChanged<CalendarEvent> onEvent;
  final VoidCallback onTask;
  final ValueChanged<String> onProject;
  final Future<void> Function(CalendarEvent event, String day, int start)
  onMoveEvent;
  final Future<void> Function(CalendarEvent event, int start, int end)
  onResizeEvent;
  final Future<void> Function(Task task, String day, int? minutes)
  onScheduleTask;
  final Future<void> Function(Task task, int start, int end) onResizeTask;
}

/// The Calendar page (design: `Calendar.dc.html`): a month view and a time
/// grid of 7, 4, 3 or 2 days. It shows the user's events, the tasks due
/// each day, project deadlines and past focus sessions. On the right: the
/// picked day, and the form for a new event or the event that is open.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  var _view = CalendarView.week;

  /// The day the view is built around. Null means today.
  String? _anchor;

  /// The day picked for a new event (and shown on the right).
  String? _day;

  /// The start and end a new event gets, as `HH:MM`.
  String? _start;
  String? _end;

  /// The event open on the right.
  String? _eventId;

  /// Bumps so the new-event form takes fresh values.
  var _serial = 0;

  /// The month the small calendar on the left shows; null follows the view.
  String? _miniMonth;

  /// True while the event panel is open on the right (as in Notion
  /// Calendar, it opens only for a new or a picked event).
  var _formOpen = false;

  /// Starts a new event on [day], from [minutes] for an hour.
  void _newAt(String day, {int? minutes}) {
    setState(() {
      _day = day;
      _eventId = null;
      _formOpen = true;
      if (minutes != null) {
        final from = math.min(minutes, 23 * 60);
        _start = timeOf(from);
        _end = timeOf(math.min(from + 60, 23 * 60 + 59));
      } else {
        _start = null;
        _end = null;
      }
      _serial++;
    });
  }

  void _openEvent(CalendarEvent event) => setState(() {
    _eventId = event.id == _eventId ? null : event.id;
    _formOpen = _eventId != null;
    _day = event.day;
    _serial++;
  });

  void _report(Object error) {
    if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
  }

  /// An event was dragged to [day], starting at [start]; it keeps its length.
  Future<void> _moveEvent(CalendarEvent event, String day, int start) async {
    final length = math.max(
      15,
      (minutesOf(event.endTime) ?? 0) - (minutesOf(event.startTime) ?? 0),
    );
    final from = start.clamp(0, _lastMinute - length);
    try {
      await ref
          .read(eventRepositoryProvider)
          .updateEvent(
            event.id,
            title: event.title,
            day: day,
            startTime: timeOf(from),
            endTime: timeOf(from + length),
            projectId: event.projectId,
            note: event.note,
          );
      if (!mounted) return;
      setState(() {
        if (_eventId == event.id) _day = day;
        _serial++;
      });
    } catch (error) {
      _report(error);
    }
  }

  /// An event's top or bottom edge was dragged.
  Future<void> _resizeEvent(CalendarEvent event, int start, int end) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .updateEvent(
            event.id,
            title: event.title,
            day: event.day,
            startTime: timeOf(start),
            endTime: timeOf(end),
            projectId: event.projectId,
            note: event.note,
          );
      if (mounted) setState(() => _serial++);
    } catch (error) {
      _report(error);
    }
  }

  /// A task was dragged onto the grid ([minutes] is its new time) or onto
  /// the All day row ([minutes] is null: no set time).
  Future<void> _scheduleTask(Task task, String day, int? minutes) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .scheduleTask(
            task.id,
            day: day,
            time: minutes == null
                ? null
                : timeOf(minutes.clamp(0, _lastMinute - _lengthOfTask(task))),
          );
    } catch (error) {
      _report(error);
    }
  }

  /// A task block's top or bottom edge was dragged: a new start, a new
  /// length, or both.
  Future<void> _resizeTask(Task task, int start, int end) async {
    final repository = ref.read(taskRepositoryProvider);
    try {
      await repository.scheduleTask(
        task.id,
        day: task.dueDate!,
        time: timeOf(start),
      );
      await repository.setTaskDuration(task.id, end - start);
    } catch (error) {
      _report(error);
    }
  }

  /// A task dropped back on the task list: no date, no time.
  Future<void> _unscheduleTask(Task task) async {
    try {
      await ref.read(taskRepositoryProvider).unscheduleTask(task.id);
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _completeTask(Task task) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .setDone(task.id, done: task.status != TaskStatus.done);
    } catch (error) {
      _report(error);
    }
  }

  void _openTask() =>
      ref.read(currentPageProvider.notifier).open(AppPage.tasks);

  void _openProject(String id) {
    ref.read(openProjectRequestProvider.notifier).ask(id);
    ref.read(currentPageProvider.notifier).open(AppPage.projects);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final anchor = _anchor ?? today;
    final events = ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final heading = calendarTitle(_view, anchor);
    final days = shownDays(_view, anchor);
    final pickedDay = _day ?? today;
    final open = events.where((e) => e.id == _eventId).firstOrNull;

    final items = _DayItems(
      tasks: tasks,
      projects: projects,
      events: events,
      sessions: sessions,
    );

    final page = PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PageHeader(
                key: const Key('calendar-title'),
                title: heading.title,
                subtitle: heading.subtitle.isEmpty ? null : heading.subtitle,
              ),
            ),
            FilledButton.icon(
              key: const Key('calendar-new-event'),
              onPressed: () => _newAt(pickedDay, minutes: _nextHour(now)),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Event'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Segments<CalendarView>(
              keyPrefix: 'calendar-view',
              value: _view,
              options: [
                for (final view in CalendarView.values)
                  (view, view.label, null),
              ],
              onChanged: (view) => setState(() => _view = view),
            ),
            SoftButton(
              key: const Key('calendar-today'),
              label: 'Today',
              onPressed: () => setState(() {
                _anchor = null;
                _day = today;
              }),
            ),
            IconButton(
              key: const Key('calendar-prev'),
              tooltip: 'Back',
              iconSize: 18,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _anchor = stepAnchor(_view, anchor, -1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('calendar-next'),
              tooltip: 'Forward',
              iconSize: 18,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _anchor = stepAnchor(_view, anchor, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_view == CalendarView.month)
          _MonthGrid(
            days: days,
            month: parseDayKey(anchor)!.month,
            today: today,
            picked: pickedDay,
            items: items,
            onPick: (day) => _newAt(day),
          )
        else
          _TimeGrid(
            days: days,
            today: today,
            now: now,
            items: items,
            selectedEventId: _eventId,
            actions: _GridActions(
              onSlot: (day, minutes) => _newAt(day, minutes: minutes),
              onEvent: _openEvent,
              onTask: _openTask,
              onProject: _openProject,
              onMoveEvent: _moveEvent,
              onResizeEvent: _resizeEvent,
              onScheduleTask: _scheduleTask,
              onResizeTask: _resizeTask,
            ),
          ),
      ],
      rail: !_formOpen
          ? null
          : [
              _EventForm(
                key: ValueKey('form-${open?.id ?? 'new'}-$_serial'),
                event: open,
                day: pickedDay,
                start: _start,
                end: _end,
                projects: projects,
                defaultStart: _nextHour(now),
                onSaved: (id) => setState(() {
                  _eventId = id;
                  _serial++;
                }),
                onClosed: () => setState(() {
                  _eventId = null;
                  _start = null;
                  _end = null;
                  _formOpen = false;
                  _serial++;
                }),
              ),
            ],
    );

    // As in Notion Calendar: on the left a small month and every open task,
    // ready to be dragged onto a day or a time.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 264,
          child: _CalendarSide(
            month: _miniMonth ?? anchor,
            today: today,
            picked: pickedDay,
            tasks: tasks,
            projects: projects,
            onMonth: (month) => setState(() => _miniMonth = month),
            onPickDay: (day) => setState(() {
              _anchor = day;
              _day = day;
            }),
            onDropTask: _unscheduleTask,
            onCompleteTask: _completeTask,
            onOpenTask: _openTask,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: page),
      ],
    );
  }
}

/// The next full hour after [now], in minutes after midnight (at most 23:00).
int _nextHour(DateTime now) => math.min((now.hour + 1) * 60, 23 * 60);

/// Everything the calendar shows, by day.
class _DayItems {
  _DayItems({
    required this.tasks,
    required this.projects,
    required this.events,
    required this.sessions,
  });

  final List<Task> tasks;
  final List<Project> projects;
  final List<CalendarEvent> events;
  final List<FocusSession> sessions;

  List<CalendarEvent> eventsOn(String day) =>
      events.where((e) => e.day == day).toList();

  /// Open tasks first, then the completed ones.
  List<Task> tasksOn(String day) => [
    ...tasks.where((t) => t.dueDate == day && t.status != TaskStatus.done),
    ...tasks.where((t) => t.dueDate == day && t.status == TaskStatus.done),
  ];

  /// Tasks of [day] without a set time: they sit in the All day row.
  List<Task> untimedTasksOn(String day) => [
    for (final task in tasksOn(day))
      if (task.dueTime == null || minutesOf(task.dueTime!) == null) task,
  ];

  /// Tasks of [day] with a time, as blocks on the grid.
  List<TimeBlock> taskBlocksOn(String day) => [
    for (final task in tasksOn(day))
      if (task.dueTime != null)
        if (minutesOf(task.dueTime!) case final int start)
          TimeBlock(
            task.id,
            start,
            math.min(_lastMinute, start + _lengthOfTask(task)),
          ),
  ];

  List<Project> deadlinesOn(String day) =>
      projects.where((p) => p.deadline == day).toList();

  Project? projectOf(String? id) =>
      projects.where((p) => p.id == id).firstOrNull;

  Task? taskOf(String? id) => tasks.where((t) => t.id == id).firstOrNull;

  FocusSession? sessionOf(String id) =>
      sessions.where((s) => s.id == id).firstOrNull;

  /// The colours of an event: its project's, or the calendar blue.
  (Color, Color) coloursOf(CalendarEvent event) {
    final project = projectOf(event.projectId);
    if (project == null) return (_eventSoft, _eventInk);
    final swatch = ProjectColors.of(project.color);
    return (swatch.soft, swatch.text);
  }
}

// ------------------------------------------------------------ month view

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.month,
    required this.today,
    required this.picked,
    required this.items,
    required this.onPick,
  });

  final List<String> days;
  final int month;
  final String today;
  final String picked;
  final _DayItems items;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('calendar-month'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final name in const [
              'Sun',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(name, style: Ember.caption),
                ),
              ),
          ],
        ),
        for (var week = 0; week < days.length ~/ 7; week++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in days.sublist(week * 7, week * 7 + 7))
                Expanded(child: _monthCell(day)),
            ],
          ),
      ],
    );
  }

  Widget _monthCell(String day) {
    final date = parseDayKey(day)!;
    final inMonth = date.month == month;
    final isToday = day == today;
    final lines = <(String, Color, Color)>[
      for (final event in items.eventsOn(day))
        (
          '${formatTime(event.startTime)} ${event.title}',
          items.coloursOf(event).$1,
          items.coloursOf(event).$2,
        ),
      for (final project in items.deadlinesOn(day))
        (
          'Due: ${project.name}',
          ProjectColors.of(project.color).soft,
          ProjectColors.of(project.color).text,
        ),
      for (final task in items.tasksOn(day))
        (
          task.title,
          Colors.transparent,
          task.status == TaskStatus.done ? Ember.ink3 : Ember.ink,
        ),
    ];
    return InkWell(
      key: Key('calendar-day-$day'),
      onTap: () => onPick(day),
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Ember.line),
            left: BorderSide(
              color: day == picked ? Ember.ink : Colors.transparent,
              width: day == picked ? 2 : 0,
            ),
          ),
          color: day == picked ? Ember.tile : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? Ember.now : null,
              ),
              child: Text(
                '${date.day}',
                style: Ember.text(
                  12,
                  15,
                  weight: isToday ? 600 : 500,
                  color: isToday
                      ? Ember.white
                      : inMonth
                      ? Ember.ink
                      : Ember.ink3,
                ),
              ),
            ),
            const SizedBox(height: 3),
            for (final (label, background, foreground) in lines.take(3))
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.text(10.5, 13, color: foreground),
                ),
              ),
            if (lines.length > 3)
              Text('+${lines.length - 3} more', style: Ember.meta),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- time grid

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.days,
    required this.today,
    required this.now,
    required this.items,
    required this.selectedEventId,
    required this.actions,
  });

  final List<String> days;
  final String today;
  final DateTime now;
  final _DayItems items;
  final String? selectedEventId;
  final _GridActions actions;

  @override
  Widget build(BuildContext context) {
    // The grid starts at 7 AM, or earlier when something starts earlier.
    var firstHour = 7;
    for (final day in days) {
      for (final block in [
        ...eventBlocksOn(day, items.events),
        ...focusBlocksOn(day, items.sessions),
        ...items.taskBlocksOn(day),
      ]) {
        firstHour = math.min(firstHour, block.start ~/ 60);
      }
    }
    final hours = 24 - firstHour;

    return Column(
      key: const Key('calendar-grid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day names and numbers.
        Row(
          children: [
            const SizedBox(width: _gutter),
            for (final day in days)
              Expanded(
                child: _DayHead(day: day, today: today),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Tasks without a time and project deadlines. A task dragged here
        // loses its time.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _gutter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('All day', style: Ember.caption),
              ),
            ),
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _AllDay(day: day, items: items, actions: actions),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: hours * _hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _gutter,
                child: Stack(
                  children: [
                    for (var h = 1; h < hours; h++)
                      Positioned(
                        top: h * _hourHeight - 7,
                        right: 8,
                        child: Text(
                          formatTime(timeOf((firstHour + h) * 60)),
                          style: Ember.text(10.5, 13, color: Ember.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              for (final day in days)
                Expanded(
                  child: _DayColumn(
                    key: ValueKey('column-$day'),
                    day: day,
                    today: today,
                    now: now,
                    firstHour: firstHour,
                    items: items,
                    selectedEventId: selectedEventId,
                    actions: actions,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayHead extends StatelessWidget {
  const _DayHead({required this.day, required this.today});

  final String day;
  final String today;

  @override
  Widget build(BuildContext context) {
    final date = parseDayKey(day)!;
    final isToday = day == today;
    return Column(
      children: [
        Text(weekdayShort[date.weekday - 1], style: Ember.caption),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? Ember.now : null,
          ),
          child: Text(
            '${date.day}',
            style: Ember.text(
              14,
              17,
              weight: isToday ? 600 : 500,
              color: isToday ? Ember.white : Ember.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllDay extends StatelessWidget {
  const _AllDay({
    required this.day,
    required this.items,
    required this.actions,
  });

  final String day;
  final _DayItems items;
  final _GridActions actions;

  @override
  Widget build(BuildContext context) {
    final deadlines = items.deadlinesOn(day);
    final tasks = items.untimedTasksOn(day);
    final chips = <Widget>[
      for (final project in deadlines)
        _Chip(
          key: Key('calendar-deadline-${project.id}'),
          label: 'Due: ${project.name}',
          background: ProjectColors.of(project.color).soft,
          foreground: ProjectColors.of(project.color).text,
          onTap: () => actions.onProject(project.id),
        ),
      for (final task in tasks)
        Draggable<_Drag>(
          data: _TaskDrag(task),
          dragAnchorStrategy: childDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 150, child: _taskChip(task, onTap: () {})),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _taskChip(task, onTap: () {}),
          ),
          child: _taskChip(
            task,
            key: Key('calendar-task-${task.id}'),
            onTap: actions.onTask,
          ),
        ),
    ];
    return DragTarget<_Drag>(
      key: Key('calendar-allday-$day'),
      onWillAcceptWithDetails: (details) => details.data is _TaskDrag,
      onAcceptWithDetails: (details) {
        if (details.data case _TaskDrag(:final task)) {
          actions.onScheduleTask(task, day, null);
        }
      },
      builder: (context, candidates, _) => Container(
        constraints: const BoxConstraints(minHeight: 24),
        decoration: BoxDecoration(
          color: candidates.isEmpty ? null : Ember.tile,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...chips.take(3),
            if (chips.length > 3)
              Text('+${chips.length - 3} more', style: Ember.meta),
          ],
        ),
      ),
    );
  }

  Widget _taskChip(Task task, {Key? key, required VoidCallback onTap}) => _Chip(
    key: key,
    label: task.title,
    background: Ember.surface,
    foreground: task.status == TaskStatus.done ? Ember.ink3 : Ember.ink,
    border: true,
    done: task.status == TaskStatus.done,
    onTap: onTap,
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border = false,
    this.done = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool border;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: border
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Ember.ring),
                  )
                : null,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(
                11,
                13,
                color: foreground,
              ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day on the time grid: hour lines, a tint for today with the orange
/// line at the time now, events, tasks with a time and focus sessions.
///
/// - A click on an empty place starts a new event there.
/// - Events and tasks can be dragged to another time or day; a dashed box
///   shows where they will land.
/// - The top and bottom edges of an event change its start and end.
class _DayColumn extends StatefulWidget {
  const _DayColumn({
    super.key,
    required this.day,
    required this.today,
    required this.now,
    required this.firstHour,
    required this.items,
    required this.selectedEventId,
    required this.actions,
  });

  final String day;
  final String today;
  final DateTime now;
  final int firstHour;
  final _DayItems items;
  final String? selectedEventId;
  final _GridActions actions;

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  /// An event whose edge is being dragged, with its new start and end.
  ({String id, int start, int end})? _resize;
  double _resizeDy = 0;

  /// Where a dragged item would land, and how long it is.
  int? _hoverStart;
  var _hoverLength = 60;

  double _top(int minutes) => (minutes / 60 - widget.firstHour) * _hourHeight;

  /// The minutes after midnight at [global], a point on the screen.
  int _minutesAt(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    return (local.dy / _hourHeight * 60).round() + widget.firstHour * 60;
  }

  int _lengthOf(_Drag drag) => switch (drag) {
    _EventDrag(:final event) => math.max(
      15,
      (minutesOf(event.endTime) ?? 0) - (minutesOf(event.startTime) ?? 0),
    ),
    _TaskDrag(:final task) => _lengthOfTask(task),
  };

  int _landing(_Drag drag, Offset global) {
    final length = _lengthOf(drag);
    return _snap(_minutesAt(global)).clamp(0, _lastMinute - length);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final items = widget.items;
    final isToday = day == widget.today;
    final events = {for (final e in items.eventsOn(day)) e.id: e};
    final tasks = {for (final t in items.tasksOn(day)) t.id: t};
    final resize = _resize;
    final placed = layoutBlocks([
      for (final block in eventBlocksOn(day, items.events))
        if (resize != null && resize.id == block.id)
          TimeBlock(block.id, resize.start, resize.end)
        else
          block,
      ...focusBlocksOn(day, items.sessions),
      for (final block in items.taskBlocksOn(day))
        if (resize != null && resize.id == block.id)
          TimeBlock(block.id, resize.start, resize.end)
        else
          block,
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return DragTarget<_Drag>(
          onMove: (details) => setState(() {
            _hoverStart = _landing(details.data, details.offset);
            _hoverLength = _lengthOf(details.data);
          }),
          onLeave: (_) => setState(() => _hoverStart = null),
          onAcceptWithDetails: (details) {
            final start = _landing(details.data, details.offset);
            setState(() => _hoverStart = null);
            switch (details.data) {
              case _EventDrag(:final event):
                widget.actions.onMoveEvent(event, day, start);
              case _TaskDrag(:final task):
                widget.actions.onScheduleTask(task, day, start);
            }
          },
          builder: (context, _, _) => GestureDetector(
            key: Key('calendar-slot-$day'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final minutes =
                  ((details.localPosition.dy / _hourHeight + widget.firstHour) *
                          60)
                      .floor();
              // Round down to the half hour.
              widget.actions.onSlot(day, (minutes ~/ 30) * 30);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isToday ? Ember.todayTint : null,
                      border: Border(left: BorderSide(color: Ember.line)),
                    ),
                    child: CustomPaint(painter: _HourLines()),
                  ),
                ),
                for (final item in placed)
                  Positioned(
                    top: _top(item.block.start) + 1,
                    height: _height(item.block),
                    left: 2 + item.column * (width - 4) / item.columns,
                    width: (width - 4) / item.columns - 2,
                    child: switch ((
                      events[item.block.id],
                      tasks[item.block.id],
                    )) {
                      (final CalendarEvent event, _) => _draggable(
                        _EventDrag(event),
                        Size(
                          (width - 4) / item.columns - 2,
                          _height(item.block),
                        ),
                        _eventBlock(event, item.block, handles: true),
                        _eventBlock(event, item.block, handles: false),
                      ),
                      (_, final Task task) => _draggable(
                        _TaskDrag(task),
                        Size(
                          (width - 4) / item.columns - 2,
                          _height(item.block),
                        ),
                        _taskBlock(task, item.block, handles: true),
                        _taskBlock(task, item.block, handles: false),
                      ),
                      _ => _focusBlock(item.block),
                    },
                  ),
                if (_hoverStart case final int start)
                  Positioned(
                    top: _top(start) + 1,
                    height: math.max(22, _hoverLength / 60 * _hourHeight - 3),
                    left: 2,
                    right: 2,
                    child: IgnorePointer(
                      child: Container(
                        key: const Key('calendar-drop-preview'),
                        padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
                        decoration: BoxDecoration(
                          color: Ember.ink.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Ember.ink, width: 1.5),
                        ),
                        child: Text(
                          formatTime(timeOf(start)),
                          style: Ember.text(11, 13, weight: 600),
                        ),
                      ),
                    ),
                  ),
                if (isToday)
                  Positioned(
                    top: _top(widget.now.hour * 60 + widget.now.minute),
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Ember.now,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1.5, color: Ember.now),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _height(TimeBlock block) =>
      math.max(22, (block.end - block.start) / 60 * _hourHeight - 3);

  /// A block that can be picked up and dropped on another time or day.
  Widget _draggable(_Drag data, Size size, Widget child, Widget look) {
    return Draggable<_Drag>(
      data: data,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox.fromSize(size: size, child: look),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: look),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }

  Widget _eventBlock(
    CalendarEvent event,
    TimeBlock block, {
    required bool handles,
  }) {
    final (background, foreground) = widget.items.coloursOf(event);
    final selected = event.id == widget.selectedEventId;
    final content = Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
      decoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Ember.ink, width: 2),
            )
          : null,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(11.5, 14, weight: 600, color: foreground),
            ),
            Text(
              '${formatTime(timeOf(block.start))} to '
              '${formatTime(timeOf(block.end))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(10.5, 13, color: foreground),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: !handles
          ? content
          : Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    key: Key('event-${event.id}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => widget.actions.onEvent(event),
                    child: content,
                  ),
                ),
                _eventEdge(event, top: true),
                _eventEdge(event, top: false),
              ],
            ),
    );
  }

  Widget _eventEdge(CalendarEvent event, {required bool top}) {
    final start = minutesOf(event.startTime) ?? 0;
    return _edge(
      id: event.id,
      keyName: 'event',
      start: start,
      end: minutesOf(event.endTime) ?? start + 60,
      top: top,
      onDone: (from, to) => widget.actions.onResizeEvent(event, from, to),
    );
  }

  /// The top or bottom edge of an event or a task: drag it to change the
  /// start or the end, in quarter hours.
  Widget _edge({
    required String id,
    required String keyName,
    required int start,
    required int end,
    required bool top,
    required Future<void> Function(int start, int end) onDone,
  }) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: 7,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          key: Key('$keyName-${top ? 'top' : 'bottom'}-$id'),
          behavior: HitTestBehavior.opaque,
          // Count from where the edge was pressed, so no movement is lost.
          dragStartBehavior: DragStartBehavior.down,
          onVerticalDragStart: (_) {
            _resizeDy = 0;
            setState(() => _resize = (id: id, start: start, end: end));
          },
          onVerticalDragUpdate: (details) {
            _resizeDy += details.delta.dy;
            final delta = (_resizeDy / _hourHeight * 60).round();
            setState(() {
              _resize = top
                  ? (
                      id: id,
                      start: _snap(start + delta).clamp(0, end - 15),
                      end: end,
                    )
                  : (
                      id: id,
                      start: start,
                      end: _snap(end + delta).clamp(start + 15, _lastMinute),
                    );
            });
          },
          onVerticalDragEnd: (_) async {
            final done = _resize;
            if (done == null) return;
            if (done.start != start || done.end != end) {
              await onDone(done.start, done.end);
            }
            if (mounted) setState(() => _resize = null);
          },
        ),
      ),
    );
  }

  /// A task with a time: white (a raised surface), its title and from-to
  /// times. Its top and bottom edges change the start and the length.
  Widget _taskBlock(Task task, TimeBlock block, {required bool handles}) {
    final done = task.status == TaskStatus.done;
    final short = block.end - block.start < 45;
    final title = Text(
      task.title,
      maxLines: block.end - block.start < 75 ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: Ember.text(
        11,
        13,
        weight: 600,
        color: done ? Ember.ink3 : Ember.ink,
      ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
    );
    final times = Text(
      '${formatTime(timeOf(block.start))} to ${formatTime(timeOf(block.end))}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Ember.text(10.5, 13, color: Ember.ink2),
    );
    final content = Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Ember.ring),
      ),
      child: ClipRect(
        child: short
            ? Row(
                children: [
                  Flexible(child: title),
                  const SizedBox(width: 6),
                  Flexible(child: times),
                ],
              )
            // Cut, not overflowing, when the block is short.
            : SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, times],
                ),
              ),
      ),
    );
    final start = minutesOf(task.dueTime!) ?? block.start;
    final end = start + _lengthOfTask(task);
    Widget edge({required bool top}) => _edge(
      id: task.id,
      keyName: 'task',
      start: start,
      end: math.min(end, _lastMinute),
      top: top,
      onDone: (from, to) => widget.actions.onResizeTask(task, from, to),
    );
    return Material(
      color: Ember.surface,
      borderRadius: BorderRadius.circular(6),
      child: !handles
          ? content
          : Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    key: Key('calendar-timed-task-${task.id}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: widget.actions.onTask,
                    child: content,
                  ),
                ),
                edge(top: true),
                edge(top: false),
              ],
            ),
    );
  }

  Widget _focusBlock(TimeBlock block) {
    final session = widget.items.sessionOf(block.id);
    final task = widget.items.taskOf(session?.taskId);
    return IgnorePointer(
      child: Container(
        key: Key('focus-block-${block.id}'),
        padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
        decoration: BoxDecoration(
          color: Ember.neutral,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: Ember.ink, width: 3)),
        ),
        child: ClipRect(
          child: Text(
            task == null ? 'Focus' : 'Focus · ${task.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Ember.text(11, 13, weight: 600, color: Ember.ink),
          ),
        ),
      ),
    );
  }
}

class _HourLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Ember.line
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += _hourHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HourLines old) => false;
}

// ------------------------------------------------------------ right panel

/// The left side, as in Notion Calendar: a small month to jump to a day,
/// and every open task, grouped by when it is due. A task is dragged from
/// here onto a time (it gets a date and a time) or onto the All day row
/// (a date only); dropped back here, it loses both.
class _CalendarSide extends StatelessWidget {
  const _CalendarSide({
    required this.month,
    required this.today,
    required this.picked,
    required this.tasks,
    required this.projects,
    required this.onMonth,
    required this.onPickDay,
    required this.onDropTask,
    required this.onCompleteTask,
    required this.onOpenTask,
  });

  /// A day in the month the small calendar shows.
  final String month;
  final String today;
  final String picked;
  final List<Task> tasks;
  final List<Project> projects;
  final ValueChanged<String> onMonth;
  final ValueChanged<String> onPickDay;
  final ValueChanged<Task> onDropTask;
  final ValueChanged<Task> onCompleteTask;
  final VoidCallback onOpenTask;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => task.status != TaskStatus.done).toList()
      ..sort((a, b) {
        final byDay = (a.dueDate ?? '').compareTo(b.dueDate ?? '');
        if (byDay != 0) return byDay;
        return (a.dueTime ?? '99').compareTo(b.dueTime ?? '99');
      });
    final groups = <(String, String, List<Task>)>[
      (
        'none',
        'No date',
        [
          for (final t in open)
            if (t.dueDate == null) t,
        ],
      ),
      (
        'overdue',
        'Overdue',
        [
          for (final t in open)
            if (t.dueDate != null && t.dueDate!.compareTo(today) < 0) t,
        ],
      ),
      (
        'today',
        'Today',
        [
          for (final t in open)
            if (t.dueDate == today) t,
        ],
      ),
      (
        'later',
        'Later',
        [
          for (final t in open)
            if (t.dueDate != null && t.dueDate!.compareTo(today) > 0) t,
        ],
      ),
    ];
    final projectsById = {for (final p in projects) p.id: p};

    return Container(
      decoration: BoxDecoration(
        color: Ember.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: _MiniMonth(
              month: month,
              today: today,
              picked: picked,
              onMonth: onMonth,
              onPickDay: onPickDay,
            ),
          ),
          Divider(height: 1, color: Ember.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text('Tasks', style: Ember.h3)),
                Text('${open.length}', style: Ember.meta),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Drag a task onto a time or a day.',
              style: Ember.caption,
            ),
          ),
          Expanded(
            child: DragTarget<_Drag>(
              key: const Key('calendar-task-list'),
              onWillAcceptWithDetails: (details) =>
                  details.data is _TaskDrag &&
                  (details.data as _TaskDrag).task.dueDate != null,
              onAcceptWithDetails: (details) {
                if (details.data case _TaskDrag(:final task)) {
                  onDropTask(task);
                }
              },
              builder: (context, candidates, _) => Container(
                color: candidates.isEmpty ? null : Ember.tile,
                child: open.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No open tasks. Add one on the Tasks page.',
                          style: Ember.meta,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        children: [
                          for (final (key, label, list) in groups)
                            if (list.isNotEmpty) ...[
                              Padding(
                                key: Key('calendar-group-$key'),
                                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                child: Text(
                                  '$label · ${list.length}',
                                  style: Ember.caption.copyWith(
                                    color: key == 'overdue'
                                        ? Ember.nowInk
                                        : Ember.ink3,
                                  ),
                                ),
                              ),
                              for (final task in list)
                                _SideTask(
                                  task: task,
                                  today: today,
                                  project: projectsById[task.projectId],
                                  onComplete: () => onCompleteTask(task),
                                  onOpen: onOpenTask,
                                ),
                            ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One task in the left list: a done ring, its title, when it is due and
/// its project. Drag it onto the calendar.
class _SideTask extends StatelessWidget {
  const _SideTask({
    required this.task,
    required this.today,
    required this.project,
    required this.onComplete,
    required this.onOpen,
  });

  final Task task;
  final String today;
  final Project? project;
  final VoidCallback onComplete;
  final VoidCallback onOpen;

  String get _when {
    final timed = task.dueTime != null && minutesOf(task.dueTime!) != null;
    final parts = <String>[
      if (task.dueDate != null) formatRelativeDay(task.dueDate!, today: today),
      if (timed) formatTime(task.dueTime!),
      if (timed) _length(_lengthOfTask(task)),
    ];
    return parts.join(' · ');
  }

  static String _length(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  Widget _row({required bool interactive}) {
    final swatch = project == null ? null : ProjectColors.of(project!.color);
    final when = _when;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 8, 4),
      decoration: BoxDecoration(
        color: interactive ? null : Ember.surface,
        borderRadius: BorderRadius.circular(8),
        border: interactive ? null : Border.all(color: Ember.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (interactive)
            TaskRing(
              done: false,
              priority: task.priority,
              label: 'Complete ${task.title}',
              size: 16,
              onTap: onComplete,
            )
          else
            const SizedBox(width: 8),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.text(12.5, 16, color: Ember.ink),
                  ),
                  if (when.isNotEmpty || swatch != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (swatch != null) ...[
                          ColorDot(swatch.dot, size: 6),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            when.isEmpty ? project!.name : when,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ember.text(
                              11,
                              13,
                              weight: 400,
                              color:
                                  task.dueDate != null &&
                                      task.dueDate!.compareTo(today) < 0
                                  ? Ember.nowInk
                                  : Ember.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<_Drag>(
      data: _TaskDrag(task),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: _row(interactive: false)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _row(interactive: true)),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: InkWell(
          key: Key('calendar-list-task-${task.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onOpen,
          child: _row(interactive: true),
        ),
      ),
    );
  }
}

/// The small month on the left: arrows to change the month, today in
/// orange, the picked day ringed. A click jumps the calendar to that day.
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.today,
    required this.picked,
    required this.onMonth,
    required this.onPickDay,
  });

  final String month;
  final String today;
  final String picked;
  final ValueChanged<String> onMonth;
  final ValueChanged<String> onPickDay;

  @override
  Widget build(BuildContext context) {
    final date = parseDayKey(month)!;
    final days = shownDays(CalendarView.month, month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${monthNames[date.month - 1]} ${date.year}',
                key: const Key('mini-title'),
                style: Ember.h3,
              ),
            ),
            IconButton(
              key: const Key('mini-prev'),
              tooltip: 'Earlier month',
              iconSize: 16,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  onMonth(stepAnchor(CalendarView.month, month, -1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('mini-next'),
              tooltip: 'Later month',
              iconSize: 16,
              color: Ember.ink2,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  onMonth(stepAnchor(CalendarView.month, month, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final letter in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(child: Text(letter, style: Ember.caption)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (var week = 0; week < days.length ~/ 7; week++)
          Row(
            children: [
              for (final day in days.sublist(week * 7, week * 7 + 7))
                Expanded(child: _cell(day, date.month)),
            ],
          ),
      ],
    );
  }

  Widget _cell(String day, int month) {
    final number = parseDayKey(day)!;
    final isToday = day == today;
    final isPicked = day == picked;
    return InkWell(
      key: Key('mini-day-$day'),
      customBorder: const CircleBorder(),
      onTap: () => onPickDay(day),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? Ember.now : null,
            border: isPicked && !isToday
                ? Border.all(color: Ember.ink, width: 1.5)
                : null,
          ),
          child: Text(
            '${number.day}',
            style: Ember.text(
              11.5,
              14,
              weight: isToday ? 600 : 500,
              color: isToday
                  ? Ember.white
                  : number.month == month
                  ? Ember.ink
                  : Ember.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

/// The form on the right: a new event, or the open one.
class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({
    super.key,
    required this.event,
    required this.day,
    required this.start,
    required this.end,
    required this.projects,
    required this.defaultStart,
    required this.onSaved,
    required this.onClosed,
  });

  /// The event being changed, or null for a new one.
  final CalendarEvent? event;

  /// The day, start and end a new event starts with.
  final String day;
  final String? start;
  final String? end;
  final List<Project> projects;

  /// Minutes after midnight, used when no start was picked.
  final int defaultStart;
  final ValueChanged<String> onSaved;
  final VoidCallback onClosed;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _note = TextEditingController(text: widget.event?.note ?? '');
  late String _day = widget.event?.day ?? widget.day;
  late String _start =
      widget.event?.startTime ?? widget.start ?? timeOf(widget.defaultStart);
  late String _end =
      widget.event?.endTime ??
      widget.end ??
      timeOf(math.min(widget.defaultStart + 60, 23 * 60 + 59));
  late String? _projectId = widget.event?.projectId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(_day) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      helpText: 'Day',
    );
    if (picked != null && mounted) setState(() => _day = dayKey(picked));
  }

  Future<void> _pickTime({required bool start}) async {
    final current = minutesOf(start ? _start : _end) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Starts' : 'Ends',
    );
    if (picked == null || !mounted) return;
    final value = timeOf(picked.hour * 60 + picked.minute);
    setState(() {
      if (start) {
        // Keep the length of the event when the start moves.
        final length = (minutesOf(_end) ?? 0) - (minutesOf(_start) ?? 0);
        _start = value;
        final from = minutesOf(value)!;
        _end = timeOf(math.min(from + math.max(length, 30), 23 * 60 + 59));
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the event a name.');
      return;
    }
    if ((minutesOf(_end) ?? 0) <= (minutesOf(_start) ?? 0)) {
      setState(() => _error = 'The end must be after the start.');
      return;
    }
    final repository = ref.read(eventRepositoryProvider);
    try {
      final event = widget.event;
      if (event == null) {
        final id = await repository.addEvent(
          userId: userId,
          title: _title.text,
          day: _day,
          startTime: _start,
          endTime: _end,
          projectId: _projectId,
          note: _note.text,
        );
        if (mounted) widget.onSaved(id);
      } else {
        await repository.updateEvent(
          event.id,
          title: _title.text,
          day: _day,
          startTime: _start,
          endTime: _end,
          projectId: _projectId,
          note: _note.text,
        );
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } catch (error) {
      // What was typed stays in the boxes, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final event = widget.event!;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete ${event.title}?',
      message: 'The event is removed from your calendar.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(eventRepositoryProvider).deleteEvent(event.id);
      widget.onClosed();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  Widget _pickBox(Key key, String label, VoidCallback onTap) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Ember.tile,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: Ember.item.copyWith(color: Ember.ink)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    final ids = {for (final project in widget.projects) project.id};
    return Column(
      key: const Key('event-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                editing ? 'Edit event' : 'New event',
                style: Ember.h2,
              ),
            ),
            IconButton(
              key: const Key('event-close'),
              tooltip: 'Close',
              iconSize: 16,
              color: Ember.ink2,
              onPressed: widget.onClosed,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Name'),
        TextField(
          key: const Key('event-title'),
          controller: _title,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            hintText: 'For example: Client call',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Day'),
        _pickBox(const Key('event-day'), formatLongDay(_day), _pickDay),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Starts'),
                  _pickBox(
                    const Key('event-start'),
                    formatTime(_start),
                    () => _pickTime(start: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Ends'),
                  _pickBox(
                    const Key('event-end'),
                    formatTime(_end),
                    () => _pickTime(start: false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Project (optional)'),
        DropdownButtonFormField<String?>(
          key: const Key('event-project'),
          initialValue: ids.contains(_projectId) ? _projectId : null,
          isExpanded: true,
          style: Ember.text(13, 16, weight: 400, color: Ember.ink),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final project in widget.projects)
              DropdownMenuItem(
                value: project.id,
                child: Text(project.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _projectId = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Note'),
        TextField(
          key: const Key('event-note'),
          controller: _note,
          minLines: 2,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(hintText: 'Optional'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('event-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add event'),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('event-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete event'),
          ),
        ],
      ],
    );
  }
}
