/// The Notion-style block editor for note pages, built on appflowy_editor
/// (MPL-2.0, unmodified): Orbito's blocks (with Toggle, Callout and Code
/// added), the "/" menu, the ⋮⋮ handle to drag or change a block, and the
/// page content as JSON plus a plain-text copy.
library;

import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../ui/ember.dart';

// ------------------------------------------------------------- the content

/// The blocks of a page: its saved content, or (for a note made before
/// pages) its text as paragraphs, one per line.
Document documentOf(Note note) {
  final content = note.content;
  if (content != null && content.isNotEmpty) {
    try {
      return Document.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on Object {
      // Unreadable content falls back to the plain text below.
    }
  }
  final lines = note.body.isEmpty ? [''] : note.body.split('\n');
  return Document.blank()
    ..insert([0], [for (final line in lines) paragraphNode(text: line)]);
}

/// The blocks as the JSON text that is saved.
String encodeDocument(Document document) => jsonEncode(document.toJson());

/// The text of every block, one line each (for search and previews).
String plainTextOf(Document document) {
  final lines = <String>[];
  void walk(Node node) {
    final delta = node.delta;
    if (delta != null) lines.add(delta.toPlainText());
    node.children.forEach(walk);
  }

  document.root.children.forEach(walk);
  return lines.join('\n').trim();
}

// ------------------------------------------------------- Orbito's blocks

abstract final class NoteBlocks {
  static const toggle = 'toggle_list';
  static const callout = 'callout';
  static const code = 'code';

  /// On a toggle: true while its inside is hidden.
  static const collapsed = 'collapsed';
}

Node toggleNode() => Node(
  type: NoteBlocks.toggle,
  attributes: {'delta': Delta().toJson(), NoteBlocks.collapsed: false},
);

Node calloutNode() => Node(
  type: NoteBlocks.callout,
  attributes: {
    'delta': Delta().toJson(),
    blockComponentBackgroundColor: '0xFFF3F2EE',
  },
);

Node codeNode() => Node(
  type: NoteBlocks.code,
  attributes: {
    'delta': Delta().toJson(),
    blockComponentBackgroundColor: '0xFFEDEBE5',
  },
);

/// Where the text of a page is drawn: Orbito's font and ink. The cursor
/// is ink and the selection a soft blue (orange means "now").
EditorStyle noteEditorStyle() => EditorStyle.desktop(
  // Room on the left for the + and ⋮⋮ handles, as in Notion.
  padding: const EdgeInsets.fromLTRB(56, 0, 32, 0),
  cursorColor: Ember.ink,
  selectionColor: const Color(0x332B62D9),
  textStyleConfiguration: TextStyleConfiguration(
    text: Ember.text(15, 24, weight: 400, color: Ember.ink),
    code: TextStyle(
      fontFamily: 'Consolas',
      color: Ember.badInk,
      backgroundColor: Ember.neutral,
    ),
    href: const TextStyle(
      color: Color(0xFF2B62D9),
      decoration: TextDecoration.underline,
    ),
  ),
);

TextStyle _headingStyle(int level) => switch (level) {
  1 => Ember.text(30, 38, weight: 700, letterSpacing: -0.02),
  2 => Ember.text(23, 30, weight: 650),
  _ => Ember.text(18, 25, weight: 600),
};

/// The block builders, each with the ⋮⋮ handle on hover.
Map<String, BlockComponentBuilder> noteBlockBuilders(EditorState editor) {
  const plain = BlockComponentConfiguration();
  final builders = <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
      configuration: plain.copyWith(
        placeholderText: (_) => "Type '/' for blocks",
      ),
    ),
    HeadingBlockKeys.type: HeadingBlockComponentBuilder(
      configuration: plain.copyWith(
        placeholderText: (node) =>
            'Heading ${node.attributes[HeadingBlockKeys.level]}',
        padding: (_) => const EdgeInsets.only(top: 10, bottom: 2),
      ),
      textStyleBuilder: _headingStyle,
    ),
    TodoListBlockKeys.type: TodoListBlockComponentBuilder(
      configuration: plain.copyWith(placeholderText: (_) => 'To-do'),
    ),
    BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
      configuration: plain.copyWith(placeholderText: (_) => 'List'),
    ),
    NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
      configuration: plain.copyWith(placeholderText: (_) => 'List'),
    ),
    QuoteBlockKeys.type: QuoteBlockComponentBuilder(
      configuration: plain.copyWith(placeholderText: (_) => 'Quote'),
      iconBuilder: (context, node) => Container(
        width: 3,
        margin: const EdgeInsets.only(right: 12),
        color: Ember.ink,
      ),
    ),
    NoteBlocks.toggle: ToggleBlockComponentBuilder(
      configuration: plain.copyWith(placeholderText: (_) => 'Toggle'),
    ),
    NoteBlocks.callout: QuoteBlockComponentBuilder(
      configuration: plain.copyWith(
        placeholderText: (_) => 'Type something…',
        padding: (_) => const EdgeInsets.fromLTRB(12, 10, 12, 10),
      ),
      iconBuilder: (context, node) => const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Text('💡', style: TextStyle(fontSize: 17)),
      ),
    ),
    NoteBlocks.code: QuoteBlockComponentBuilder(
      configuration: plain.copyWith(
        placeholderText: (_) => 'Code',
        padding: (_) => const EdgeInsets.fromLTRB(14, 12, 14, 12),
        textStyle: (node, {textSpan}) => TextStyle(
          fontFamily: 'Consolas',
          fontSize: 13.5,
          height: 1.5,
          color: Ember.ink,
        ),
      ),
      iconBuilder: (context, node) => const SizedBox.shrink(),
    ),
  };
  for (final entry in builders.entries) {
    if (entry.key == PageBlockKeys.type) continue;
    entry.value
      ..showActions = ((_) => true)
      ..actionBuilder = (context, state) =>
          _BlockHandle(node: context.node, editor: editor, state: state);
  }
  return builders;
}

/// The block types the "/" menu works in.
const noteSlashTypes = {
  ParagraphBlockKeys.type,
  HeadingBlockKeys.type,
  TodoListBlockKeys.type,
  BulletedListBlockKeys.type,
  NumberedListBlockKeys.type,
  QuoteBlockKeys.type,
  NoteBlocks.toggle,
  NoteBlocks.callout,
};

SelectionMenuItem _menuItem(
  String name,
  IconData icon,
  List<String> keywords,
  Node Function() make,
) => SelectionMenuItem.node(
  getName: () => name,
  iconData: icon,
  keywords: keywords,
  nodeBuilder: (_, _) => make(),
  replace: (_, node) => node.delta?.isEmpty ?? false,
);

/// The "/" menu, in Notion's order.
final noteSlashItems = <SelectionMenuItem>[
  _menuItem('Text', Icons.notes_rounded, ['text', 'paragraph'], paragraphNode),
  _menuItem('Heading 1', Icons.title_rounded, [
    'heading 1',
    'h1',
    'title',
  ], () => headingNode(level: 1)),
  _menuItem('Heading 2', Icons.title_rounded, [
    'heading 2',
    'h2',
  ], () => headingNode(level: 2)),
  _menuItem('Heading 3', Icons.title_rounded, [
    'heading 3',
    'h3',
  ], () => headingNode(level: 3)),
  _menuItem('To-do list', Icons.check_box_outlined, [
    'to-do',
    'todo',
    'checkbox',
    'task',
  ], () => todoListNode(checked: false)),
  _menuItem('Bulleted list', Icons.format_list_bulleted_rounded, [
    'bulleted list',
    'bullet',
    'list',
  ], bulletedListNode),
  _menuItem('Numbered list', Icons.format_list_numbered_rounded, [
    'numbered list',
    'number',
    'list',
  ], numberedListNode),
  _menuItem('Toggle list', Icons.arrow_right_rounded, [
    'toggle',
    'collapse',
  ], toggleNode),
  _menuItem('Quote', Icons.format_quote_rounded, [
    'quote',
    'citation',
  ], quoteNode),
  _menuItem('Divider', Icons.horizontal_rule_rounded, [
    'divider',
    'line',
    'separator',
  ], dividerNode),
  _menuItem('Callout', Icons.lightbulb_outline_rounded, [
    'callout',
    'note',
    'tip',
  ], calloutNode),
  _menuItem('Code', Icons.code_rounded, ['code', 'snippet'], codeNode),
];

/// The "/" menu in Orbito's colours.
SelectionMenuStyle get noteMenuStyle => SelectionMenuStyle(
  selectionMenuBackgroundColor: Ember.surface,
  selectionMenuItemTextColor: Ember.ink,
  selectionMenuItemIconColor: Ember.ink2,
  selectionMenuItemSelectedTextColor: Ember.ink,
  selectionMenuItemSelectedIconColor: Ember.ink,
  selectionMenuItemSelectedColor: Ember.tile,
  selectionMenuUnselectedLabelColor: Ember.ink2,
  selectionMenuDividerColor: Ember.line,
  selectionMenuLinkBorderColor: Ember.line,
  selectionMenuInvalidLinkColor: Color(0xFFC8242F),
  selectionMenuButtonColor: Ember.tile,
  selectionMenuButtonTextColor: Ember.ink,
  selectionMenuButtonIconColor: Ember.ink,
  selectionMenuButtonBorderColor: Ember.line,
  selectionMenuTabIndicatorColor: Ember.ink,
);

/// Typing shortcuts: the standard ones with Orbito's "/" menu.
List<CharacterShortcutEvent> noteCharacterShortcuts() => [
  for (final event in standardCharacterShortcutEvents)
    if (event.key != slashCommand.key) event,
  customSlashCommand(
    noteSlashItems,
    style: noteMenuStyle,
    supportSlashMenuNodeTypes: noteSlashTypes,
  ),
];

// ------------------------------------------------------------- moving

/// Moves [dragged] next to [target]: above it, or below it with [below].
/// Nothing happens when [target] is [dragged] or inside it.
Future<void> moveBlock(
  EditorState editor,
  Node dragged,
  Node target, {
  required bool below,
}) async {
  final from = dragged.path;
  final to = target.path;
  if (_startsWith(to, from)) return; // onto itself or into itself
  // Paths are as they are now; the transaction shifts them for the
  // removal of the block itself.
  final destination = below ? to.next : to;
  final transaction = editor.transaction
    ..deleteNode(dragged)
    ..insertNode(destination, dragged.deepCopy());
  await editor.apply(transaction);
}

bool _startsWith(List<int> path, List<int> prefix) {
  if (prefix.length > path.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (path[i] != prefix[i]) return false;
  }
  return true;
}

/// Wraps every block so a dragged block can be dropped above or below it;
/// a thin line shows where it will land.
Widget noteBlockWrapper(
  EditorState editor,
  BuildContext context, {
  required Node node,
  required Widget child,
}) {
  if (node.type == PageBlockKeys.type) return child;
  return _DropZone(editor: editor, node: node, child: child);
}

class _DropZone extends StatefulWidget {
  const _DropZone({
    required this.editor,
    required this.node,
    required this.child,
  });

  final EditorState editor;
  final Node node;
  final Widget child;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool? _below;

  bool _isBelow(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return true;
    return box.globalToLocal(global).dy > box.size.height / 2;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Node>(
      onWillAcceptWithDetails: (details) =>
          details.data != widget.node &&
          !_startsWith(widget.node.path, details.data.path),
      onMove: (details) {
        final below = _isBelow(details.offset + const Offset(0, 12));
        if (below != _below) setState(() => _below = below);
      },
      onLeave: (_) => setState(() => _below = null),
      onAcceptWithDetails: (details) {
        final below = _below ?? true;
        setState(() => _below = null);
        moveBlock(widget.editor, details.data, widget.node, below: below);
      },
      builder: (context, candidates, _) {
        final showing = candidates.isNotEmpty && _below != null;
        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: showing && !_below! ? Ember.ink3 : Colors.transparent,
                width: 2,
              ),
              bottom: BorderSide(
                color: showing && _below! ? Ember.ink3 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// The "+" and ⋮⋮ shown left of a block on hover: "+" adds a block below;
/// ⋮⋮ drags the block, or opens its menu.
class _BlockHandle extends StatelessWidget {
  const _BlockHandle({
    required this.node,
    required this.editor,
    required this.state,
  });

  final Node node;
  final EditorState editor;
  final BlockComponentActionState state;

  Future<void> _addBelow() async {
    final path = node.path.next;
    final transaction = editor.transaction
      ..insertNode(path, paragraphNode())
      ..afterSelection = Selection.collapsed(Position(path: path));
    await editor.apply(transaction);
  }

  Future<void> _run(String action) async {
    final transaction = editor.transaction;
    switch (action) {
      case 'delete':
        transaction.deleteNode(node);
      case 'duplicate':
        transaction.insertNode(node.path.next, node.deepCopy());
      case 'up':
        final previous = node.previous;
        if (previous == null) return;
        await moveBlock(editor, node, previous, below: false);
        return;
      case 'down':
        final next = node.next;
        if (next == null) return;
        await moveBlock(editor, node, next, below: true);
        return;
      default:
        final make = _turnInto[action];
        if (make == null) return;
        final replacement = make()
          ..updateAttributes({'delta': (node.delta ?? Delta()).toJson()});
        transaction
          ..insertNode(node.path.next, replacement)
          ..deleteNode(node);
    }
    await editor.apply(transaction);
  }

  static final _turnInto = <String, Node Function()>{
    'Text': paragraphNode,
    'Heading 1': () => headingNode(level: 1),
    'Heading 2': () => headingNode(level: 2),
    'Heading 3': () => headingNode(level: 3),
    'To-do list': () => todoListNode(checked: false),
    'Bulleted list': bulletedListNode,
    'Numbered list': numberedListNode,
    'Toggle list': toggleNode,
    'Quote': quoteNode,
    'Callout': calloutNode,
    'Code': codeNode,
  };

  @override
  Widget build(BuildContext context) {
    final preview = node.delta?.toPlainText() ?? '';
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HandleButton(
            tooltip: 'Add a block below',
            icon: Icons.add_rounded,
            onTap: _addBelow,
          ),
          Draggable<Node>(
            data: node,
            onDragStarted: () => state.alwaysShowActions = true,
            onDragEnd: (_) => state.alwaysShowActions = false,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.7,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Ember.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Ember.line),
                  ),
                  child: Text(
                    preview.isEmpty ? node.type : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ember.text(14, 20, weight: 400, color: Ember.ink),
                  ),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Drag to move · click for options',
              padding: EdgeInsets.zero,
              onOpened: () => state.alwaysShowActions = true,
              onCanceled: () => state.alwaysShowActions = false,
              onSelected: (action) {
                state.alwaysShowActions = false;
                _run(action);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
                const PopupMenuItem(value: 'up', child: Text('Move up')),
                const PopupMenuItem(value: 'down', child: Text('Move down')),
                const PopupMenuDivider(),
                for (final name in _turnInto.keys)
                  PopupMenuItem(value: name, child: Text('Turn into $name')),
              ],
              child: const _HandleIcon(Icons.drag_indicator_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandleButton extends StatelessWidget {
  const _HandleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: _HandleIcon(icon),
      ),
    );
  }
}

class _HandleIcon extends StatelessWidget {
  const _HandleIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 24,
    child: Icon(icon, size: 18, color: Ember.ink3),
  );
}

// --------------------------------------------------------------- toggle

/// A toggle list: a line with a ▸ that shows or hides the blocks inside
/// it (the inside is made with Tab, as for list items).
class ToggleBlockComponentBuilder extends BlockComponentBuilder {
  ToggleBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ToggleBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class ToggleBlockComponentWidget extends BlockComponentStatefulWidget {
  const ToggleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<ToggleBlockComponentWidget> createState() =>
      _ToggleBlockComponentWidgetState();
}

class _ToggleBlockComponentWidgetState extends State<ToggleBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: NoteBlocks.toggle,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool get _collapsed => node.attributes[NoteBlocks.collapsed] == true;

  Future<void> _flip() async {
    final transaction = editorState.transaction
      ..updateNode(node, {NoteBlocks.collapsed: !_collapsed});
    await editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed || node.children.isEmpty) {
      return Padding(
        padding: configuration.margin(node),
        child: buildComponent(context),
      );
    }
    return super.build(context);
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          GestureDetector(
            key: Key('toggle-${node.id}'),
            onTap: _flip,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 24,
              height: 24,
              child: AnimatedRotation(
                turns: _collapsed ? 0 : 0.25,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.arrow_right_rounded,
                  size: 22,
                  color: Ember.ink,
                ),
              ),
            ),
          ),
          Flexible(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: placeholderText,
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    child = Container(
      decoration: withBackgroundColor ? decoration : null,
      key: blockComponentKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }
}
