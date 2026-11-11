import 'package:flutter/material.dart';

import 'ember.dart';

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
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
              gap: 18,
              children: rail!,
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

/// A soft grey tile. With [onTap] it is a button.
class Tile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: selected
          ? const BorderSide(color: Ember.ink, width: 1.5)
          : BorderSide.none,
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
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

/// A small coloured label with a dot, used for project names.
class NameChip extends StatelessWidget {
  const NameChip({super.key, required this.label, required this.swatch});

  final String label;
  final Swatch swatch;

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
          ColorDot(swatch.dot, size: 6),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: percent.clamp(0, 100) / 100,
        minHeight: 6,
        backgroundColor: Ember.line,
        color: Ember.ink,
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

/// Asks the user to confirm with [confirmLabel]. Returns true when they do.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep'),
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

/// Shows a short message at the bottom of the window.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
