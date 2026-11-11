import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/plan_repository.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';
import '../setup/setup_page.dart';

/// The Life areas page: the list on the left, and on the right a form to
/// add an area or change the selected one.
class AreasPage extends ConsumerStatefulWidget {
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

class _AreasPageState extends ConsumerState<AreasPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final selected = areas.where((area) => area.id == _selectedId).firstOrNull;
    int goalsOf(LifeArea area) =>
        goals.where((goal) => goal.lifeAreaId == area.id).length;

    return PageLayout(
      main: [
        PageHeader(
          title: 'Life areas',
          subtitle: areas.isEmpty
              ? 'The parts of your life you want to look after'
              : countOf(areas.length, 'area'),
        ),
        if (areas.isEmpty)
          const EmptyHint(
            title: 'No life areas yet',
            text:
                'Add one on the right. Suggestions: Health, Mind, Career, '
                'Family, Learning.',
          )
        else
          Column(
            children: [
              for (final area in areas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tile(
                    key: Key('area-${area.id}'),
                    selected: area.id == _selectedId,
                    onTap: () => setState(() {
                      _selectedId = area.id == _selectedId ? null : area.id;
                    }),
                    child: Row(
                      children: [
                        ColorDot(AreaColors.of(area.color).dot, size: 12),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            area.name,
                            style: Ember.text(15, 18, weight: 600),
                          ),
                        ),
                        Text(
                          goalsOf(area) == 0
                              ? 'No goals yet'
                              : countOf(goalsOf(area), 'goal'),
                          style: Ember.meta,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        Text(
          '3 to 8 areas is easier to keep up with. This is a suggestion, '
          'not a limit.',
          style: Ember.meta,
        ),
      ],
      rail: [
        _AreaForm(
          key: ValueKey(selected?.id ?? 'new'),
          area: selected,
          goalCount: selected == null ? 0 : goalsOf(selected),
          existingNames: [for (final area in areas) area.name],
          nextColor: areaColorAt(areas.length),
          onClose: () => setState(() => _selectedId = null),
        ),
      ],
    );
  }
}

class _AreaForm extends ConsumerStatefulWidget {
  const _AreaForm({
    super.key,
    required this.area,
    required this.goalCount,
    required this.existingNames,
    required this.nextColor,
    required this.onClose,
  });

  /// The area being changed, or null to add a new one.
  final LifeArea? area;
  final int goalCount;
  final List<String> existingNames;
  final String nextColor;
  final VoidCallback onClose;

  @override
  ConsumerState<_AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends ConsumerState<_AreaForm> {
  late final _name = TextEditingController(text: widget.area?.name ?? '');
  late String _color = widget.area?.color ?? widget.nextColor;
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
      setState(() => _error = 'Give the area a name.');
      return;
    }
    const duplicate = 'You already have an area with this name.';
    final wanted = _name.text.trim().toLowerCase();
    final ownName = widget.area?.name.trim().toLowerCase();
    if (wanted != ownName &&
        widget.existingNames.any((n) => n.trim().toLowerCase() == wanted)) {
      setState(() => _error = duplicate);
      return;
    }
    final plan = ref.read(planRepositoryProvider);
    try {
      final area = widget.area;
      if (area == null) {
        await plan.addArea(userId: userId, name: _name.text, color: _color);
        if (!mounted) return;
        _name.clear();
        setState(() => _error = null);
      } else {
        await plan.updateArea(area.id, name: _name.text, color: _color);
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } on DuplicateNameException {
      if (mounted) setState(() => _error = duplicate);
    } catch (error) {
      // The typed name stays in the box, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final area = widget.area!;
    final plan = ref.read(planRepositoryProvider);
    final LinkedItems? linked;
    if (widget.goalCount == 0) {
      final confirmed = await confirmDialog(
        context,
        title: 'Delete ${area.name}?',
        message: 'Nothing is linked to this area.',
        confirmLabel: 'Delete',
      );
      linked = confirmed ? LinkedItems.keep : null;
    } else {
      final goals = countOf(widget.goalCount, 'goal');
      linked = await askAboutLinkedItems(
        context,
        title: 'Delete ${area.name}?',
        message:
            '$goals belong to this area. Keep them without an area, or '
            'delete them too, together with their projects and tasks?',
        keepLabel: 'Keep the goals',
        deleteLabel: 'Delete them too',
      );
    }
    if (linked == null) return;
    try {
      await plan.deleteArea(area.id, linked: linked);
      widget.onClose();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.area != null;
    final taken = widget.existingNames.map((n) => n.toLowerCase()).toSet();
    final suggestions = [
      for (final (name, _) in suggestedAreas)
        if (!taken.contains(name.toLowerCase())) name,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(editing ? 'Edit area' : 'New area', style: Ember.h2),
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
          key: const Key('area-name'),
          controller: _name,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(errorText: _error),
        ),
        if (!editing && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in suggestions.take(6))
                ActionChip(
                  label: Text(name),
                  labelStyle: Ember.text(11, 13, color: Ember.ink2),
                  backgroundColor: Ember.neutral,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _name.text = name),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const FieldLabel('Colour'),
        SwatchPicker(
          colors: AreaColors.all,
          selected: _color,
          onChanged: (name) => setState(() => _color = name),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('area-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add area'),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('area-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete area'),
          ),
        ],
      ],
    );
  }
}
