import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/sleep.dart' show formatTime, timeOf;
import '../../domain/tags.dart';
import '../../ui/ember.dart';

/// What the add box will create.
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.dueDate,
    required this.dueTime,
    required this.priority,
    required this.projectId,
    required this.tags,
    required this.notes,
  });

  final String title;
  final String? dueDate;
  final String? dueTime;
  final String priority;
  final String? projectId;
  final List<String> tags;
  final String? notes;
}

/// The add-task box (founder's reference). Closed it is one line,
/// "+ Add Task". A click opens it: "What would you like to do?" and a row
/// of options (date, priority, tag, project, more) with Add on the right.
/// Enter adds; Esc closes. The date, project and priority stay for the
/// next task; the rest starts empty again.
class TaskComposer extends StatefulWidget {
  const TaskComposer({
    super.key,
    required this.focusNode,
    required this.today,
    required this.projects,
    required this.knownTags,
    required this.onAdd,
    this.projectId,
    this.priority,
  });

  /// Asking this for focus opens the box (the title bar's "New").
  final FocusNode focusNode;
  final String today;
  final List<Project> projects;
  final List<String> knownTags;

  /// Saves the task; false keeps the typed text (nothing is lost).
  final Future<bool> Function(TaskDraft draft) onAdd;

  /// The project and priority a new task starts with (the page's filter).
  final String? projectId;
  final String? priority;

  @override
  State<TaskComposer> createState() => _TaskComposerState();
}

class _TaskComposerState extends State<TaskComposer> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _note = TextEditingController();
  var _open = false;

  /// True while a menu or a dialog of the box is open, so a click in it
  /// does not close the box.
  var _busy = false;

  late String? _date = widget.today;
  String? _time;
  late String _priority = widget.priority ?? TaskPriority.none;
  late String? _projectId = widget.projectId;
  final _tags = <String>[];
  var _noteOpen = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusAsked);
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusAsked);
    _title.dispose();
    _titleFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  void _focusAsked() {
    if (widget.focusNode.hasFocus) _openBox();
  }

  void _openBox() {
    if (!_open) setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  void _close() {
    if (_busy) return;
    setState(() => _open = false);
    _titleFocus.unfocus();
  }

  Future<T?> _hold<T>(Future<T?> Function() action) async {
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final saved = await widget.onAdd(
      TaskDraft(
        title: title,
        dueDate: _date,
        dueTime: _date == null ? null : _time,
        priority: _priority,
        projectId: _projectId,
        tags: List.of(_tags),
        notes: _noteOpen ? _note.text : null,
      ),
    );
    if (!saved || !mounted) return;
    setState(() {
      _title.clear();
      _note.clear();
      _noteOpen = false;
      _tags.clear();
      _time = null;
    });
    _titleFocus.requestFocus();
  }

  String _dateLabel() {
    final date = _date;
    if (date == null) return 'Date';
    final day = formatRelativeDay(date, today: widget.today);
    return _time == null ? day : '$day ${formatTime(_time!)}';
  }

  Future<void> _pickDate() async {
    final now = parseDayKey(_date ?? widget.today)!;
    final picked = await _hold(
      () => showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
      ),
    );
    if (picked != null) setState(() => _date = dayKey(picked));
  }

  Future<void> _pickTime() async {
    final picked = await _hold(
      () => showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      ),
    );
    if (picked == null) return;
    setState(() {
      _date ??= widget.today;
      _time = timeOf(picked.hour * 60 + picked.minute);
    });
  }

  Future<void> _newTag() async {
    final tag = await _hold(
      () => showDialog<String>(
        context: context,
        builder: (context) => const _NewTagDialog(),
      ),
    );
    final clean = cleanTag(tag ?? '');
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() => _tags.add(clean));
    }
  }

  /// One option in the row: an icon, and its value when one is set.
  Widget _option({
    required String key,
    required IconData icon,
    required String tooltip,
    String? label,
    Color? color,
    required List<PopupMenuEntry<String>> Function() items,
    required ValueChanged<String> onPick,
  }) {
    final shown = color ?? Ember.ink2;
    return PopupMenuButton<String>(
      key: Key(key),
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onOpened: () => _busy = true,
      onCanceled: () => _busy = false,
      onSelected: (value) {
        _busy = false;
        onPick(value);
      },
      itemBuilder: (_) => items(),
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 5 : 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: shown),
            if (label != null) ...[
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.text(12.5, 15, color: shown),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    String value,
    String text, {
    IconData? icon,
    Color? color,
    bool checked = false,
  }) => PopupMenuItem(
    key: Key('compose-$value'),
    value: value,
    height: 36,
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color ?? Ember.ink2),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(text, style: Ember.text(13, 16, weight: 400))),
        if (checked) Icon(Icons.check, size: 16, color: Ember.ink),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      // Closed: one line, as in the founder's reference.
      return Focus(
        focusNode: widget.focusNode,
        child: Material(
          color: Ember.tile,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: const Key('task-compose'),
            borderRadius: BorderRadius.circular(10),
            onTap: _openBox,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.add, size: 16, color: Ember.ink2),
                  const SizedBox(width: 8),
                  Text(
                    'Add Task',
                    style: Ember.text(13, 16, color: Ember.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final project = widget.projects
        .where((p) => p.id == _projectId)
        .firstOrNull;
    final priorityColor = switch (_priority) {
      TaskPriority.high => Ember.nowInk,
      TaskPriority.medium => Ember.amberInk,
      _ => null,
    };
    final today = widget.today;
    final nextMonday = addDays(today, 8 - parseDayKey(today)!.weekday);

    return TapRegion(
      onTapOutside: (_) {
        if (_title.text.trim().isEmpty && !_noteOpen) _close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Container(
          key: const Key('task-composer'),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          decoration: BoxDecoration(
            color: Ember.tile,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Ember.ink, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('task-new'),
                controller: _title,
                focusNode: _titleFocus,
                autofocus: true,
                onSubmitted: (_) => _add(),
                style: Ember.text(14, 18, weight: 400, color: Ember.ink),
                decoration: InputDecoration(
                  hintText: 'What would you like to do?',
                  hintStyle: Ember.text(14, 18, weight: 400, color: Ember.ink3),
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
              ),
              if (_noteOpen) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('compose-note'),
                  controller: _note,
                  minLines: 1,
                  maxLines: 4,
                  style: Ember.text(12.5, 17, weight: 400, color: Ember.ink2),
                  decoration: InputDecoration(
                    hintText: 'Note',
                    hintStyle: Ember.text(
                      12.5,
                      17,
                      weight: 400,
                      color: Ember.ink3,
                    ),
                    filled: false,
                    isCollapsed: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
              ],
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in _tags)
                      InkWell(
                        key: Key('compose-tag-chip-$tag'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _tags.remove(tag)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Ember.neutral,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$tag  ×',
                            style: Ember.text(11.5, 14, color: Ember.ink2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _option(
                    key: 'compose-date',
                    icon: Icons.calendar_today_outlined,
                    tooltip: 'Date',
                    label: _dateLabel(),
                    color: _date == null ? null : Ember.blueInk,
                    items: () => [
                      _item('date-today', 'Today', icon: Icons.today_outlined),
                      _item(
                        'date-tomorrow',
                        'Tomorrow',
                        icon: Icons.wb_sunny_outlined,
                      ),
                      _item(
                        'date-next-week',
                        'Next Monday',
                        icon: Icons.next_week_outlined,
                      ),
                      _item(
                        'date-pick',
                        'Pick a date…',
                        icon: Icons.event_outlined,
                      ),
                      _item(
                        'date-time',
                        _time == null ? 'Add a time…' : 'Change the time…',
                        icon: Icons.schedule,
                      ),
                      if (_time != null)
                        _item(
                          'date-no-time',
                          'No time',
                          icon: Icons.timer_off_outlined,
                        ),
                      _item(
                        'date-none',
                        'No date',
                        icon: Icons.event_busy_outlined,
                      ),
                    ],
                    onPick: (value) {
                      switch (value) {
                        case 'date-today':
                          setState(() => _date = today);
                        case 'date-tomorrow':
                          setState(() => _date = addDays(today, 1));
                        case 'date-next-week':
                          setState(() => _date = nextMonday);
                        case 'date-pick':
                          _pickDate();
                        case 'date-time':
                          _pickTime();
                        case 'date-no-time':
                          setState(() => _time = null);
                        case 'date-none':
                          setState(() {
                            _date = null;
                            _time = null;
                          });
                      }
                    },
                  ),
                  _option(
                    key: 'compose-priority',
                    icon: _priority == TaskPriority.none
                        ? Icons.outlined_flag
                        : Icons.flag,
                    tooltip: 'Priority',
                    color: priorityColor,
                    items: () => [
                      _item(
                        'priority-high',
                        'High',
                        icon: Icons.flag,
                        color: Ember.nowInk,
                        checked: _priority == TaskPriority.high,
                      ),
                      _item(
                        'priority-medium',
                        'Medium',
                        icon: Icons.flag,
                        color: Ember.amberInk,
                        checked: _priority == TaskPriority.medium,
                      ),
                      _item(
                        'priority-none',
                        'No priority',
                        icon: Icons.outlined_flag,
                        checked: _priority == TaskPriority.none,
                      ),
                    ],
                    onPick: (value) => setState(
                      () => _priority = switch (value) {
                        'priority-high' => TaskPriority.high,
                        'priority-medium' => TaskPriority.medium,
                        _ => TaskPriority.none,
                      },
                    ),
                  ),
                  _option(
                    key: 'compose-tag',
                    icon: Icons.sell_outlined,
                    tooltip: 'Tags',
                    color: _tags.isEmpty ? null : Ember.ink,
                    items: () => [
                      for (final tag in widget.knownTags.take(12))
                        _item(
                          'tag-$tag',
                          '#$tag',
                          checked: _tags.contains(tag),
                        ),
                      _item('tag-new', 'New tag…', icon: Icons.add),
                    ],
                    onPick: (value) {
                      if (value == 'tag-new') {
                        _newTag();
                        return;
                      }
                      final tag = value.substring(4);
                      setState(
                        () => _tags.contains(tag)
                            ? _tags.remove(tag)
                            : _tags.add(tag),
                      );
                    },
                  ),
                  _option(
                    key: 'compose-project',
                    icon: Icons.drive_file_move_outline,
                    tooltip: 'Project',
                    label: project?.name,
                    color: project == null
                        ? null
                        : ProjectColors.of(project.color).text,
                    items: () => [
                      for (final p in widget.projects)
                        _item(
                          'project-${p.id}',
                          p.name,
                          icon: ItemIcons.of(p.icon),
                          color: ProjectColors.of(p.color).dot,
                          checked: p.id == _projectId,
                        ),
                      _item(
                        'project-none',
                        'No project',
                        icon: Icons.folder_off_outlined,
                        checked: _projectId == null,
                      ),
                    ],
                    onPick: (value) => setState(
                      () => _projectId = value == 'project-none'
                          ? null
                          : value.substring(8),
                    ),
                  ),
                  _option(
                    key: 'compose-more',
                    icon: Icons.more_horiz,
                    tooltip: 'More',
                    items: () => [
                      _item(
                        'more-note',
                        _noteOpen ? 'Remove the note' : 'Add a note',
                        icon: Icons.notes,
                      ),
                      _item(
                        'more-time',
                        _time == null ? 'Add a time…' : 'Change the time…',
                        icon: Icons.schedule,
                      ),
                      _item(
                        'more-clear',
                        'Clear the options',
                        icon: Icons.restart_alt,
                      ),
                    ],
                    onPick: (value) {
                      switch (value) {
                        case 'more-note':
                          setState(() {
                            _noteOpen = !_noteOpen;
                            if (!_noteOpen) _note.clear();
                          });
                        case 'more-time':
                          _pickTime();
                        case 'more-clear':
                          setState(() {
                            _date = null;
                            _time = null;
                            _priority = TaskPriority.none;
                            _projectId = null;
                            _tags.clear();
                          });
                      }
                    },
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('task-add'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: _title.text.trim().isEmpty ? null : _add,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the name of a new tag. It keeps its own text box, so the box
/// lives until the dialog has closed.
class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog();

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New tag', style: Ember.h2),
      content: TextField(
        key: const Key('compose-tag-name'),
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'For example: errand'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('compose-tag-save'),
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text('Add tag'),
        ),
      ],
    );
  }
}
