import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The life areas the app suggests, each with one line that explains it.
const suggestedAreas = <(String name, String hint)>[
  ('Health', 'Body, movement, food, sleep'),
  ('Mind', 'Calm, focus, mental health'),
  ('Career', 'Work, skills, direction'),
  ('Financial Freedom', 'Income, saving, debt'),
  ('Family', 'The people at home'),
  ('Relationships', 'Partner, friends, community'),
  ('Learning', 'Study, reading, new skills'),
  ('Spirituality', 'Meaning, faith, values'),
  ('Fun', 'Hobbies, play, rest'),
  ('Environment', 'Home, order, surroundings'),
];

/// The colour for the n-th new life area. Grey is kept for "no colour".
String areaColorAt(int index) {
  final names = AreaColors.all.keys
      .where((name) => name != AreaColors.fallback)
      .toList();
  return names[index % names.length];
}

class SetupSkipped extends Notifier<bool> {
  @override
  bool build() => false;

  void skip() => state = true;
}

/// True once the user chose "Skip for now". It lasts until the app closes.
final setupSkippedProvider = NotifierProvider<SetupSkipped, bool>(
  SetupSkipped.new,
);

/// First-run setup: suggests life areas the user can accept or change.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _chosen = <String>{};
  bool _saving = false;

  Future<void> _addChosen() async {
    final userId = ref.read(userIdProvider);
    if (userId == null || _chosen.isEmpty) return;
    setState(() => _saving = true);
    final plan = ref.read(planRepositoryProvider);
    try {
      var index = 0;
      for (final (name, _) in suggestedAreas) {
        if (!_chosen.contains(name)) continue;
        await plan.addArea(
          userId: userId,
          name: name,
          color: areaColorAt(index++),
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, 'Could not save the areas. Try again. ($error)');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = ref.watch(firstSyncDoneProvider);
    return PageLayout(
      main: [
        if (!downloaded)
          Tile(
            key: const Key('setup-waiting'),
            color: Ember.neutral,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              'Still checking the server for your data. If you already use '
              'Orbito on another device, wait a moment: your areas will '
              'appear by themselves.',
              style: Ember.meta,
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which parts of your life do you want to look after?',
              style: Ember.h1.copyWith(color: Ember.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'Pick the areas that matter now. These are suggestions: you '
              'can rename, delete or add your own at any time.',
              style: Ember.text(14, 20, weight: 400, color: Ember.ink2),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (name, hint) in suggestedAreas)
              SizedBox(
                width: 210,
                height: 100,
                child: Semantics(
                  button: true,
                  selected: _chosen.contains(name),
                  child: Tile(
                    key: Key('suggest-$name'),
                    selected: _chosen.contains(name),
                    color: _chosen.contains(name) ? Ember.white : Ember.tile,
                    padding: const EdgeInsets.all(14),
                    onTap: _saving
                        ? null
                        : () => setState(() {
                            if (!_chosen.remove(name)) _chosen.add(name);
                          }),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ember.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ember.meta,
                        ),
                      ],
                    ),
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
        Row(
          children: [
            FilledButton(
              key: const Key('setup-add'),
              onPressed: _chosen.isEmpty || _saving ? null : _addChosen,
              child: Text(
                _chosen.isEmpty
                    ? 'Pick at least one area'
                    : 'Add ${countOf(_chosen.length, 'area')}',
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('setup-skip'),
              onPressed: _saving
                  ? null
                  : () => ref.read(setupSkippedProvider.notifier).skip(),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ],
    );
  }
}
