import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/launcher.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import '../focus/focus_page.dart' show startFocus;

/// Example lines shown while the box is empty (from the prototype).
const _examples = [
  (
    'task call bank tomorrow 10am #work high',
    'Task with date, time, project, priority',
  ),
  ('meditated', 'Marks a habit done'),
  ('slept 11 to 6:30', 'Logs last night'),
  ('focus write the plan', 'Starts the focus timer on a task'),
  ('note meeting ideas', 'Keeps a note in the Inbox'),
  ('anything else', 'Goes to the Inbox, nothing is lost'),
];

/// Opens the Quick Launcher. [onFocus] is called after a focus session was
/// started from it, so the app can show focus mode.
Future<void> showQuickLauncher(
  BuildContext context, {
  required VoidCallback onFocus,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close the Quick Launcher',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Motion.of(context, Motion.base),
    pageBuilder: (context, _, _) => _QuickLauncher(onFocus: onFocus),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.soft);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class _QuickLauncher extends ConsumerStatefulWidget {
  const _QuickLauncher({required this.onFocus});

  final VoidCallback onFocus;

  @override
  ConsumerState<_QuickLauncher> createState() => _QuickLauncherState();
}

class _QuickLauncherState extends ConsumerState<_QuickLauncher> {
  final _line = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _line.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  ParsedLine? _parsed() => parseLine(
    _line.text,
    today: dayKey(ref.read(clockProvider)()),
    habits: ref.read(habitsProvider).value ?? const [],
    projects: ref.read(projectsProvider).value ?? const [],
    tasks: ref.read(tasksProvider).value ?? const [],
  );

  /// Does what the line says. The dialog closes only when it worked, so a
  /// line is never lost.
  Future<void> _run() async {
    final line = _parsed();
    final userId = ref.read(userIdProvider);
    if (line == null || userId == null || _busy) return;
    setState(() => _busy = true);
    final today = dayKey(ref.read(clockProvider)());
    String done;
    try {
      switch (line) {
        case TaskLine():
          final tasks = ref.read(taskRepositoryProvider);
          final id = await tasks.addTask(
            userId: userId,
            title: line.title,
            projectId: line.projectId,
            dueDate: line.dueDate,
            priority: line.priority,
          );
          if (line.notes != null) {
            await tasks.updateTask(
              id,
              title: line.title,
              projectId: line.projectId,
              dueDate: line.dueDate,
              priority: line.priority,
              notes: line.notes,
            );
          }
          final due = line.dueDate;
          done = due == null
              ? 'Task added.'
              : 'Task added for '
                    '${formatRelativeDay(due, today: today).toLowerCase()}.';
        case HabitLine():
          await ref
              .read(habitRepositoryProvider)
              .setMark(
                userId: userId,
                habitId: line.habit.id,
                day: today,
                status: HabitMark.done,
              );
          done = '${line.habit.name} marked done.';
        case SleepLine():
          await ref
              .read(sleepRepositoryProvider)
              .saveNight(
                userId: userId,
                day: today,
                bedTime: line.bedTime,
                wakeTime: line.wakeTime,
              );
          done = 'Last night saved.';
        case FocusLine():
          if (!mounted) return;
          await startFocus(context, ref, taskId: line.task.id);
          if (!mounted) return;
          Navigator.of(context).pop();
          widget.onFocus();
          return;
        case NoteLine():
          await ref
              .read(captureRepositoryProvider)
              .addToInbox(
                userId: userId,
                text: line.text,
                kind: InboxKind.note,
              );
          done = 'Note kept in the Inbox.';
        case InboxLine():
          await ref
              .read(captureRepositoryProvider)
              .addToInbox(userId: userId, text: line.text);
          done = 'Captured to the Inbox.';
      }
    } catch (error) {
      // The line stays in the box, so nothing is lost.
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, 'Could not save. Try again. ($error)');
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final line = _parsed();
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const Key('launcher'),
          width: 620,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Ember.paper,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(context).pop(),
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Ember.ink2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('launcher-line'),
                          controller: _line,
                          autofocus: true,
                          onSubmitted: (_) => _run(),
                          style: Ember.text(
                            15,
                            20,
                            weight: 400,
                            color: Ember.ink,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a task, a habit, a night of sleep…',
                            filled: false,
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const Kbd('Esc'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: line == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Try', style: Ember.caption),
                            const SizedBox(height: 8),
                            for (final (example, what) in _examples)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _line.text = example,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          example,
                                          style: Ember.item.copyWith(
                                            color: Ember.ink,
                                          ),
                                        ),
                                      ),
                                      Text(what, style: Ember.meta),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Will create', style: Ember.caption),
                            const SizedBox(height: 8),
                            Wrap(
                              key: const Key('launcher-preview'),
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (label, tone) in line.chips)
                                  _ToneChip(label: label, tone: tone),
                              ],
                            ),
                          ],
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                  child: Row(
                    children: [
                      const Kbd('Enter'),
                      const SizedBox(width: 6),
                      Text('Do it', style: Ember.meta),
                      const SizedBox(width: 14),
                      const Kbd('Esc'),
                      const SizedBox(width: 6),
                      Text('Close', style: Ember.meta),
                      const Spacer(),
                      FilledButton(
                        key: const Key('launcher-run'),
                        onPressed: line == null || _busy ? null : _run,
                        child: const Text('Do it'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip in one of the design's tag colours.
class ToneChip extends StatelessWidget {
  const ToneChip({super.key, required this.label, required this.tone});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ChipTone.ink => (Ember.ink, Ember.white),
      ChipTone.blue => (const Color(0xFFE4EDFD), const Color(0xFF2B62D9)),
      ChipTone.green => (const Color(0xFFE3F5E9), const Color(0xFF23804A)),
      ChipTone.orange => (Ember.nowSoft, Ember.nowInk),
      ChipTone.amber => (const Color(0xFFFBF0D5), Ember.amberInk),
      ChipTone.violet => (const Color(0xFFEEE7FD), const Color(0xFF6C43D0)),
      ChipTone.plain => (Ember.neutral, Ember.ink),
    };
    return Tag(label, background: background, foreground: foreground);
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.label, required this.tone});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) => Appear(
    rise: 4,
    child: ToneChip(label: label, tone: tone),
  );
}
