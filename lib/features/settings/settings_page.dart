import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/today.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// Saves the user's choice of Today sections. The choice is synced, so
/// every device shows the same Today page.
Future<void> saveTodaySections(
  BuildContext context,
  WidgetRef ref,
  List<TodaySection> sections,
) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return;
  try {
    await ref
        .read(captureRepositoryProvider)
        .saveTodaySections(userId: userId, sections: writeSections(sections));
  } catch (error) {
    if (context.mounted) showMessage(context, 'Could not save. ($error)');
  }
}

/// Settings: which sections the Today page shows, and in which order.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = readSections(ref.watch(todaySectionsProvider).value);
    void save(List<TodaySection> sections) =>
        saveTodaySections(context, ref, sections);

    Widget column(TodayColumn which, String title) {
      // The sections that are on, in their order, then the ones that are off.
      final shown = on.where((s) => s.column == which).toList();
      final hidden = TodaySection.values
          .where((s) => s.column == which && !on.contains(s))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Ember.h3),
          const SizedBox(height: 10),
          for (final section in [...shown, ...hidden])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tile(
                key: Key('section-${section.name}'),
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.label,
                            style: Ember.item.copyWith(
                              color: on.contains(section)
                                  ? Ember.ink
                                  : Ember.ink3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(section.description, style: Ember.meta),
                        ],
                      ),
                    ),
                    if (on.contains(section)) ...[
                      IconButton(
                        key: Key('section-up-${section.name}'),
                        tooltip: 'Move up',
                        iconSize: 18,
                        color: Ember.ink2,
                        onPressed: shown.first == section
                            ? null
                            : () => save(moveSection(on, section, -1)),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        key: Key('section-down-${section.name}'),
                        tooltip: 'Move down',
                        iconSize: 18,
                        color: Ember.ink2,
                        onPressed: shown.last == section
                            ? null
                            : () => save(moveSection(on, section, 1)),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                    Switch(
                      key: Key('section-switch-${section.name}'),
                      value: on.contains(section),
                      activeTrackColor: Ember.ink,
                      onChanged: (_) => save(toggleSection(on, section)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return PageLayout(
      main: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Your choices are kept on every device you sign in on.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.wb_sunny_outlined,
              title: 'Today page',
            ),
            Text(
              'Switch sections on or off and change their order. Changes '
              'apply at once.',
              style: Ember.meta,
            ),
            const SizedBox(height: 16),
            column(TodayColumn.main, 'Main panel'),
            const SizedBox(height: 18),
            column(TodayColumn.side, 'Right panel'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SoftButton(
                key: const Key('sections-reset'),
                icon: Icons.restart_alt,
                label: 'Back to the default sections',
                onPressed: () => save(defaultSections),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
