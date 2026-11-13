import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/task_view.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import 'completion_chart.dart';

enum _TasksView { list, month }

const _priorityLabels = <(String, String)>[
  (TaskPriority.none, 'None'),
  (TaskPriority.medium, 'Medium'),
  (TaskPriority.high, 'High'),
];

/// The Tasks page: the completion chart, a box to add a task, the list or
/// month view with grouping, sorting and filters, and on the right the
/// details of the selected task.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _newTask = TextEditingController();
  var _range = ChartRange.twoWeeks;
  var _view = _TasksView.list;
  var _grouping = TaskGrouping.dueDate;
  var _sorting = TaskSorting.dueDate;
  var _status = StatusFilter.open;
  String? _projectId;
  String? _goalId;
  String? _priority;
  String? _selectedId;

  /// The month the month view shows. Null means the current month.
  DateTime? _month;

  @override
  void dispose() {
    _newTask.dispose();
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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final now = ref.watch(clockProvider)();
    final today = dayKey(now);

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
    final selected = tasks.where((task) => task.id == _selectedId).firstOrNull;
    final points = completionSeries(tasks, _range, today: today);
    final summary = chartSummary(_range, points);
    final month = _month ?? DateTime(now.year, now.month);
    Project? projectOf(Task task) =>
        projects.where((p) => p.id == task.projectId).firstOrNull;
    void select(Task task) => setState(() {
      _selectedId = task.id == _selectedId ? null : task.id;
    });

    return PageLayout(
      main: [
        PageHeader(title: 'Tasks', subtitle: '$open open'),
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
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('task-new'),
                controller: _newTask,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(hintText: 'Add a task'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('task-add'),
              onPressed: _add,
              child: const Text('Add'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Segments<_TasksView>(
              keyPrefix: 'view',
              value: _view,
              options: const [
                (_TasksView.list, 'List', Icons.view_list_outlined),
                (_TasksView.month, 'Month', Icons.calendar_month_outlined),
              ],
              onChanged: (view) => setState(() => _view = view),
            ),
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
                for (final project in projects) (project.id, project.name),
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
          ],
        ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in groupTasks(
                shown,
                _grouping,
                today: today,
                projects: projects,
                goals: goals,
              )) ...[
                if (group.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                    child: Text(
                      '${group.label} · ${group.tasks.length}',
                      style: Ember.text(
                        12,
                        15,
                        weight: 600,
                        color: group.now ? Ember.nowInk : Ember.ink2,
                      ),
                    ),
                  ),
                for (final task in group.tasks)
                  TaskRow(
                    task: task,
                    project: projectOf(task),
                    today: today,
                    selected: task.id == _selectedId,
                    onTap: () => select(task),
                    onToggle: () => _toggle(task),
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
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.project,
    required this.today,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    this.showNote = false,
  });

  final Task task;
  final Project? project;
  final String today;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final due = task.dueDate;
    final note = showNote ? firstLine(task.notes) : null;
    return Appear(child: _row(context, done, due, note));
  }

  Widget _row(BuildContext context, bool done, String? due, String? note) {
    return Material(
      color: selected ? Ember.tile : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('task-${task.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line(context, done, due),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(34, 0, 8, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 13, color: Ember.ink3),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          key: Key('task-note-${task.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ember.meta,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, bool done, String? due) {
    return Row(
      children: [
        TaskRing(
          done: done,
          priority: task.priority,
          label: '${done ? 'Undo' : 'Complete'} ${task.title}',
          onTap: onToggle,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                // A completed title fades to grey.
                child: AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.base),
                  curve: Motion.soft,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: done
                      ? Ember.item.copyWith(
                          color: Ember.ink3,
                          decoration: TextDecoration.lineThrough,
                        )
                      : Ember.item.copyWith(color: Ember.ink),
                  child: Text(task.title),
                ),
              ),
              if (task.priority != TaskPriority.none) ...[
                const SizedBox(width: 8),
                PriorityTag(task.priority),
              ],
            ],
          ),
        ),
        if (due != null) ...[
          const SizedBox(width: 10),
          Text(
            formatRelativeDay(due, today: today),
            style: Ember.text(
              12,
              15,
              weight: isDueNow(task, today) ? 600 : 400,
              color: isDueNow(task, today) ? Ember.nowInk : Ember.ink2,
            ),
          ),
        ],
        if (project != null) ...[
          const SizedBox(width: 10),
          NameChip(
            label: project!.name,
            swatch: ProjectColors.of(project!.color),
          ),
        ],
        const SizedBox(width: 4),
      ],
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
  late String? _projectId = widget.task.projectId;
  late String? _dueDate = widget.task.dueDate;
  late String _priority = widget.task.priority;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(_dueDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      helpText: 'Due date',
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = dayKey(picked));
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateTask(
            widget.task.id,
            title: _title.text,
            projectId: _projectId,
            dueDate: _dueDate,
            priority: _priority,
            notes: _notes.text,
          );
      if (!mounted) return;
      setState(() => _error = null);
      showMessage(context, 'Saved.');
    } catch (error) {
      // The typed text stays in the boxes, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
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
    final projectIds = {for (final project in widget.projects) project.id};
    // A task serves its project; the project serves the goal.
    final project = widget.projects
        .where((p) => p.id == _projectId)
        .firstOrNull;
    final servedGoal = widget.goals
        .where((goal) => goal.id == project?.goalId)
        .firstOrNull;
    final dueDate = _dueDate;
    final fieldStyle = Ember.text(13, 16, weight: 400, color: Ember.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Task', style: Ember.h2)),
            IconButton(
              tooltip: 'Close',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Title'),
        TextField(
          key: const Key('task-title'),
          controller: _title,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(errorText: _error),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Project'),
        DropdownButtonFormField<String?>(
          key: const Key('task-project'),
          initialValue: projectIds.contains(_projectId) ? _projectId : null,
          isExpanded: true,
          style: fieldStyle,
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
        if (servedGoal != null) ...[
          const SizedBox(height: 6),
          Text(
            'Serves the goal: ${servedGoal.title}',
            key: const Key('task-served-goal'),
            style: Ember.meta,
          ),
        ],
        const SizedBox(height: 14),
        const FieldLabel('Due date'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('task-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  dueDate == null
                      ? 'Pick a date'
                      : formatRelativeDay(dueDate, today: widget.today),
                ),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              key: const Key('task-date-today'),
              onPressed: () => setState(() => _dueDate = widget.today),
              child: const Text('Today'),
            ),
            if (dueDate != null)
              IconButton(
                key: const Key('task-date-clear'),
                tooltip: 'Remove the date',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _dueDate = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Priority'),
        Wrap(
          spacing: 6,
          children: [
            for (final (value, label) in _priorityLabels)
              ChoiceChip(
                key: Key('priority-$value'),
                label: Text(label),
                selected: _priority == value,
                showCheckmark: false,
                labelStyle: Ember.text(
                  12,
                  15,
                  color: _priority == value ? Ember.white : Ember.ink,
                ),
                selectedColor: Ember.ink,
                backgroundColor: Ember.tile,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _priority = value),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Notes'),
        TextField(
          key: const Key('task-notes'),
          controller: _notes,
          minLines: 4,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Anything to remember about this task',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('task-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('task-delete'),
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete task'),
        ),
      ],
    );
  }
}
