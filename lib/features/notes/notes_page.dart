import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show NoteRequest, noteRequestProvider;
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/note_tree.dart';
import '../../domain/sleep.dart' show formatTime, timeOf;
import '../../ui/ember.dart';
import '../../ui/widgets.dart';
import 'note_editor.dart';

/// The cover colours a page may have (orange is left out: it means "now").
const _covers = <String, Color>{
  'grey': Color(0xFFD9D6CE),
  'blue': Color(0xFFBFD3F7),
  'green': Color(0xFFBFE5CC),
  'violet': Color(0xFFD5C8F4),
  'amber': Color(0xFFF3DFA6),
  'pink': Color(0xFFEDC9F2),
  'teal': Color(0xFFB5E0DE),
  'brown': Color(0xFFE3CBB5),
};

/// The icons a page may have.
const _emojis = [
  '📄', '📝', '📌', '📎', '📚', '📖', '🗂️', '🗒️', //
  '💡', '🎯', '🚀', '⭐', '✅', '🔥', '🧠', '💬', //
  '🏠', '💼', '🎓', '💰', '🏋️', '🧘', '🍎', '✈️', //
  '🌱', '🌍', '🎨', '🎵', '📷', '💻', '🛠️', '🔒', //
  '❤️', '😊', '🙏', '🌙', '☀️', '⏰', '📅', '🧾', //
];

/// "Edited Today, 9:05 AM" from a stored time.
String _edited(String stored, String today) {
  final moment = parseStoredTime(stored);
  if (moment == null) return '';
  final day = formatRelativeDay(dayKey(moment), today: today);
  return 'Edited $day, '
      '${formatTime(timeOf(moment.hour * 60 + moment.minute))}';
}

/// The Notes page, after Notion: pages inside pages on the left (with
/// favourites, search and the Trash), and the open page on the right with
/// its icon, cover, title and blocks. Everything saves by itself.
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  /// The page open on the right; null opens the first page.
  String? _openId;
  final _expanded = <String>{};
  var _query = '';

  String? get _userId => ref.read(userIdProvider);

  void _open(String id) {
    final pages = ref.read(notesProvider).value ?? const <Note>[];
    final byId = pagesById(pages);
    setState(() {
      _openId = id;
      // Show the page in the tree: open every page it sits inside.
      for (final page in pathTo(byId, id)) {
        if (page.id != id) _expanded.add(page.id);
      }
    });
  }

  Future<void> _newPage({String? parentId, String? projectId}) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final id = await ref
          .read(captureRepositoryProvider)
          .createPage(userId: userId, parentId: parentId, projectId: projectId);
      if (parentId != null) _expanded.add(parentId);
      if (mounted) setState(() => _openId = id);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not add a page. ($error)');
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  void _handle(String request) {
    if (request == NoteRequest.newNote) {
      _newPage();
    } else if (request.startsWith('new:')) {
      _newPage(projectId: request.substring(4));
    } else {
      _open(request);
    }
  }

  Future<void> _trash(Note page) async {
    await _guard(() => ref.read(captureRepositoryProvider).trashPage(page.id));
    if (mounted) showMessage(context, 'Moved to the Trash: ${pageTitle(page)}');
  }

  Future<void> _moveTo(Note page, List<Note> pages) async {
    final byId = pagesById(pages);
    final choices = [
      for (final other in pages)
        if (!isHidden(byId, other.id) &&
            canMoveUnder(pages, page.id, other.id) &&
            other.id != page.parentId)
          other,
    ]..sort((a, b) => pageTitle(a).compareTo(pageTitle(b)));
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Move "${pageTitle(page)}" to', style: Ember.h2),
        children: [
          if (page.parentId != null)
            SimpleDialogOption(
              key: const Key('move-to-top'),
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Top level (no parent page)'),
            ),
          for (final other in choices)
            SimpleDialogOption(
              key: Key('move-to-${other.id}'),
              onPressed: () => Navigator.pop(context, other.id),
              child: Text('${other.icon ?? '📄'}  ${pageTitle(other)}'),
            ),
        ],
      ),
    );
    final userId = _userId;
    if (target == null || userId == null) return;
    final parent = target.isEmpty ? null : target;
    await _guard(
      () => ref
          .read(captureRepositoryProvider)
          .movePage(
            page.id,
            userId: userId,
            parentId: parent,
            sortOrder: nextSortOrder(pages, parent),
          ),
    );
    if (parent != null && mounted) setState(() => _expanded.add(parent));
  }

  Future<void> _showTrash() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _TrashDialog(userId: _userId ?? ''),
    );
  }

  /// A page dropped on another page in the tree goes inside it.
  Future<void> _dropInside(Note dragged, Note target, List<Note> pages) async {
    final userId = _userId;
    if (userId == null || !canMoveUnder(pages, dragged.id, target.id)) return;
    await _guard(
      () => ref
          .read(captureRepositoryProvider)
          .movePage(
            dragged.id,
            userId: userId,
            parentId: target.id,
            sortOrder: nextSortOrder(pages, target.id),
          ),
    );
    if (mounted) setState(() => _expanded.add(target.id));
  }

  _PageMenu _menuFor(Note page, List<Note> pages, {bool big = false}) =>
      _PageMenu(
        page: page,
        big: big,
        onFavorite: () => _guard(
          () => ref
              .read(captureRepositoryProvider)
              .setFavorite(page.id, favorite: !isFavorite(page)),
        ),
        onMove: () => _moveTo(page, pages),
        onTrash: () => _trash(page),
      );

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
    final pages = ref.watch(notesProvider).value ?? const <Note>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final today = dayKey(ref.watch(clockProvider)());
    final byId = pagesById(pages);
    final top = childrenOf(pages, null);
    var open = byId[_openId];
    if (open == null || isHidden(byId, open.id)) open = top.firstOrNull;
    final favorites = favoritePages(pages);
    final found = searchPages(pages, _query);
    final trashCount = trashedPages(pages).length;

    Widget tree(Note page, int depth) {
      final children = childrenOf(pages, page.id);
      final expanded = _expanded.contains(page.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageRow(
            page: page,
            depth: depth,
            open: page.id == open?.id,
            expanded: expanded,
            hasChildren: children.isNotEmpty,
            onOpen: () => _open(page.id),
            onToggle: () => setState(
              () =>
                  expanded ? _expanded.remove(page.id) : _expanded.add(page.id),
            ),
            onAdd: () => _newPage(parentId: page.id),
            onDrop: (dragged) => _dropInside(dragged, page, pages),
            canDrop: (dragged) => canMoveUnder(pages, dragged.id, page.id),
            menu: _menuFor(page, pages),
          ),
          if (expanded)
            if (children.isEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: 30.0 + 14 * (depth + 1),
                  bottom: 4,
                ),
                child: Text('No pages inside', style: Ember.caption),
              )
            else
              for (final child in children) tree(child, depth + 1),
        ],
      );
    }

    final sidebar = Container(
      width: 250,
      decoration: BoxDecoration(
        color: Ember.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: TextField(
              key: const Key('notes-search'),
              onChanged: (value) => setState(() => _query = value),
              style: Ember.item.copyWith(color: Ember.ink),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search pages',
                prefixIcon: Icon(Icons.search, size: 18),
                prefixIconConstraints: BoxConstraints(minWidth: 34),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              children: [
                if (_query.trim().isNotEmpty) ...[
                  const _SideLabel('Results'),
                  if (found.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('No pages match.', style: Ember.meta),
                    ),
                  for (final page in found)
                    _PageRow(
                      key: Key('search-${page.id}'),
                      page: page,
                      depth: 0,
                      open: page.id == open?.id,
                      expanded: false,
                      hasChildren: false,
                      onOpen: () => _open(page.id),
                    ),
                ] else ...[
                  if (favorites.isNotEmpty) ...[
                    const _SideLabel('Favorites'),
                    for (final page in favorites)
                      _PageRow(
                        key: Key('favorite-${page.id}'),
                        page: page,
                        depth: 0,
                        open: page.id == open?.id,
                        expanded: false,
                        hasChildren: false,
                        onOpen: () => _open(page.id),
                      ),
                    const SizedBox(height: 10),
                  ],
                  _SideLabel(
                    'Pages',
                    trailing: IconButton(
                      key: const Key('notes-new-top'),
                      tooltip: 'Add a page',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      onPressed: _newPage,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  for (final page in top) tree(page, 0),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Ember.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SideButton(
                  key: const Key('notes-new'),
                  icon: Icons.add_rounded,
                  label: 'New page',
                  onTap: _newPage,
                ),
                _SideButton(
                  key: const Key('notes-trash'),
                  icon: Icons.delete_outline_rounded,
                  label: trashCount == 0 ? 'Trash' : 'Trash · $trashCount',
                  onTap: _showTrash,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final openPage = open;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sidebar,
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Ember.paper,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.hardEdge,
            child: openPage == null
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EmptyHint(
                            title: 'No pages yet',
                            text:
                                'A page holds anything: notes, lists, plans. '
                                'Pages can sit inside pages.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('notes-empty-new'),
                            onPressed: _newPage,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New page'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _OpenPage(
                    key: ValueKey(openPage.id),
                    page: openPage,
                    path: pathTo(byId, openPage.id),
                    project: projects
                        .where((project) => project.id == openPage.projectId)
                        .firstOrNull,
                    projects: projects,
                    edited: _edited(openPage.updatedAt, today),
                    onOpen: _open,
                    onAddInside: () => _newPage(parentId: openPage.id),
                    menu: _menuFor(openPage, pages, big: true),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.label, {this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 0, 2),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Expanded(child: Text(label, style: Ember.caption)),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Ember.ink2),
            const SizedBox(width: 8),
            Text(label, style: Ember.item.copyWith(color: Ember.ink2)),
          ],
        ),
      ),
    );
  }
}

/// One page in the tree: ▸ to open the pages inside, the icon and title;
/// on hover "•••" and "+" (add a page inside). A page can be dragged onto
/// another page to go inside it.
class _PageRow extends StatefulWidget {
  const _PageRow({
    super.key,
    required this.page,
    required this.depth,
    required this.open,
    required this.expanded,
    required this.hasChildren,
    required this.onOpen,
    this.onToggle,
    this.onAdd,
    this.onDrop,
    this.canDrop,
    this.menu,
  });

  final Note page;
  final int depth;
  final bool open;
  final bool expanded;
  final bool hasChildren;
  final VoidCallback onOpen;
  final VoidCallback? onToggle;
  final VoidCallback? onAdd;
  final void Function(Note dragged)? onDrop;
  final bool Function(Note dragged)? canDrop;
  final Widget? menu;

  @override
  State<_PageRow> createState() => _PageRowState();
}

class _PageRowState extends State<_PageRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final inTree = widget.onToggle != null;
    Widget row(bool dropping) => MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: dropping
            ? const Color(0x222B62D9)
            : widget.open
            ? Ember.tile
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: inTree ? Key('page-row-${page.id}') : null,
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onOpen,
          child: SizedBox(
            height: 30,
            child: Row(
              children: [
                SizedBox(width: 4.0 + 14 * widget.depth),
                if (inTree)
                  InkWell(
                    key: Key('page-expand-${page.id}'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: widget.onToggle,
                    child: SizedBox(
                      width: 20,
                      height: 22,
                      child: Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: widget.hasChildren || _hover
                            ? Ember.ink2
                            : Ember.line,
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 22,
                  child: page.icon == null
                      ? const Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: Ember.ink2,
                        )
                      : Text(page.icon!, style: const TextStyle(fontSize: 15)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pageTitle(page),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.item.copyWith(
                      color: page.title.trim().isEmpty
                          ? Ember.ink3
                          : widget.open
                          ? Ember.ink
                          : Ember.ink2,
                      fontWeight: widget.open
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (_hover && widget.menu != null) widget.menu!,
                if (_hover && widget.onAdd != null)
                  InkWell(
                    key: Key('page-add-${page.id}'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: widget.onAdd,
                    child: const Tooltip(
                      message: 'Add a page inside',
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(Icons.add, size: 16, color: Ember.ink2),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
    if (!inTree) return row(false);
    return DragTarget<Note>(
      onWillAcceptWithDetails: (details) =>
          details.data.id != page.id &&
          (widget.canDrop?.call(details.data) ?? false),
      onAcceptWithDetails: (details) => widget.onDrop?.call(details.data),
      builder: (context, candidates, _) => Draggable<Note>(
        data: page,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Ember.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Ember.line),
            ),
            child: Text(
              '${page.icon ?? '📄'}  ${pageTitle(page)}',
              style: Ember.item.copyWith(color: Ember.ink),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: row(false)),
        child: row(candidates.isNotEmpty),
      ),
    );
  }
}

/// "•••" on a page: favourite, move to, move to the Trash.
class _PageMenu extends StatelessWidget {
  const _PageMenu({
    required this.page,
    required this.onFavorite,
    required this.onMove,
    required this.onTrash,
    this.big = false,
  });

  final Note page;
  final VoidCallback onFavorite;
  final VoidCallback onMove;
  final VoidCallback onTrash;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final favorite = isFavorite(page);
    return PopupMenuButton<String>(
      key: Key(big ? 'page-more' : 'page-menu-${page.id}'),
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (action) => switch (action) {
        'favorite' => onFavorite(),
        'move' => onMove(),
        _ => onTrash(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('page-action-favorite'),
          value: 'favorite',
          child: Text(favorite ? 'Remove from Favorites' : 'Add to Favorites'),
        ),
        const PopupMenuItem(
          key: Key('page-action-move'),
          value: 'move',
          child: Text('Move to…'),
        ),
        const PopupMenuItem(
          key: Key('page-action-trash'),
          value: 'trash',
          child: Text('Move to Trash'),
        ),
      ],
      child: SizedBox(
        width: big ? 32 : 24,
        height: big ? 32 : 24,
        child: Icon(
          Icons.more_horiz_rounded,
          size: big ? 20 : 16,
          color: Ember.ink2,
        ),
      ),
    );
  }
}

/// The open page: breadcrumbs and buttons on top, the cover, the icon,
/// the title and the blocks. The title and blocks save by themselves a
/// moment after typing stops, and when the page closes.
class _OpenPage extends ConsumerStatefulWidget {
  const _OpenPage({
    super.key,
    required this.page,
    required this.path,
    required this.project,
    required this.projects,
    required this.edited,
    required this.onOpen,
    required this.onAddInside,
    required this.menu,
  });

  final Note page;
  final List<Note> path;
  final Project? project;
  final List<Project> projects;
  final String edited;
  final ValueChanged<String> onOpen;
  final VoidCallback onAddInside;
  final Widget menu;

  @override
  ConsumerState<_OpenPage> createState() => _OpenPageState();
}

class _OpenPageState extends ConsumerState<_OpenPage> {
  late final EditorState _editor = EditorState(
    document: documentOf(widget.page),
  );
  late final _title = TextEditingController(text: widget.page.title);
  late final _builders = noteBlockBuilders(_editor);
  late final _shortcuts = noteCharacterShortcuts();
  final _editorScroll = ScrollController();
  late final _scroller = EditorScrollController(
    editorState: _editor,
    scrollController: _editorScroll,
  );
  late final _repository = ref.read(captureRepositoryProvider);
  StreamSubscription<Object?>? _changes;
  Timer? _saveSoon;
  var _dirty = false;
  var _hoverTop = false;

  @override
  void initState() {
    super.initState();
    _changes = _editor.transactionStream.listen((_) => _changed());
  }

  void _changed() {
    _dirty = true;
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(milliseconds: 900), _save);
  }

  Future<void> _save() async {
    _saveSoon?.cancel();
    if (!_dirty) return;
    _dirty = false;
    try {
      await _repository.savePage(
        widget.page.id,
        title: _title.text,
        content: encodeDocument(_editor.document),
        body: plainTextOf(_editor.document),
      );
    } catch (error) {
      _dirty = true;
      if (mounted) showMessage(context, 'Could not save the page. ($error)');
    }
  }

  @override
  void dispose() {
    // Save what was typed before the page closes.
    if (_dirty) unawaited(_save());
    _saveSoon?.cancel();
    _changes?.cancel();
    _title.dispose();
    _scroller.dispose();
    _editorScroll.dispose();
    _editor.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  Future<void> _pickIcon() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Icon', style: Ember.h2),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final emoji in _emojis)
                InkWell(
                  key: Key('emoji-$emoji'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.pop(context, emoji),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('emoji-remove'),
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await _guard(
      () => _repository.setPageIcon(
        widget.page.id,
        picked.isEmpty ? null : picked,
      ),
    );
  }

  Future<void> _pickCover() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cover', style: Ember.h2),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _covers.entries)
              InkWell(
                key: Key('cover-${entry.key}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(context, entry.key),
                child: Container(
                  width: 64,
                  height: 40,
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (widget.page.cover != null)
            TextButton(
              key: const Key('cover-remove'),
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Remove'),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _guard(
      () => _repository.setPageCover(
        widget.page.id,
        picked.isEmpty ? null : picked,
      ),
    );
  }

  Future<void> _pickProject() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Link to a project', style: Ember.h2),
        children: [
          SimpleDialogOption(
            key: const Key('project-none'),
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('No project'),
          ),
          for (final project in widget.projects)
            SimpleDialogOption(
              key: Key('project-${project.id}'),
              onPressed: () => Navigator.pop(context, project.id),
              child: Text(project.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _guard(
      () => _repository.setPageProject(
        widget.page.id,
        picked.isEmpty ? null : picked,
      ),
    );
  }

  /// A click below the last block puts the cursor at its end, or adds an
  /// empty line after a block that has text or no text place.
  Future<void> _focusEnd() async {
    final last = _editor.document.root.children.lastOrNull;
    if (last == null || last.delta == null || last.delta!.isNotEmpty) {
      final path = last == null ? [0] : last.path.next;
      final transaction = _editor.transaction
        ..insertNode(path, paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: path));
      await _editor.apply(transaction);
      return;
    }
    _editor.selection = Selection.collapsed(
      Position(path: last.path, offset: last.delta!.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final cover = _covers[page.cover];
    final project = widget.project;
    final favorite = isFavorite(page);

    final header = MouseRegion(
      onEnter: (_) => setState(() => _hoverTop = true),
      onExit: (_) => setState(() => _hoverTop = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cover != null)
            Container(
              key: const Key('page-cover'),
              height: 150,
              color: cover,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(10),
              child: _hoverTop
                  ? SoftButton(
                      key: const Key('page-change-cover'),
                      label: 'Change cover',
                      onPressed: _pickCover,
                    )
                  : null,
            ),
          Padding(
            // Lines up with the text of the blocks below.
            padding: EdgeInsets.fromLTRB(90, cover == null ? 36 : 0, 32, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.icon != null)
                  Transform.translate(
                    offset: Offset(0, cover == null ? 0 : -34),
                    child: InkWell(
                      key: const Key('page-icon'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _pickIcon,
                      child: Text(
                        page.icon!,
                        style: const TextStyle(fontSize: 64, height: 1.15),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 30,
                  child: AnimatedOpacity(
                    opacity: _hoverTop ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Row(
                      children: [
                        if (page.icon == null)
                          _GhostButton(
                            key: const Key('page-add-icon'),
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Add icon',
                            onTap: _pickIcon,
                          ),
                        if (cover == null)
                          _GhostButton(
                            key: const Key('page-add-cover'),
                            icon: Icons.image_outlined,
                            label: 'Add cover',
                            onTap: _pickCover,
                          ),
                        if (project == null)
                          _GhostButton(
                            key: const Key('page-add-project'),
                            icon: Icons.folder_outlined,
                            label: 'Link project',
                            onTap: _pickProject,
                          ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  key: const Key('page-title'),
                  controller: _title,
                  onChanged: (_) => _changed(),
                  onSubmitted: (_) {
                    _save();
                    _editor.selection = Selection.collapsed(
                      Position(path: [0]),
                    );
                  },
                  style: Ember.text(
                    36,
                    44,
                    weight: 700,
                    color: Ember.ink,
                    letterSpacing: -0.02,
                  ),
                  decoration: InputDecoration(
                    hintText: untitled,
                    hintStyle: Ember.text(
                      36,
                      44,
                      weight: 700,
                      color: Ember.line,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                  ),
                ),
                if (project != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      key: const Key('page-project'),
                      onTap: _pickProject,
                      child: NameChip(
                        label: project.name,
                        swatch: ProjectColors.of(project.color),
                        icon: ItemIcons.of(project.icon),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumbs, when it was edited, add inside, favourite, "•••".
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.path.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('/', style: Ember.meta),
                          ),
                        InkWell(
                          key: Key('crumb-${widget.path[i].id}'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => widget.onOpen(widget.path[i].id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            child: Text(
                              [
                                ?widget.path[i].icon,
                                pageTitle(widget.path[i]),
                              ].join(' '),
                              style: Ember.meta.copyWith(
                                color: i == widget.path.length - 1
                                    ? Ember.ink
                                    : Ember.ink2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Text(widget.edited, style: Ember.caption),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('page-add-inside'),
                tooltip: 'Add a page inside',
                iconSize: 19,
                color: Ember.ink2,
                onPressed: widget.onAddInside,
                icon: const Icon(Icons.note_add_outlined),
              ),
              IconButton(
                key: const Key('page-favorite'),
                tooltip: favorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                iconSize: 19,
                color: favorite ? Ember.amber : Ember.ink2,
                onPressed: () => _guard(
                  () => _repository.setFavorite(page.id, favorite: !favorite),
                ),
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                ),
              ),
              widget.menu,
            ],
          ),
        ),
        Expanded(
          // The editor's own words (its link menu and such) load here.
          child: Localizations.override(
            context: context,
            delegates: const [AppFlowyEditorLocalizations.delegate],
            child: AppFlowyEditor(
              key: const Key('page-editor'),
              editorState: _editor,
              editorScrollController: _scroller,
              editorStyle: noteEditorStyle(),
              blockComponentBuilders: _builders,
              characterShortcutEvents: _shortcuts,
              commandShortcutEvents: standardCommandShortcutEvents,
              blockWrapper: (context, {required node, required child}) =>
                  noteBlockWrapper(_editor, context, node: node, child: child),
              header: header,
              footer: GestureDetector(
                key: const Key('page-below'),
                behavior: HitTestBehavior.opaque,
                onTap: _focusEnd,
                child: const SizedBox(height: 160),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A quiet button above the title: "Add icon", "Add cover".
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Ember.ink3),
            const SizedBox(width: 5),
            Text(label, style: Ember.meta.copyWith(color: Ember.ink3)),
          ],
        ),
      ),
    );
  }
}

/// The Trash: pages put there, to restore or delete for good.
class _TrashDialog extends ConsumerWidget {
  const _TrashDialog({required this.userId});

  final String userId;

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    Note page,
  ) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for good?'),
        content: Text(
          '"${pageTitle(page)}" and the pages inside it will be gone. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('trash-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref
        .read(captureRepositoryProvider)
        .deleteForever(page.id, userId: userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(notesProvider).value ?? const <Note>[];
    final trashed = trashedPages(pages);
    return AlertDialog(
      title: Text('Trash', style: Ember.h2),
      content: SizedBox(
        width: 420,
        child: trashed.isEmpty
            ? Text('The Trash is empty.', style: Ember.meta)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final page in trashed)
                      ListTile(
                        key: Key('trash-${page.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          page.icon ?? '📄',
                          style: const TextStyle(fontSize: 18),
                        ),
                        title: Text(pageTitle(page)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('trash-restore-${page.id}'),
                              tooltip: 'Restore',
                              onPressed: () => ref
                                  .read(captureRepositoryProvider)
                                  .restorePage(page.id, userId: userId),
                              icon: const Icon(Icons.restore_rounded, size: 19),
                            ),
                            IconButton(
                              key: Key('trash-delete-${page.id}'),
                              tooltip: 'Delete for good',
                              onPressed: () =>
                                  _deleteForever(context, ref, page),
                              icon: const Icon(
                                Icons.delete_forever_outlined,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          key: const Key('trash-close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
