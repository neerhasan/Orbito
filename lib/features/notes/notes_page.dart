import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show NoteRequest, noteRequestProvider;
import '../../data/local/app_database.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The Notes page: a list of notes, and on the right the open note or the
/// form for a new one. A note may be linked to one project.
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  /// The note open on the right. Null shows the form for a new note.
  String? _selectedId;

  /// The project a new note starts linked to.
  String? _newProjectId;

  /// Shows only the notes of this project. Null shows all.
  String? _filterProjectId;

  /// Bumps to give the new-note form fresh fields after a request.
  var _formSerial = 0;

  void _select(String? id) => setState(() {
    _selectedId = id;
    _newProjectId = null;
    _formSerial++;
  });

  void _handle(String request) {
    if (request == NoteRequest.newNote) {
      _select(null);
    } else if (request.startsWith('new:')) {
      _select(null);
      setState(() => _newProjectId = request.substring(4));
    } else {
      _select(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(noteRequestProvider);
    if (request != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handle(request);
        ref.read(noteRequestProvider.notifier).handled();
      });
    }
    final notes = ref.watch(notesProvider).value ?? const <Note>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    Project? projectOf(Note note) =>
        projects.where((p) => p.id == note.projectId).firstOrNull;

    final filter = projects.any((p) => p.id == _filterProjectId)
        ? _filterProjectId
        : null;
    final shown = filter == null
        ? notes
        : notes.where((n) => n.projectId == filter).toList();
    final selected = notes.where((n) => n.id == _selectedId).firstOrNull;

    return PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: PageHeader(
                title: 'Notes',
                subtitle: 'Write things down. Link a note to a project.',
              ),
            ),
            FilledButton.icon(
              key: const Key('note-new-button'),
              onPressed: () => _select(null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New note'),
            ),
          ],
        ),
        if (projects.isNotEmpty && notes.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                key: const Key('note-filter'),
                initialValue: filter,
                isExpanded: true,
                style: Ember.text(13, 16, weight: 400, color: Ember.ink),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All notes')),
                  for (final project in projects)
                    DropdownMenuItem(
                      value: project.id,
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _filterProjectId = value),
              ),
            ),
          ),
        if (shown.isEmpty)
          EmptyHint(
            title: notes.isEmpty ? 'No notes yet' : 'No notes here',
            text: notes.isEmpty
                ? 'Write your first note on the right.'
                : 'No note is linked to this project yet.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final note in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NoteTile(
                    note: note,
                    project: projectOf(note),
                    selected: note.id == _selectedId,
                    onTap: () =>
                        _select(note.id == _selectedId ? null : note.id),
                  ),
                ),
            ],
          ),
      ],
      rail: [
        _NoteForm(
          key: ValueKey('${selected?.id ?? 'new'}-$_formSerial'),
          note: selected,
          projects: projects,
          startProjectId: _newProjectId ?? filter,
          onSaved: (id) => setState(() {
            _selectedId = id;
            _newProjectId = null;
          }),
          onDeleted: () => _select(null),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final Project? project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = note.title.isEmpty ? 'Untitled' : note.title;
    final swatch = project == null ? null : ProjectColors.of(project!.color);
    return Tile(
      key: Key('note-${note.id}'),
      onTap: onTap,
      selected: selected,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.sticky_note_2_outlined,
              size: 18,
              color: Ember.ink2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.text(15, 18, weight: 600),
                ),
                if (note.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.body.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.meta,
                  ),
                ],
              ],
            ),
          ),
          if (project != null) ...[
            const SizedBox(width: 12),
            Tag(
              project!.name,
              background: swatch!.soft,
              foreground: swatch.text,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteForm extends ConsumerStatefulWidget {
  const _NoteForm({
    super.key,
    required this.note,
    required this.projects,
    required this.startProjectId,
    required this.onSaved,
    required this.onDeleted,
  });

  /// The note being changed, or null to write a new one.
  final Note? note;
  final List<Project> projects;

  /// The project a new note starts linked to.
  final String? startProjectId;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<_NoteForm> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late String? _projectId = widget.note?.projectId ?? widget.startProjectId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      setState(() => _error = 'Write a title or some text.');
      return;
    }
    final repository = ref.read(captureRepositoryProvider);
    try {
      final note = widget.note;
      if (note == null) {
        final id = await repository.addNote(
          userId: userId,
          title: _title.text,
          body: _body.text,
          projectId: _projectId,
        );
        if (mounted) widget.onSaved(id);
      } else {
        await repository.updateNote(
          note.id,
          title: _title.text,
          body: _body.text,
          projectId: _projectId,
        );
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } catch (error) {
      // The text stays in the boxes, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final note = widget.note!;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this note?',
      message: note.title.isEmpty ? 'It will be removed.' : note.title,
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(captureRepositoryProvider).deleteNote(note.id);
      widget.onDeleted();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.note != null;
    final ids = {for (final project in widget.projects) project.id};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(editing ? 'Edit note' : 'New note', style: Ember.h2),
        const SizedBox(height: 14),
        const FieldLabel('Title'),
        TextField(
          key: const Key('note-title'),
          controller: _title,
          decoration: InputDecoration(errorText: _error),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Note'),
        TextField(
          key: const Key('note-body'),
          controller: _body,
          minLines: 8,
          maxLines: 16,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(hintText: 'Write here…'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Project (optional)'),
        DropdownButtonFormField<String?>(
          key: const Key('note-project'),
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
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('note-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add note'),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('note-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete note'),
          ),
        ],
      ],
    );
  }
}
