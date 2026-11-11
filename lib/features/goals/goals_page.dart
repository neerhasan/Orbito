import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/dates.dart';
import '../../domain/progress.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The Goals page: the list on the left, and on the right a form to add a
/// goal or the details of the selected one.
class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final selected = goals.where((goal) => goal.id == _selectedId).firstOrNull;
    final today = dayKey(DateTime.now());
    List<Task> tasksOf(Goal goal) =>
        tasksOfGoal(goal.id, projects: projects, tasks: tasks);

    return PageLayout(
      main: [
        const PageHeader(
          title: 'Goals',
          subtitle: 'Percent comes from tasks done.',
        ),
        if (goals.isEmpty)
          const EmptyHint(
            title: 'No goals yet',
            text: 'A goal is one result you want in a life area.',
          )
        else
          Column(
            children: [
              for (final goal in goals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GoalTile(
                    goal: goal,
                    area: areas
                        .where((area) => area.id == goal.lifeAreaId)
                        .firstOrNull,
                    tasks: tasksOf(goal),
                    today: today,
                    selected: goal.id == _selectedId,
                    onTap: () => setState(() {
                      _selectedId = goal.id == _selectedId ? null : goal.id;
                    }),
                  ),
                ),
            ],
          ),
      ],
      rail: [
        _GoalForm(
          key: ValueKey(selected?.id ?? 'new'),
          goal: selected,
          areas: areas,
          projects: selected == null
              ? const []
              : projects.where((p) => p.goalId == selected.id).toList(),
          today: today,
          onClose: () => setState(() => _selectedId = null),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.area,
    required this.tasks,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final LifeArea? area;
  final List<Task> tasks;
  final String today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final percent = percentDone(tasks);
    final targetDate = goal.targetDate;
    return Tile(
      key: Key('goal-${goal.id}'),
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.text(15, 18, weight: 600),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (area != null) ...[
                      NameChip(
                        label: area!.name,
                        swatch: AreaColors.of(area!.color),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        targetDate == null
                            ? 'No target date'
                            : 'By ${formatShortDay(targetDate, today: today)}',
                        overflow: TextOverflow.ellipsis,
                        style: Ember.meta,
                      ),
                    ),
                  ],
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
                      tasks.isEmpty
                          ? 'No tasks yet'
                          : '$done of ${countOf(tasks.length, 'task')}',
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

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({
    super.key,
    required this.goal,
    required this.areas,
    required this.projects,
    required this.today,
    required this.onClose,
  });

  /// The goal being changed, or null to add a new one.
  final Goal? goal;
  final List<LifeArea> areas;

  /// The projects that serve this goal.
  final List<Project> projects;
  final String today;
  final VoidCallback onClose;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final _doneWhen = TextEditingController(
    text: widget.goal?.doneWhen ?? '',
  );
  late String? _areaId = widget.goal?.lifeAreaId;
  late String? _targetDate = widget.goal?.targetDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _doneWhen.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(_targetDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      helpText: 'Target date',
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = dayKey(picked));
    }
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the goal a title.');
      return;
    }
    final doneWhen = _doneWhen.text.trim().isEmpty
        ? null
        : _doneWhen.text.trim();
    final plan = ref.read(planRepositoryProvider);
    try {
      final goal = widget.goal;
      if (goal == null) {
        await plan.addGoal(
          userId: userId,
          title: _title.text,
          lifeAreaId: _areaId,
          targetDate: _targetDate,
          doneWhen: doneWhen,
        );
        if (!mounted) return;
        _title.clear();
        _doneWhen.clear();
        setState(() {
          _error = null;
          _targetDate = null;
        });
      } else {
        await plan.updateGoal(
          goal.id,
          title: _title.text,
          lifeAreaId: _areaId,
          targetDate: _targetDate,
          doneWhen: doneWhen,
        );
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } catch (error) {
      // The typed text stays in the boxes, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final goal = widget.goal!;
    final projects = widget.projects.length;
    final LinkedItems? linked;
    if (projects == 0) {
      final confirmed = await confirmDialog(
        context,
        title: 'Delete ${goal.title}?',
        message: 'Nothing is linked to this goal.',
        confirmLabel: 'Delete',
      );
      linked = confirmed ? LinkedItems.keep : null;
    } else {
      linked = await askAboutLinkedItems(
        context,
        title: 'Delete ${goal.title}?',
        message:
            '${countOf(projects, 'project')} serve this goal. Keep them '
            'without a goal, or delete them too? Deleting a project also '
            'deletes its tasks.',
        keepLabel: 'Keep them',
        deleteLabel: 'Delete them too',
      );
    }
    if (linked == null) return;
    try {
      await ref
          .read(planRepositoryProvider)
          .deleteGoal(goal.id, linked: linked);
      widget.onClose();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.goal != null;
    final areaIds = {for (final area in widget.areas) area.id};
    final targetDate = _targetDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(editing ? 'Edit goal' : 'New goal', style: Ember.h2),
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
        const FieldLabel('Title'),
        TextField(
          key: const Key('goal-title'),
          controller: _title,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(errorText: _error),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Life area'),
        DropdownButtonFormField<String?>(
          key: const Key('goal-area'),
          initialValue: areaIds.contains(_areaId) ? _areaId : null,
          isExpanded: true,
          style: Ember.text(13, 16, weight: 400, color: Ember.ink),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final area in widget.areas)
              DropdownMenuItem(
                value: area.id,
                child: Text(area.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _areaId = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Target date'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('goal-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  targetDate == null
                      ? 'Pick a date'
                      : formatShortDay(targetDate, today: widget.today),
                ),
              ),
            ),
            if (targetDate != null)
              IconButton(
                key: const Key('goal-date-clear'),
                tooltip: 'Remove the date',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _targetDate = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Done when'),
        TextField(
          key: const Key('goal-done-when'),
          controller: _doneWhen,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'How you will know the goal is reached',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('goal-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add goal'),
        ),
        if (editing) ...[
          const SizedBox(height: 22),
          Text('Projects', style: Ember.h3),
          const SizedBox(height: 8),
          if (widget.projects.isEmpty)
            Text(
              'No projects serve this goal yet. Link one on the Projects '
              'page.',
              style: Ember.meta,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final project in widget.projects)
                  NameChip(
                    label: project.name,
                    swatch: ProjectColors.of(project.color),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Tasks belong to projects. Add tasks on the Projects or Tasks '
            'page; the goal counts them through its projects.',
            style: Ember.meta,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            key: const Key('goal-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete goal'),
          ),
        ],
      ],
    );
  }
}
