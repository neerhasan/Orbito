import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';

/// M0 test screen: the signed-in user's test rows, an add button and the
/// sync status line.
class SyncTestScreen extends ConsumerStatefulWidget {
  const SyncTestScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<SyncTestScreen> createState() => _SyncTestScreenState();
}

class _SyncTestScreenState extends ConsumerState<SyncTestScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addRow() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    try {
      await ref
          .read(syncTestRepositoryProvider)
          .addRow(userId: widget.user.id, text: text);
      _text.clear();
    } catch (error) {
      // The typed text stays in the box, so nothing is lost.
      _show('Could not save the row on this device. ($error)');
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(syncServiceProvider).signOut();
    } catch (error) {
      _show('Could not sign out. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(syncTestRowsProvider(widget.user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbito sync test'),
        actions: [
          TextButton(onPressed: _signOut, child: const Text('Sign out')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SyncStatusLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Signed in as ${widget.user.email ?? widget.user.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-row-text'),
                    controller: _text,
                    onSubmitted: (_) => _addRow(),
                    decoration: const InputDecoration(
                      labelText: 'New test row',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('add-row'),
                  onPressed: _addRow,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not read the local database. ($error)'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No rows yet. Add one above.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = items[index];
                        return ListTile(
                          title: Text(row.body),
                          subtitle: Text('Created ${_localTime(row.createdAt)}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusLine extends ConsumerWidget {
  const _SyncStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusTextProvider);
    final theme = Theme.of(context);
    return Container(
      key: const Key('sync-status'),
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync: ${status.label}', style: theme.textTheme.titleSmall),
          if (status.detail != null)
            Text(status.detail!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Shows a stored UTC timestamp in the device's time zone.
String _localTime(String stored) {
  final parsed = DateTime.tryParse(stored);
  if (parsed == null) return stored;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
