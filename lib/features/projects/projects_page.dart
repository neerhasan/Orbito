import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart'
    show formatWorked, secondsByTask, secondsOfProject;
import '../../domain/progress.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';
import '../tasks/tasks_page.dart' show TaskForm, TaskRow;

/// The Projects page. It has two views:
/// - the list of projects, with a form on the right to add one;
/// - one open project with all its tasks and their notes. On the right is
///   the selected task, or the form to change the project.
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  /// The project that is open, or null for the list.
  String? _openId;

  /// The task selected inside the open project.
  String? _taskId;

  final _newTask = TextEditingController();

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  void _open(String? projectId) => setState(() {
    _openId = projectId;
    _taskId = null;
    _newTask.clear();
  });

  Future<void> _addTask(Project project) async {
    final userId = ref.read(userIdProvider);
    final title = _newTask.text.trim();
    if (userId == null || title.isEmpty) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .addTask(userId: userId, title: title, projectId: project.id);
      _newTask.clear();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not add the task. ($error)');
    }
  }

  Future<void> _toggle(Task task) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .setDone(task.id, done: task.status != TaskStatus.done);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final today = dayKey(ref.watch(clockProvider)());
    final byTask = secondsByTask(
      ref.watch(focusSessionsProvider).value ?? const <FocusSession>[],
    );
    List<Task> tasksOf(Project project) =>
        tasks.where((task) => task.projectId == project.id).toList();
    int focusOf(Project project) => secondsOfProject(project.id, tasks, byTask);
    Goal? goalOf(Project project) =>
        goals.where((goal) => goal.id == project.goalId).firstOrNull;

    final open = projects.where((p) => p.id == _openId).firstOrNull;
    if (open == null) {
      return PageLayout(
        main: [
          const PageHeader(
            title: 'Projects',
            subtitle: 'Percent comes from tasks done.',
          ),
          if (projects.isEmpty)
            const EmptyHint(
              title: 'No projects yet',
              text: 'A project groups tasks that serve one goal.',
            )
          else
            Column(
              children: [
                for (final project in projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProjectTile(
                      project: project,
                      goal: goalOf(project),
                      tasks: tasksOf(project),
                      focusSeconds: focusOf(project),
                      onTap: () => _open(project.id),
                    ),
                  ),
              ],
            ),
        ],
        rail: [
          _ProjectForm(
            key: const ValueKey('new'),
            project: null,
            goals: goals,
            tasks: const [],
            nextColor: ProjectColors.firstUnused(projects.map((p) => p.color)),
            onClose: () {},
          ),
        ],
      );
    }

    final openTasks = tasksOf(open);
    // Open tasks first, then the completed ones.
    final ordered = [
      ...openTasks.where((task) => task.status != TaskStatus.done),
      ...openTasks.where((task) => task.status == TaskStatus.done),
    ];
    final selectedTask = openTasks
        .where((task) => task.id == _taskId)
        .firstOrNull;
    return PageLayout(
      main: [
        _ProjectHeader(
          project: open,
          goal: goalOf(open),
          tasks: openTasks,
          focusSeconds: focusOf(open),
          onBack: () => _open(null),
        ),
        const SizedBox(height: 22),
        Text('Tasks', style: Ember.h3),
        const SizedBox(height: 8),
        if (ordered.isEmpty)
          const EmptyHint(
            title: 'No tasks yet',
            text: 'Add the first task of this project below.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final task in ordered)
                TaskRow(
                  task: task,
                  project: null,
                  today: today,
                  selected: task.id == _taskId,
                  showNote: true,
                  onTap: () => setState(() {
                    _taskId = task.id == _taskId ? null : task.id;
                  }),
                  onToggle: () => _toggle(task),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('project-new-task'),
                controller: _newTask,
                onSubmitted: (_) => _addTask(open),
                decoration: const InputDecoration(
                  hintText: 'Add a task to this project',
                ),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              key: const Key('project-add-task'),
              onPressed: () => _addTask(open),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
      rail: [
        if (selectedTask != null)
          TaskForm(
            key: ValueKey(selectedTask.id),
            task: selectedTask,
            projects: projects,
            goals: goals,
            today: today,
            onClose: () => setState(() => _taskId = null),
          )
        else
          _ProjectForm(
            key: ValueKey(open.id),
            project: open,
            goals: goals,
            tasks: openTasks,
            nextColor: open.color,
            onClose: () => _open(null),
          ),
      ],
    );
  }
}

/// The goal a project serves: its icon and title in the goal's colour.
class _GoalChip extends StatelessWidget {
  const _GoalChip(this.goal);

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return NameChip(
      key: Key('goal-chip-${goal.id}'),
      label: goal.title,
      swatch: GoalColors.of(goal.color),
      icon: ItemIcons.of(goal.icon, orElse: ItemIcons.goalFallback),
    );
  }
}

/// The square with the project's icon in the project's colour.
class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon(this.project, {this.size = 40});

  final Project project;
  final double size;

  @override
  Widget build(BuildContext context) {
    final swatch = ProjectColors.of(project.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: swatch.soft,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        ItemIcons.of(project.icon),
        size: size / 2,
        color: swatch.text,
      ),
    );
  }
}

/// "2 of 5 tasks", with the focus time when there is some.
String _progressLine(int done, int total, int focusSeconds) {
  final tasks = '$done of ${countOf(total, 'task')}';
  return focusSeconds == 0
      ? tasks
      : '$tasks · ${formatWorked(focusSeconds)} focused';
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.goal,
    required this.tasks,
    required this.focusSeconds,
    required this.onTap,
  });

  final Project project;
  final Goal? goal;
  final List<Task> tasks;
  final int focusSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final percent = percentDone(tasks);
    return Tile(
      key: Key('project-${project.id}'),
      onTap: onTap,
      child: Row(
        children: [
          _ProjectIcon(project),
          const SizedBox(width: 18),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.text(15, 18, weight: 600),
                ),
                const SizedBox(height: 6),
                if (goal == null)
                  Text('No goal linked', style: Ember.meta)
                else
                  _GoalChip(goal!),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progressLine(done, tasks.length, focusSeconds),
                      style: Ember.meta,
                    ),
                    Text('$percent%', style: Ember.item),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(percent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The top of an open project: back arrow, icon, name, goal and progress.
class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.goal,
    required this.tasks,
    required this.focusSeconds,
    required this.onBack,
  });

  final Project project;
  final Goal? goal;
  final List<Task> tasks;
  final int focusSeconds;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final percent = percentDone(tasks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('project-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All projects'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _ProjectIcon(project, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.h1Small.copyWith(color: Ember.ink),
                  ),
                  const SizedBox(height: 6),
                  if (goal == null)
                    Text('No goal linked', style: Ember.meta)
                  else
                    _GoalChip(goal!),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _progressLine(done, tasks.length, focusSeconds),
              style: Ember.meta,
            ),
            Text('$percent%', style: Ember.item),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(percent),
      ],
    );
  }
}

class _ProjectForm extends ConsumerStatefulWidget {
  const _ProjectForm({
    super.key,
    required this.project,
    required this.goals,
    required this.tasks,
    required this.nextColor,
    required this.onClose,
  });

  /// The project being changed, or null to add a new one.
  final Project? project;
  final List<Goal> goals;

  /// The project's tasks, so deleting can ask what happens to them.
  final List<Task> tasks;
  final String nextColor;
  final VoidCallback onClose;

  @override
  ConsumerState<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<_ProjectForm> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late String _color = widget.project?.color ?? widget.nextColor;
  late String _icon = ItemIcons.all.containsKey(widget.project?.icon)
      ? widget.project!.icon!
      : ItemIcons.fallback;
  late String? _goalId = widget.project?.goalId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the project a name.');
      return;
    }
    final plan = ref.read(planRepositoryProvider);
    try {
      final project = widget.project;
      if (project == null) {
        await plan.addProject(
          userId: userId,
          name: _name.text,
          color: _color,
          icon: _icon,
          goalId: _goalId,
        );
        if (!mounted) return;
        _name.clear();
        setState(() {
          _error = null;
          _goalId = null;
          _icon = ItemIcons.fallback;
        });
      } else {
        await plan.updateProject(
          project.id,
          name: _name.text,
          color: _color,
          icon: _icon,
          goalId: _goalId,
        );
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } catch (error) {
      // The typed name stays in the box, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final project = widget.project!;
    final LinkedItems? linked;
    if (widget.tasks.isEmpty) {
      final confirmed = await confirmDialog(
        context,
        title: 'Delete ${project.name}?',
        message: 'This project has no tasks.',
        confirmLabel: 'Delete',
      );
      linked = confirmed ? LinkedItems.keep : null;
    } else {
      linked = await askAboutLinkedItems(
        context,
        title: 'Delete ${project.name}?',
        message:
            '${countOf(widget.tasks.length, 'task')} belong to this '
            'project. Keep them without a project, or delete them too?',
        keepLabel: 'Keep the tasks',
        deleteLabel: 'Delete them too',
      );
    }
    if (linked == null) return;
    try {
      await ref
          .read(planRepositoryProvider)
          .deleteProject(project.id, linked: linked);
      widget.onClose();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.project != null;
    final goalIds = {for (final goal in widget.goals) goal.id};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(editing ? 'Edit project' : 'New project', style: Ember.h2),
        const SizedBox(height: 14),
        const FieldLabel('Name'),
        TextField(
          key: const Key('project-name'),
          controller: _name,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(errorText: _error),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Serves goal'),
        DropdownButtonFormField<String?>(
          key: const Key('project-goal'),
          initialValue: goalIds.contains(_goalId) ? _goalId : null,
          isExpanded: true,
          style: Ember.text(13, 16, weight: 400, color: Ember.ink),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final goal in widget.goals)
              DropdownMenuItem(
                value: goal.id,
                child: Text(goal.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _goalId = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Colour'),
        SwatchPicker(
          colors: ProjectColors.all,
          selected: _color,
          onChanged: (name) => setState(() => _color = name),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Icon'),
        IconPicker(
          icons: ItemIcons.all,
          selected: _icon,
          swatch: ProjectColors.of(_color),
          onChanged: (name) => setState(() => _icon = name),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('project-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add project'),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('project-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete project'),
          ),
        ],
      ],
    );
  }
}
