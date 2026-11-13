import 'package:flutter/material.dart';

import '../data/repositories/plan_repository.dart' show LinkedItems;
import 'ember.dart';
import 'motion.dart';

/// A paper-coloured panel with rounded corners. Its content scrolls.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(28, 26, 28, 28),
    this.gap = 22,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: Ember.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: Ember.item.copyWith(color: Ember.ink),
        child: SingleChildScrollView(
          padding: padding,
          // When content is added or removed, the panel grows or shrinks
          // softly instead of jumping. AnimatedSize cannot run with a zero
          // duration, so with less motion the column is used as it is.
          child: Motion.reduced(context)
              ? column
              : AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.soft,
                  alignment: Alignment.topCenter,
                  child: column,
                ),
        ),
      ),
    );
  }
}

/// A page: the main panel and, on the right, a narrower panel for details
/// or a form.
class PageLayout extends StatelessWidget {
  const PageLayout({super.key, required this.main, this.rail});

  final List<Widget> main;
  final List<Widget>? rail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: Panel(children: main)),
        if (rail != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 340,
            child: Panel(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                // A new form or detail (another key) cross-fades in.
                SoftSwitcher(
                  child: Column(
                    key: ValueKey(
                      Object.hashAll(
                        rail!.map((child) => child.key ?? child.runtimeType),
                      ),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rail!.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        rail![i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The big page title with one line of grey text under it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Ember.h1.copyWith(color: Ember.ink)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Ember.date),
        ],
      ],
    );
  }
}

/// A soft grey tile. With [onTap] it is a button: it darkens a little under
/// the pointer and gives softly when pressed. A new tile fades in.
class Tile extends StatefulWidget {
  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.color = Ember.tile,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final Color color;
  final EdgeInsets padding;

  @override
  State<Tile> createState() => _TileState();
}

class _TileState extends State<Tile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final color = tappable && _hover
        ? Color.lerp(widget.color, Ember.ink, 0.035)!
        : widget.color;
    return Appear(
      child: Pressable(
        enabled: tappable,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.soft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected ? Ember.ink : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHover: tappable
                  ? (hover) => setState(() => _hover = hover)
                  : null,
              hoverColor: Colors.transparent,
              child: Padding(
                // The border is always there (clear when not selected), so
                // the content does not move when a tile is selected.
                padding: widget.padding - const EdgeInsets.all(1.5),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title with an icon, and something small on the right (a
/// legend or a hint), as in the design's `.sh` row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Ember.ink),
              const SizedBox(width: 8),
              Text(title, style: Ember.h2),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lays tiles out in equal columns, each at least [minWidth] wide, as in
/// the design's `.grid.s`.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minWidth = 160});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + gap) / (minWidth + gap)).floor();
        final columns = fit.clamp(1, children.length);
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final cells = children.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: i < cells.length ? cells[i] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// A number tile: a small label, a big value, and a line under it.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.below,
    this.valueSize = 24,
  });

  final String label;
  final String value;
  final String? detail;

  /// Shown under the value instead of (or before) [detail], for example a
  /// progress bar.
  final Widget? below;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Tile(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ember.meta),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ember.stat.copyWith(
              color: Ember.ink,
              fontSize: valueSize,
              height: (valueSize + 5) / valueSize,
            ),
          ),
          if (below != null) ...[const SizedBox(height: 10), below!],
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!, style: Ember.meta),
          ],
        ],
      ),
    );
  }
}

/// A row of buttons where one is chosen, as in the design's `.seg`. The
/// chosen one slides softly to its new place.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = false,
  });

  final String keyPrefix;
  final T value;

  /// Each option: its value and its label.
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Stretch to the full width, each option the same width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget option(T option, String label) {
      final chosen = option == value;
      final button = Semantics(
        button: true,
        selected: chosen,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.soft,
          decoration: BoxDecoration(
            color: chosen ? Ember.white : Ember.tile.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('$keyPrefix-$option'),
              onTap: () => onChanged(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Ember.text(
                    12,
                    15,
                    color: chosen ? Ember.ink : Ember.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: button) : button;
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Ember.tile,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            option(options[i].$1, options[i].$2),
          ],
        ],
      ),
    );
  }
}

/// The tile shown when a list is empty.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Tile(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          Text(title, style: Ember.h3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: Ember.meta, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The mark of a life area: its icon in its colour, or a coloured dot when
/// the area has no icon.
class AreaMark extends StatelessWidget {
  const AreaMark({
    super.key,
    required this.color,
    required this.icon,
    this.size = 16,
  });

  /// A colour name from `AreaColors`.
  final String color;

  /// An icon name from `ItemIcons`, or null for the dot.
  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final swatch = AreaColors.of(color);
    final data = ItemIcons.all[icon];
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: data == null
            ? ColorDot(swatch.dot, size: size * 0.6)
            : Icon(data, size: size, color: swatch.dot),
      ),
    );
  }
}

/// A small coloured label with a dot, used for project and goal names.
/// With an [icon], the icon replaces the dot.
class NameChip extends StatelessWidget {
  const NameChip({
    super.key,
    required this.label,
    required this.swatch,
    this.icon,
  });

  final String label;
  final Swatch swatch;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: swatch.soft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            ColorDot(swatch.dot, size: 6)
          else
            Icon(icon, size: 13, color: swatch.text),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(11, 13, color: swatch.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label without a dot.
class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.background = Ember.neutral,
    this.foreground = Ember.ink2,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Ember.text(11, 13, color: foreground)),
    );
  }
}

/// The round "complete" button in front of a task. The border shows the
/// priority: orange for high, amber for medium.
class TaskRing extends StatelessWidget {
  const TaskRing({
    super.key,
    required this.done,
    required this.priority,
    required this.onTap,
    required this.label,
  });

  final bool done;
  final String priority;
  final VoidCallback onTap;

  /// Read by screen readers, for example "Complete Buy shoes".
  final String label;

  @override
  Widget build(BuildContext context) {
    final border = done
        ? Ember.ink
        : switch (priority) {
            'high' => Ember.now,
            'medium' => Ember.amber,
            _ => Ember.ring,
          };
    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          // Ticking fills the ring softly and the check grows into place.
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            curve: Motion.soft,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Ember.ink : Colors.transparent,
              border: Border.all(color: border, width: 1.6),
            ),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: Motion.of(context, Motion.base),
              curve: Motion.settle,
              child: const Icon(Icons.check, size: 12, color: Ember.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small grey label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Ember.meta),
    );
  }
}

/// A thin progress bar from 0 to 100.
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.percent, {super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    // The bar flows to its new length instead of jumping.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: percent.clamp(0, 100) / 100),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.soft,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: Ember.line,
          color: Ember.ink,
        ),
      ),
    );
  }
}

/// A row of round colour buttons. One is selected.
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, Swatch> colors;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final MapEntry(key: name, value: swatch) in colors.entries)
          Semantics(
            button: true,
            selected: name == selected,
            label: capitalize(name),
            child: Tooltip(
              message: capitalize(name),
              child: InkWell(
                key: Key('color-$name'),
                customBorder: const CircleBorder(),
                onTap: () => onChanged(name),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: name == selected ? Ember.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ColorDot(swatch.dot, size: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A grid of icon buttons. One is selected. [swatch] colours the selected
/// one, so the user sees the icon as it will look.
///
/// With [allowNone], the first button is a plain dot meaning "no icon"; it
/// is selected, and reported, as an empty name.
class IconPicker extends StatelessWidget {
  const IconPicker({
    super.key,
    required this.icons,
    required this.selected,
    required this.swatch,
    required this.onChanged,
    this.allowNone = false,
  });

  final Map<String, IconData> icons;
  final String selected;
  final Swatch swatch;
  final ValueChanged<String> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (allowNone)
          Semantics(
            button: true,
            selected: selected.isEmpty,
            label: 'No icon',
            child: Tooltip(
              message: 'No icon',
              child: Material(
                color: selected.isEmpty ? swatch.soft : Ember.tile,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: selected.isEmpty
                      ? const BorderSide(color: Ember.ink, width: 1.5)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('icon-none'),
                  onTap: () => onChanged(''),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: ColorDot(swatch.dot, size: 8)),
                  ),
                ),
              ),
            ),
          ),
        for (final MapEntry(key: name, value: icon) in icons.entries)
          Semantics(
            button: true,
            selected: name == selected,
            label: '${capitalize(name)} icon',
            child: Tooltip(
              message: capitalize(name),
              child: Material(
                color: name == selected ? swatch.soft : Ember.tile,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: name == selected
                      ? const BorderSide(color: Ember.ink, width: 1.5)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('icon-$name'),
                  onTap: () => onChanged(name),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      icon,
                      size: 17,
                      color: name == selected ? swatch.text : Ember.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Asks the user to confirm with [confirmLabel]. Returns true when they do.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks what to do with linked items before a delete. Returns null when the
/// user cancels, so nothing is deleted.
Future<LinkedItems?> askAboutLinkedItems(
  BuildContext context, {
  required String title,
  required String message,
  required String keepLabel,
  required String deleteLabel,
}) {
  return showDialog<LinkedItems>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          key: const Key('linked-delete'),
          onPressed: () => Navigator.of(context).pop(LinkedItems.delete),
          child: Text(deleteLabel),
        ),
        FilledButton(
          key: const Key('linked-keep'),
          onPressed: () => Navigator.of(context).pop(LinkedItems.keep),
          child: Text(keepLabel),
        ),
      ],
    ),
  );
}

/// `1 goal`, `2 goals`.
String countOf(int count, String singular, [String? plural]) =>
    count == 1 ? '1 $singular' : '$count ${plural ?? '${singular}s'}';

/// Shows a short message at the bottom of the window.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
