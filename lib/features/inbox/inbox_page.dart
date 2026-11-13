import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/launcher.dart';
import '../../ui/ember.dart';
import '../../ui/widgets.dart';

/// The Inbox: lines from the Quick Launcher that were not sorted, and notes.
/// Each can become a task or be removed. Nothing is lost on its way here.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  /// Turns an Inbox line into a task, reading its date, time, project and
  /// priority like the Quick Launcher does.
  Future<void> _makeTask(
    BuildContext context,
    WidgetRef ref,
    InboxItem item,
  ) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    final parsed = parseLine(
      'task ${item.body}',
      today: dayKey(ref.read(clockProvider)()),
      projects: ref.read(projectsProvider).value ?? const [],
    );
    final line = parsed is TaskLine ? parsed : null;
    try {
      final tasks = ref.read(taskRepositoryProvider);
      final title = line?.title ?? item.body;
      final id = await tasks.addTask(
        userId: userId,
        title: title,
        projectId: line?.projectId,
        dueDate: line?.dueDate,
        priority: line?.priority ?? TaskPriority.none,
      );
      if (line?.notes != null) {
        await tasks.updateTask(
          id,
          title: title,
          projectId: line?.projectId,
          dueDate: line?.dueDate,
          priority: line!.priority,
          notes: line.notes,
        );
      }
      await ref.read(captureRepositoryProvider).removeFromInbox(item.id);
      if (context.mounted) showMessage(context, 'Now a task: $title');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    InboxItem item,
  ) async {
    try {
      await ref.read(captureRepositoryProvider).removeFromInbox(item.id);
    } catch (error) {
      if (context.mounted) showMessage(context, 'Could not remove. ($error)');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider).value ?? const <InboxItem>[];
    final today = dayKey(ref.watch(clockProvider)());
    return PageLayout(
      main: [
        PageHeader(
          title: 'Inbox',
          subtitle: items.isEmpty
              ? 'Lines the Quick Launcher could not sort land here'
              : '${countOf(items.length, 'line')} waiting',
        ),
        if (items.isEmpty)
          const EmptyHint(
            title: 'Nothing waiting',
            text:
                'Type anything in the Quick Launcher (Ctrl K). What it '
                'cannot sort lands here, so nothing is lost.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Tile(
                    key: Key('inbox-${item.id}'),
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Row(
                      children: [
                        Icon(
                          item.kind == InboxKind.note
                              ? Icons.sticky_note_2_outlined
                              : Icons.inbox_outlined,
                          size: 16,
                          color: Ember.ink2,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.body,
                                style: Ember.item.copyWith(color: Ember.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (item.kind == InboxKind.note) 'Note',
                                  formatRelativeDay(
                                    dayKeyOfStoredTime(item.createdAt) ?? today,
                                    today: today,
                                  ),
                                ].join(' · '),
                                style: Ember.meta,
                              ),
                            ],
                          ),
                        ),
                        SoftButton(
                          key: Key('inbox-task-${item.id}'),
                          icon: Icons.check_circle_outline,
                          label: 'Make a task',
                          background: Ember.white,
                          onPressed: () => _makeTask(context, ref, item),
                        ),
                        IconButton(
                          key: Key('inbox-remove-${item.id}'),
                          tooltip: 'Remove',
                          iconSize: 16,
                          color: Ember.ink2,
                          onPressed: () => _remove(context, ref, item),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
      rail: [
        Text('How the Inbox works', style: Ember.h2),
        Text(
          'Press Ctrl K anywhere and type one line. Orbito turns it into a '
          'task, a habit mark, a night of sleep or a focus session. A line it '
          'cannot sort, and every note, waits here until you decide.',
          style: Ember.body.copyWith(color: Ember.ink2),
        ),
        Text(
          'Make a task reads a date, a time, a #project and a priority from '
          'the line, like the Quick Launcher does.',
          style: Ember.meta,
        ),
      ],
    );
  }
}
