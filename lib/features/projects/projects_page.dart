import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/progress.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The Projects page: the list on the left, and on the right a form to add
/// a project or the details of the selected one.
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final selected = projects.where((p) => p.id == _selectedId).firstOrNull;
    List<Task> tasksOf(Project project) =>
        tasks.where((task) => task.projectId == project.id).toList();

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
                    goal: goals
                        .where((goal) => goal.id == project.goalId)
                        .firstOrNull,
                    tasks: tasksOf(project),
                    selected: project.id == _selectedId,
                    onTap: () => setState(() {
                      _selectedId = project.id == _selectedId
                          ? null
                          : project.id;
                    }),
                  ),
                ),
            ],
          ),
      ],
      rail: [
        _ProjectForm(
          key: ValueKey(selected?.id ?? 'new'),
          project: selected,
          goals: goals,
          tasks: selected == null ? const [] : tasksOf(selected),
          nextColor: ProjectColors.firstUnused(projects.map((p) => p.color)),
          onClose: () => setState(() => _selectedId = null),
        ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.goal,
    required this.tasks,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final Goal? goal;
  final List<Task> tasks;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = ProjectColors.of(project.color);
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final percent = percentDone(tasks);
    return Tile(
      key: Key('project-${project.id}'),
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: swatch.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ProjectIcons.of(project.icon),
              size: 20,
              color: swatch.text,
            ),
          ),
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
                const SizedBox(height: 5),
                Text(
                  goal == null ? 'No goal linked' : 'Goal: ${goal!.title}',
                  overflow: TextOverflow.ellipsis,
                  style: Ember.meta,
                ),
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
                      '$done of ${countOf(tasks.length, 'task')}',
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
  final List<Task> tasks;
  final String nextColor;
  final VoidCallback onClose;

  @override
  ConsumerState<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<_ProjectForm> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  final _newTask = TextEditingController();
  late String _color = widget.project?.color ?? widget.nextColor;
  late String _icon = ProjectIcons.all.containsKey(widget.project?.icon)
      ? widget.project!.icon!
      : ProjectIcons.fallback;
  late String? _goalId = widget.project?.goalId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _newTask.dispose();
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
          _icon = ProjectIcons.fallback;
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

  Future<void> _addTask() async {
    final userId = ref.read(userIdProvider);
    final title = _newTask.text.trim();
    if (userId == null || title.isEmpty) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .addTask(userId: userId, title: title, projectId: widget.project!.id);
      _newTask.clear();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not add the task. ($error)');
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
        Row(
          children: [
            Expanded(
              child: Text(
                editing ? 'Edit project' : 'New project',
                style: Ember.h2,
              ),
            ),
            if (editing)
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
          icons: ProjectIcons.all,
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
          const SizedBox(height: 22),
          Text('Tasks', style: Ember.h3),
          const SizedBox(height: 8),
          if (widget.tasks.isEmpty)
            Text('No tasks yet.', style: Ember.meta)
          else
            for (final task in widget.tasks)
              Row(
                children: [
                  TaskRing(
                    done: task.status == TaskStatus.done,
                    priority: task.priority,
                    label:
                        '${task.status == TaskStatus.done ? 'Undo' : 'Complete'} '
                        '${task.title}',
                    onTap: () => ref
                        .read(taskRepositoryProvider)
                        .setDone(task.id, done: task.status != TaskStatus.done),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      style: task.status == TaskStatus.done
                          ? Ember.item.copyWith(
                              color: Ember.ink3,
                              decoration: TextDecoration.lineThrough,
                            )
                          : Ember.item,
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('project-new-task'),
                  controller: _newTask,
                  onSubmitted: (_) => _addTask(),
                  decoration: const InputDecoration(
                    hintText: 'Add a task to this project',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(onPressed: _addTask, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 14),
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
