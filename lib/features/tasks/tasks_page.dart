import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show addTaskRequestProvider;
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/sleep.dart' show formatTime, timeOf;
import '../../domain/task_view.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import '../focus/focus_page.dart' show startFocus;
import 'completion_chart.dart';

enum _TasksView { list, month }

const _priorityLabels = <(String, String)>[
  (TaskPriority.none, 'None'),
  (TaskPriority.medium, 'Medium'),
  (TaskPriority.high, 'High'),
];

/// The Tasks page (design: `docs/design/source/Tasks.dc.html`, "Tasks ·
/// list + detail"): a box to add a task, the tasks as soft tiles grouped
/// by date, and on the right the details of the selected task.
///
/// The filters, grouping and sorting sit behind the "Filters" button, and
/// the completion chart in the "Completed" section at the bottom (the
/// founder's choice A, 2026-11-13).
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _newTask = TextEditingController();
  final _newTaskFocus = FocusNode();
  var _range = ChartRange.twoWeeks;
  var _view = _TasksView.list;
  var _grouping = TaskGrouping.dueDate;
  var _sorting = TaskSorting.dueDate;
  var _status = StatusFilter.open;
  String? _projectId;
  String? _goalId;
  String? _priority;
  String? _selectedId;
  var _showFilters = false;
  var _showDoneToday = false;
  var _showCompleted = false;

  /// The month the month view shows. Null means the current month.
  DateTime? _month;

  @override
  void dispose() {
    _newTask.dispose();
    _newTaskFocus.dispose();
    super.dispose();
  }

  /// Adds a task. It takes over the project and priority filters, so
  /// the new task is visible in the list the user is looking at.
  Future<void> _add() async {
    final userId = ref.read(userIdProvider);
    final title = _newTask.text.trim();
    if (userId == null || title.isEmpty) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .addTask(
            userId: userId,
            title: title,
            projectId: _projectId,
            priority: _priority ?? TaskPriority.none,
          );
      _newTask.clear();
    } catch (error) {
      // The typed title stays in the box, so nothing is lost.
      if (mounted) showMessage(context, 'Could not add the task. ($error)');
    }
  }

  Future<void> _toggle(Task task) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .setDone(task.id, done: task.status != TaskStatus.done);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  void _resetFilters() => setState(() {
    _grouping = TaskGrouping.dueDate;
    _sorting = TaskSorting.dueDate;
    _status = StatusFilter.open;
    _projectId = null;
    _goalId = null;
    _priority = null;
  });

  @override
  Widget build(BuildContext context) {
    // "New" in the title bar: put the cursor in the add box.
    if (ref.watch(addTaskRequestProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _newTaskFocus.requestFocus();
        ref.read(addTaskRequestProvider.notifier).handled();
      });
    }
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);
    final byTask = secondsByTask(sessions);

    // A filter may point at a project or goal that was deleted meanwhile.
    final projectId = projects.any((p) => p.id == _projectId)
        ? _projectId
        : null;
    final goalId = goals.any((g) => g.id == _goalId) ? _goalId : null;

    final shown = sortTasks(
      filterTasks(
        tasks,
        TaskFilter(
          status: _status,
          projectId: projectId,
          goalId: goalId,
          priority: _priority,
        ),
        projects: projects,
      ),
      _sorting,
    );
    final open = tasks.where((task) => task.status != TaskStatus.done).length;
    final overdue = countOverdue(tasks, today: today);
    final onTime = onTimeThisMonth(tasks, today: today);
    final doneToday = doneOn(tasks, today: today);
    final selected = tasks.where((task) => task.id == _selectedId).firstOrNull;
    final points = completionSeries(tasks, _range, today: today);
    final summary = chartSummary(_range, points);
    final month = _month ?? DateTime(now.year, now.month);
    final filtered =
        _grouping != TaskGrouping.dueDate ||
        _sorting != TaskSorting.dueDate ||
        _status != StatusFilter.open ||
        projectId != null ||
        goalId != null ||
        _priority != null;
    Project? projectOf(Task task) =>
        projects.where((p) => p.id == task.projectId).firstOrNull;
    void select(Task task) => setState(() {
      _selectedId = task.id == _selectedId ? null : task.id;
    });
    TaskRow row(Task task) => TaskRow(
      key: ValueKey('row-${task.id}'),
      task: task,
      project: projectOf(task),
      today: today,
      focusSeconds: byTask[task.id] ?? 0,
      selected: task.id == _selectedId,
      onTap: () => select(task),
      onToggle: () => _toggle(task),
    );

    return PageLayout(
      railWidth: 400,
      main: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: [
            PageHeader(
              title: 'Tasks',
              subtitle: [
                '$open open',
                if (overdue > 0) '$overdue overdue',
                if (onTime != null) '$onTime% done on time this month',
              ].join(' · '),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Segments<_TasksView>(
                    keyPrefix: 'view',
                    value: _view,
                    options: const [
                      (_TasksView.list, 'List', Icons.view_list_outlined),
                      (
                        _TasksView.month,
                        'Calendar',
                        Icons.calendar_month_outlined,
                      ),
                    ],
                    onChanged: (view) => setState(() => _view = view),
                  ),
                  const SizedBox(width: 8),
                  SoftButton(
                    key: const Key('task-filters'),
                    icon: Icons.filter_list,
                    label: filtered ? 'Filters on' : 'Filters',
                    active: _showFilters,
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('task-new-button'),
                    onPressed: _newTaskFocus.requestFocus,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New task'),
                  ),
                ],
              ),
            ),
          ],
        ),
        // The filters fold out under the header.
        if (_showFilters)
          Appear(
            child: Tile(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_view == _TasksView.list) ...[
                    _Pick<TaskGrouping>(
                      key: const Key('group'),
                      prefix: 'Group',
                      value: _grouping,
                      options: [
                        for (final grouping in TaskGrouping.values)
                          (grouping, grouping.label),
                      ],
                      onChanged: (value) => setState(() => _grouping = value),
                    ),
                    _Pick<TaskSorting>(
                      key: const Key('sort'),
                      prefix: 'Sort',
                      value: _sorting,
                      options: [
                        for (final sorting in TaskSorting.values)
                          (sorting, sorting.label),
                      ],
                      onChanged: (value) => setState(() => _sorting = value),
                    ),
                  ],
                  _Pick<StatusFilter>(
                    key: const Key('filter-status'),
                    value: _status,
                    options: [
                      for (final status in StatusFilter.values)
                        (status, status.label),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  _Pick<String?>(
                    key: const Key('filter-project'),
                    value: projectId,
                    options: [
                      (null, 'All projects'),
                      for (final project in projects)
                        (project.id, project.name),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  ),
                  _Pick<String?>(
                    key: const Key('filter-goal'),
                    value: goalId,
                    options: [
                      (null, 'All goals'),
                      for (final goal in goals) (goal.id, goal.title),
                    ],
                    onChanged: (value) => setState(() => _goalId = value),
                  ),
                  _Pick<String?>(
                    key: const Key('filter-priority'),
                    value: _priority,
                    options: const [
                      (null, 'Any priority'),
                      (TaskPriority.high, 'High'),
                      (TaskPriority.medium, 'Medium'),
                      (TaskPriority.none, 'No priority'),
                    ],
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                  if (filtered)
                    TextButton(
                      key: const Key('filter-reset'),
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ),
          ),
        _AddBox(controller: _newTask, focusNode: _newTaskFocus, onAdd: _add),
        if (_view == _TasksView.month)
          _MonthView(
            month: month,
            today: today,
            tasks: shown,
            projectOf: projectOf,
            selectedId: _selectedId,
            onSelect: select,
            onMonth: (value) => setState(() => _month = value),
          )
        else if (shown.isEmpty)
          EmptyHint(
            title: tasks.isEmpty
                ? 'No tasks yet'
                : _status == StatusFilter.open && open == 0
                ? 'No open tasks'
                : 'No tasks match',
            text: tasks.isEmpty
                ? 'Add your first one in the box above.'
                : _status == StatusFilter.open && open == 0
                ? 'Everything is done. Add one in the box above.'
                : 'Change the filters to see more.',
          )
        else
          for (final group in groupTasks(
            shown,
            _grouping,
            today: today,
            projects: projects,
            goals: goals,
          ))
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (group.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          group.label,
                          style: Ember.caption.copyWith(
                            color: group.label == 'Overdue'
                                ? Ember.nowInk
                                : Ember.ink3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${group.tasks.length}',
                          key: Key('group-${group.label}'),
                          style: Ember.caption,
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < group.tasks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  row(group.tasks[i]),
                ],
              ],
            ),
        if (_view == _TasksView.list &&
            _status == StatusFilter.open &&
            doneToday.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftButton(
                key: const Key('done-today'),
                icon: _showDoneToday ? Icons.expand_less : Icons.expand_more,
                label: 'Done today · ${doneToday.length}',
                onPressed: () =>
                    setState(() => _showDoneToday = !_showDoneToday),
              ),
              if (_showDoneToday)
                for (final task in doneToday) ...[
                  const SizedBox(height: 6),
                  SizedBox(width: double.infinity, child: row(task)),
                ],
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SoftButton(
                key: const Key('show-chart'),
                icon: _showCompleted ? Icons.expand_less : Icons.show_chart,
                label: 'Completed',
                onPressed: () =>
                    setState(() => _showCompleted = !_showCompleted),
              ),
            ),
            if (_showCompleted) ...[
              const SizedBox(height: 10),
              Tile(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tasks completed', style: Ember.h3),
                              const SizedBox(height: 3),
                              Text(
                                summary,
                                key: const Key('chart-summary'),
                                style: Ember.meta,
                              ),
                            ],
                          ),
                        ),
                        _Segments<ChartRange>(
                          keyPrefix: 'chart',
                          value: _range,
                          options: [
                            for (final range in ChartRange.values)
                              (range, range.label, null),
                          ],
                          onChanged: (range) => setState(() => _range = range),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CompletionChart(points: points, summary: summary),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
      rail: [
        if (selected == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text('Pick a task', style: Ember.h3),
                const SizedBox(height: 6),
                Text(
                  'Its details show here.',
                  style: Ember.meta,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          TaskForm(
            key: ValueKey(selected.id),
            task: selected,
            projects: projects,
            goals: goals,
            today: today,
            onClose: () => setState(() => _selectedId = null),
          ),
      ],
    );
  }
}

/// The box to add a task (the design's `.input` with a plus and "Enter").
class _AddBox extends StatelessWidget {
  const _AddBox({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.add, size: 16, color: Ember.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('task-new'),
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onAdd(),
              style: Ember.text(13, 16, weight: 400, color: Ember.ink),
              decoration: const InputDecoration(
                hintText: 'Add a task',
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          InkWell(
            key: const Key('task-add'),
            borderRadius: BorderRadius.circular(6),
            onTap: onAdd,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Kbd('Enter'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of buttons where one is chosen, such as "List | Month".
class _Segments<T extends Enum> extends StatelessWidget {
  const _Segments({
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String keyPrefix;
  final T value;
  final List<(T, String, IconData?)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Ember.neutral,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (option, label, icon) in options)
            Semantics(
              button: true,
              selected: option == value,
              child: Material(
                color: option == value ? Ember.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('$keyPrefix-${option.name}'),
                  onTap: () => onChanged(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 14,
                            color: option == value ? Ember.ink : Ember.ink2,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: Ember.text(
                            12,
                            15,
                            color: option == value ? Ember.ink : Ember.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small drop-down list in the style of the page.
class _Pick<T> extends StatelessWidget {
  const _Pick({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.prefix,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Shown before the chosen value, for example "Group".
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final style = Ember.text(12, 15, color: Ember.ink);
    return Container(
      height: 34,
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          dropdownColor: Ember.white,
          style: style,
          icon: const Icon(Icons.expand_more, size: 16, color: Ember.ink2),
          selectedItemBuilder: (context) => [
            for (final (_, label) in options)
              // The width limit keeps a long project name inside the box.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    prefix == null ? label : '$prefix: $label',
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
          ],
          items: [
            for (final (option, label) in options)
              DropdownMenuItem<T>(
                value: option,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (chosen) => onChanged(chosen as T),
        ),
      ),
    );
  }
}

/// The label next to a task title that shows its priority.
class PriorityTag extends StatelessWidget {
  const PriorityTag(this.priority, {super.key});

  final String priority;

  @override
  Widget build(BuildContext context) {
    return priority == TaskPriority.high
        ? const Tag('High', background: Ember.nowTint, foreground: Ember.nowInk)
        : const Tag(
            'Medium',
            background: Color(0xFFFBF0D5),
            foreground: Ember.amberInk,
          );
  }
}

/// One task on one line: complete button, title, priority, due date and,
/// on the right, the project in its colour. With [showNote], the first
/// line of the task's notes sits under the title.

/// One task as a soft tile (the design's list row): the complete ring, the
/// title, and under it when it is due (orange when overdue), the project
/// tag and the first line of the notes. Focus time sits on the right.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.project,
    required this.today,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    this.focusSeconds = 0,
    this.showNote = true,
  });

  final Task task;

  /// Null hides the project tag (for example on the project's own page).
  final Project? project;
  final String today;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final int focusSeconds;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final due = task.dueDate;
    final late = !done && due != null && due.compareTo(today) < 0;
    final note = showNote ? firstLine(task.notes) : null;
    final project = this.project;
    return Tile(
      key: Key('task-${task.id}'),
      selected: selected,
      color: selected ? Ember.white : Ember.tile,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(9, 7, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskRing(
            done: done,
            priority: task.priority,
            label: '${done ? 'Undo' : 'Complete'} ${task.title}',
            onTap: onToggle,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.soft,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: done
                        ? Ember.item.copyWith(
                            color: Ember.ink3,
                            decoration: TextDecoration.lineThrough,
                          )
                        : Ember.item.copyWith(color: Ember.ink),
                    child: Text(task.title),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        due == null
                            ? 'No date'
                            : formatRelativeDay(due, today: today),
                        key: Key('task-when-${task.id}'),
                        style: Ember.meta.copyWith(
                          color: late ? Ember.nowInk : Ember.ink2,
                        ),
                      ),
                      if (task.priority != TaskPriority.none)
                        PriorityTag(task.priority),
                      if (project != null)
                        Tag(
                          project.name,
                          background: ProjectColors.of(project.color).soft,
                          foreground: ProjectColors.of(project.color).text,
                        ),
                      if (note != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            '· $note',
                            key: Key('task-note-${task.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ember.meta,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (focusSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 10),
              child: Text(
                formatWorked(focusSeconds),
                style: Ember.meta.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The details of one task (the design's right panel): change it in place,
/// focus on it, write notes, reschedule or delete it. Project, due date and
/// priority save as soon as they change; the title and the notes save when
/// the cursor leaves them or with their Save button.
class TaskForm extends ConsumerStatefulWidget {
  const TaskForm({
    super.key,
    required this.task,
    required this.projects,
    required this.goals,
    required this.today,
    required this.onClose,
  });

  final Task task;
  final List<Project> projects;
  final List<Goal> goals;
  final String today;
  final VoidCallback onClose;

  @override
  ConsumerState<TaskForm> createState() => TaskFormState();
}

class TaskFormState extends ConsumerState<TaskForm> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes ?? '');
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveTitle();
    });
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _saveNotes();
    });
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  /// Saves the task with the given changes; everything else stays.
  Future<void> _update({
    String? title,
    String? Function()? projectId,
    String? Function()? dueDate,
    String? priority,
    String? notes,
    String done = 'Saved.',
    bool quiet = true,
  }) async {
    final task = widget.task;
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateTask(
            task.id,
            title: title ?? task.title,
            projectId: projectId == null ? task.projectId : projectId(),
            dueDate: dueDate == null ? task.dueDate : dueDate(),
            priority: priority ?? task.priority,
            notes: notes,
          );
      if (!quiet && mounted) showMessage(context, done);
    } catch (error) {
      // The typed text stays in the boxes, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _saveTitle() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    if (_error != null) setState(() => _error = null);
    if (title == widget.task.title) return;
    await _update(title: title);
  }

  Future<void> _saveNotes() async {
    if (_notes.text.trim() == (widget.task.notes ?? '')) return;
    await _update(notes: _notes.text, quiet: false, done: 'Notes saved.');
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(widget.task.dueDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      helpText: 'Due date',
    );
    if (picked != null && mounted) {
      await _update(dueDate: () => dayKey(picked));
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete ${widget.task.title}?',
      message: 'The task is removed from all your devices.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(taskRepositoryProvider).deleteTask(widget.task.id);
      widget.onClose();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final done = task.status == TaskStatus.done;
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final sessions =
        (ref.watch(focusSessionsProvider).value ?? const <FocusSession>[])
            .where((session) => session.taskId == task.id)
            .toList();
    final totalSeconds = sessions.fold<int>(
      0,
      (sum, session) => sum + session.focusSeconds,
    );
    final projectIds = {for (final project in widget.projects) project.id};
    // A task serves its project; the project serves the goal.
    final project = widget.projects
        .where((p) => p.id == task.projectId)
        .firstOrNull;
    final goal = widget.goals
        .where((goal) => goal.id == project?.goalId)
        .firstOrNull;
    final area = areas.where((a) => a.id == goal?.lifeAreaId).firstOrNull;
    final due = task.dueDate;
    final late = !done && due != null && due.compareTo(widget.today) < 0;
    final created = dayKeyOfStoredTime(task.createdAt);
    final finished = dayKeyOfStoredTime(task.completedAt);
    final notesChanged = _notes.text.trim() != (task.notes ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${project?.name ?? 'No project'}  /  Task',
                overflow: TextOverflow.ellipsis,
                style: Ember.caption.copyWith(color: Ember.ink2),
              ),
            ),
            IconButton(
              key: const Key('task-close'),
              tooltip: 'Close',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              color: Ember.ink2,
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskRing(
              done: done,
              priority: task.priority,
              size: 22,
              label: '${done ? 'Undo' : 'Complete'} ${task.title}',
              onTap: () => ref
                  .read(taskRepositoryProvider)
                  .setDone(task.id, done: !done),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('task-title'),
                    controller: _title,
                    focusNode: _titleFocus,
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveTitle(),
                    style: Ember.text(
                      22,
                      28,
                      weight: 700,
                      color: Ember.ink,
                      letterSpacing: -0.015,
                    ),
                    decoration: InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.only(top: 3),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    done
                        ? 'Done${finished == null ? '' : ' · ${formatRelativeDay(finished, today: widget.today)}'}'
                        : 'Open${created == null ? '' : ' · added ${formatShortDay(created, today: widget.today)}'}',
                    style: Ember.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FocusBox(task: task, totalSeconds: totalSeconds),
        const SizedBox(height: 20),
        _Field(
          label: 'Project',
          child: _Pick<String?>(
            key: const Key('task-project'),
            value: projectIds.contains(task.projectId) ? task.projectId : null,
            options: [
              (null, 'No project'),
              for (final project in widget.projects) (project.id, project.name),
            ],
            onChanged: (value) => _update(projectId: () => value),
          ),
        ),
        _Field(
          label: 'Goal',
          child: goal == null
              ? Text('Set by the project', style: Ember.meta)
              : Align(
                  alignment: Alignment.centerLeft,
                  child: NameChip(
                    key: const Key('task-served-goal'),
                    label: goal.title,
                    swatch: GoalColors.of(goal.color),
                    icon: ItemIcons.of(
                      goal.icon,
                      orElse: ItemIcons.goalFallback,
                    ),
                  ),
                ),
        ),
        _Field(
          label: 'Life area',
          child: area == null
              ? Text('—', style: Ember.meta)
              : Row(
                  children: [
                    AreaMark(color: area.color, icon: area.icon, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        area.name,
                        overflow: TextOverflow.ellipsis,
                        style: Ember.item.copyWith(color: Ember.ink),
                      ),
                    ),
                  ],
                ),
        ),
        _Field(
          label: 'Due',
          child: Row(
            children: [
              Flexible(
                child: InkWell(
                  key: const Key('task-date'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      due == null
                          ? 'Pick a date'
                          : formatRelativeDay(due, today: widget.today),
                      style: Ember.item.copyWith(
                        color: late
                            ? Ember.nowInk
                            : due == null
                            ? Ember.ink2
                            : Ember.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (due != widget.today)
                SoftButton(
                  key: const Key('task-date-today'),
                  label: 'Today',
                  onPressed: () => _update(dueDate: () => widget.today),
                ),
              if (due != null)
                IconButton(
                  key: const Key('task-date-clear'),
                  tooltip: 'Remove the date',
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  color: Ember.ink2,
                  onPressed: () => _update(dueDate: () => null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        _Field(
          label: 'Priority',
          child: Wrap(
            spacing: 6,
            children: [
              for (final (value, label) in _priorityLabels)
                _PriorityChoice(
                  key: Key('priority-$value'),
                  priority: value,
                  label: label,
                  chosen: task.priority == value,
                  onTap: () => _update(priority: value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text('Time', style: Ember.h3)),
            Text(
              totalSeconds == 0
                  ? 'No focus time yet'
                  : '${formatWorked(totalSeconds)} focused',
              key: const Key('task-focus-time'),
              style: Ember.meta,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Focus sessions', style: Ember.h3),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Text('None yet. Start one above.', style: Ember.meta)
        else
          for (final session in sessions.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_sessionWhen(session), style: Ember.meta),
                  ),
                  Text(formatWorked(session.focusSeconds), style: Ember.meta),
                ],
              ),
            ),
        const SizedBox(height: 18),
        Text('Notes', style: Ember.h3),
        const SizedBox(height: 8),
        TextField(
          key: const Key('task-notes'),
          controller: _notes,
          focusNode: _notesFocus,
          minLines: 4,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Anything to remember about this task',
          ),
        ),
        if (notesChanged) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('task-save'),
              onPressed: () {
                _notesFocus.unfocus();
                _saveNotes();
              },
              child: const Text('Save notes'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SoftButton(
              key: const Key('task-reschedule'),
              icon: Icons.calendar_today_outlined,
              label: 'Reschedule',
              onPressed: _pickDate,
            ),
            SoftButton(
              key: const Key('task-postpone'),
              label: 'Postpone to tomorrow',
              onPressed: () => _update(
                dueDate: () => addDays(widget.today, 1),
                quiet: false,
                done: 'Moved to tomorrow.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('task-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete task'),
          ),
        ),
      ],
    );
  }

  String _sessionWhen(FocusSession session) {
    final start = parseStoredTime(session.startedAt);
    if (start == null) return '';
    final day = formatRelativeDay(dayKey(start), today: widget.today);
    return '$day · ${formatTime(timeOf(start.hour * 60 + start.minute))}';
  }
}

/// One line of the details list: a grey label and its value.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: Ember.meta)),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }
}

/// A priority button with the ring colour it gives the task.
class _PriorityChoice extends StatelessWidget {
  const _PriorityChoice({
    super.key,
    required this.priority,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String priority;
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = switch (priority) {
      TaskPriority.high => Ember.now,
      TaskPriority.medium => Ember.amber,
      _ => Ember.ring,
    };
    return Semantics(
      button: true,
      selected: chosen,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.soft,
        decoration: BoxDecoration(
          color: chosen ? Ember.ink : Ember.tile,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(7),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ring, width: 1.6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Ember.text(
                      12,
                      15,
                      color: chosen ? Ember.white : Ember.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Focus on this task from its details (the design's orange "Focus running"
/// tile). While its timer runs the clock moves and it can be paused or
/// stopped here; otherwise it starts a session.
class _FocusBox extends ConsumerStatefulWidget {
  const _FocusBox({required this.task, required this.totalSeconds});

  final Task task;
  final int totalSeconds;

  @override
  ConsumerState<_FocusBox> createState() => _FocusBoxState();
}

class _FocusBoxState extends ConsumerState<_FocusBox> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Ticks once a second only while this task's timer runs.
  void _ticking(bool on) {
    if (on && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  Future<void> _stop() async {
    try {
      final saved = await ref.read(focusRepositoryProvider).stop();
      if (!mounted) return;
      showMessage(
        context,
        saved == null
            ? 'Under a minute, so it was not saved as a session.'
            : 'Saved ${formatWorked(saved)} of focus.',
      );
    } catch (error) {
      if (mounted) showMessage(context, 'Could not stop. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(focusTimerProvider).value;
    final mine = timer != null && timer.taskId == widget.task.id;
    final running = mine && isRunning(timer);
    _ticking(running);
    final worked = mine ? workedMs(timer, ref.watch(clockProvider)()) : 0;
    final total = widget.totalSeconds + worked ~/ 1000;

    if (mine) {
      return AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.soft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Ember.nowTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _RoundButton(
              key: const Key('task-focus-pause'),
              icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Ember.now,
              label: running ? 'Pause focus' : 'Resume focus',
              onTap: () => ref.read(focusRepositoryProvider).togglePause(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    running ? 'Focus running' : 'Focus paused',
                    style: Ember.item.copyWith(color: Ember.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatClock(worked)} now · ${formatWorked(total)} total',
                    style: Ember.meta.copyWith(
                      color: Ember.nowInk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            SoftButton(
              key: const Key('task-focus-stop'),
              label: 'Stop and save',
              background: Ember.white,
              onPressed: _stop,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _RoundButton(
            key: const Key('task-start-focus'),
            icon: Icons.play_arrow_rounded,
            color: Ember.ink,
            label: 'Start focus',
            onTap: widget.task.status == TaskStatus.done
                ? null
                : () => startFocus(context, ref, taskId: widget.task.id),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Focus', style: Ember.item.copyWith(color: Ember.ink)),
                const SizedBox(height: 3),
                Text(
                  total == 0
                      ? 'Start a session on this task'
                      : '${formatWorked(total)} so far',
                  style: Ember.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        child: Material(
          color: onTap == null ? Ember.ring : color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(icon, size: 16, color: Ember.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first line of [text] that is not empty, or null when there is none.
String? firstLine(String? text) {
  if (text == null) return null;
  for (final line in text.split('\n')) {
    if (line.trim().isNotEmpty) return line.trim();
  }
  return null;
}

/// A calendar of one month. Each day shows the tasks due on it.
class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.today,
    required this.tasks,
    required this.projectOf,
    required this.selectedId,
    required this.onSelect,
    required this.onMonth,
  });

  /// The first day of the month shown.
  final DateTime month;
  final String today;
  final List<Task> tasks;
  final Project? Function(Task) projectOf;
  final String? selectedId;
  final ValueChanged<Task> onSelect;
  final ValueChanged<DateTime?> onMonth;

  static const _shownPerDay = 3;

  @override
  Widget build(BuildContext context) {
    final cells = monthCells(month.year, month.month);
    final byDay = <String, List<Task>>{};
    var withoutDate = 0;
    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) {
        withoutDate++;
      } else {
        byDay.putIfAbsent(due, () => []).add(task);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${monthNames[month.month - 1]} ${month.year}',
              key: const Key('month-title'),
              style: Ember.h2,
            ),
            const Spacer(),
            IconButton(
              key: const Key('month-prev'),
              tooltip: 'Previous month',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(
              key: const Key('month-today'),
              onPressed: () => onMonth(null),
              child: const Text('This month'),
            ),
            IconButton(
              key: const Key('month-next'),
              tooltip: 'Next month',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final name in weekdayShort)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 4),
                  child: Text(name, style: Ember.caption),
                ),
              ),
          ],
        ),
        for (var week = 0; week < cells.length; week += 7)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in cells.sublist(week, week + 7))
                  Expanded(child: _dayCell(day, byDay[day] ?? const [])),
              ],
            ),
          ),
        if (withoutDate > 0) ...[
          const SizedBox(height: 10),
          Text(
            '${countOf(withoutDate, 'task')} without a due date: see the '
            'list view.',
            style: Ember.meta,
          ),
        ],
      ],
    );
  }

  Widget _dayCell(String? day, List<Task> dayTasks) {
    final isToday = day != null && day == today;
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: day == null ? Colors.transparent : Ember.tile,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: Ember.now, width: 1.5) : null,
      ),
      child: day == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 3),
                  child: Text(
                    '${parseDayKey(day)!.day}',
                    style: Ember.text(
                      11,
                      13,
                      weight: isToday ? 700 : 500,
                      color: isToday ? Ember.nowInk : Ember.ink2,
                    ),
                  ),
                ),
                for (final task in dayTasks.take(_shownPerDay))
                  _monthTask(task),
                if (dayTasks.length > _shownPerDay)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, top: 1),
                    child: Text(
                      '+${dayTasks.length - _shownPerDay} more',
                      style: Ember.caption,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _monthTask(Task task) {
    final project = projectOf(task);
    final swatch = project == null ? null : ProjectColors.of(project.color);
    final done = task.status == TaskStatus.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: swatch?.soft ?? Ember.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: task.id == selectedId
              ? const BorderSide(color: Ember.ink, width: 1.2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('month-task-${task.id}'),
          onTap: () => onSelect(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(
                11,
                13,
                color: done ? Ember.ink3 : swatch?.text ?? Ember.ink,
              ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
      ),
    );
  }
}

/// The details of one task, to change or delete it.
