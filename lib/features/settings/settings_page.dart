import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme_mode.dart';
import '../../domain/sleep.dart' show formatTime, minutesOf, timeOf;
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

/// Saves the usual wake time and bedtime (`HH:MM`). Synced like the Today
/// sections.
Future<void> saveDayTimes(
  BuildContext context,
  WidgetRef ref, {
  required String wake,
  required String bed,
}) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return;
  try {
    await ref
        .read(captureRepositoryProvider)
        .saveDayTimes(userId: userId, wake: wake, bed: bed);
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

    final times = ref.watch(dayTimesProvider).value;
    final wake = times?.wake ?? '07:00';
    final bed = times?.bed ?? '23:00';

    Future<void> pick({required bool isWake}) async {
      final current = minutesOf(isWake ? wake : bed) ?? 0;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        helpText: isWake ? 'Wake up time' : 'Bedtime',
      );
      if (picked == null || !context.mounted) return;
      final value = timeOf(picked.hour * 60 + picked.minute);
      await saveDayTimes(
        context,
        ref,
        wake: isWake ? value : wake,
        bed: isWake ? bed : value,
      );
    }

    Widget timeRow(String key, String label, String value, bool isWake) => Tile(
      key: Key(key),
      onTap: () => pick(isWake: isWake),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Ember.item)),
          Text(formatTime(value), style: Ember.item.copyWith(color: Ember.ink)),
          const SizedBox(width: 6),
          Icon(Icons.edit_outlined, size: 14, color: Ember.ink2),
        ],
      ),
    );

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
            const SectionHeader(icon: Icons.contrast_rounded, title: 'Look'),
            Tile(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dark mode', style: Ember.item),
                        const SizedBox(height: 2),
                        Text(
                          'Kept on this device only. The moon in the top bar '
                          'switches it too.',
                          style: Ember.meta,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('setting-dark'),
                    value: ref.watch(darkModeProvider),
                    onChanged: (dark) =>
                        ref.read(darkModeProvider.notifier).set(dark),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.bedtime_outlined,
              title: 'Your day',
            ),
            Text(
              'The day bar on Today starts when you wake up. A red dot marks '
              'your bedtime, which is 100%. If you stay up later, the bar '
              'keeps running: 110%, 120% and so on.',
              style: Ember.meta,
            ),
            const SizedBox(height: 12),
            timeRow('setting-wake', 'Wake up time', wake, true),
            const SizedBox(height: 6),
            timeRow('setting-bed', 'Bedtime', bed, false),
          ],
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
