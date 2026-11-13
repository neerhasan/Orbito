// Proves on the REAL Supabase project that one account cannot see or change
// another account's rows (row-level security), for every synced table.
//
// It needs the internet, the filled-in `.env`, and two test accounts in
// `.env.test` (see `env.test.example`). Without them the tests are skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' show uuid;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every synced table, with one column the test writes: its first value and
/// a second value the wrong account tries to change it to. All other
/// columns have defaults on the server. Add each new table here.
const _tables = <String, (String, Object, Object)>{
  'sync_test': ('text', 'rls test row', 'changed'),
  'life_areas': ('name', 'rls test row', 'changed'),
  'goals': ('title', 'rls test row', 'changed'),
  'projects': ('name', 'rls test row', 'changed'),
  'tasks': ('title', 'rls test row', 'changed'),
  'habits': ('name', 'rls test row', 'changed'),
  'habit_logs': ('status', 'done', 'skip'),
  'focus_sessions': ('focus_seconds', 60, 999),
  'sleep_logs': ('bed_time', '23:00', '01:00'),
  'inbox_items': ('text', 'rls test row', 'changed'),
  'preferences': ('today_sections', 'habits', 'tasks'),
};

Map<String, String> _readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final split = trimmed.indexOf('=');
    if (split <= 0) continue;
    values[trimmed.substring(0, split).trim()] = trimmed
        .substring(split + 1)
        .trim();
  }
  return values;
}

void main() {
  final env = {..._readEnvFile('.env'), ..._readEnvFile('.env.test')};
  String value(String name) => env[name] ?? '';

  final url = value('SUPABASE_URL');
  final key = value('SUPABASE_PUBLISHABLE_KEY');
  final emailA = value('RLS_TEST_EMAIL_A');
  final passwordA = value('RLS_TEST_PASSWORD_A');
  final emailB = value('RLS_TEST_EMAIL_B');
  final passwordB = value('RLS_TEST_PASSWORD_B');

  final ready =
      url.startsWith('https://') &&
      !url.contains('your-') &&
      key.isNotEmpty &&
      !key.contains('your-') &&
      passwordA.isNotEmpty &&
      passwordB.isNotEmpty;
  final skip = ready
      ? null
      : 'Skipped: fill in .env and .env.test (two test accounts) to run it.';

  SupabaseClient newClient() => SupabaseClient(
    url,
    key,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  for (final MapEntry(key: table, value: (column, first, second))
      in _tables.entries) {
    test(
      '$table: a second account cannot read, change, delete or forge the '
      'first account\'s rows',
      () async {
        final accountA = newClient();
        final accountB = newClient();
        final signedOut = newClient();
        addTearDown(accountA.dispose);
        addTearDown(accountB.dispose);
        addTearDown(signedOut.dispose);

        await accountA.auth.signInWithPassword(
          email: emailA,
          password: passwordA,
        );
        await accountB.auth.signInWithPassword(
          email: emailB,
          password: passwordB,
        );
        final idOfA = accountA.auth.currentUser!.id;
        expect(
          accountB.auth.currentUser!.id,
          isNot(idOfA),
          reason: 'The two test accounts must be different accounts.',
        );

        final rowId = uuid.v4();
        await accountA.from(table).insert({
          'id': rowId,
          'user_id': idOfA,
          column: first,
        });
        addTearDown(() => accountA.from(table).delete().eq('id', rowId));

        // The owner can read the row.
        final ownView = await accountA.from(table).select().eq('id', rowId);
        expect(ownView, hasLength(1));

        // The other account cannot read it.
        final otherView = await accountB.from(table).select().eq('id', rowId);
        expect(otherView, isEmpty);

        // The other account cannot see ANY of the first account's rows.
        final allOfA = await accountB.from(table).select().eq('user_id', idOfA);
        expect(allOfA, isEmpty);

        // The other account cannot change it.
        final changed = await accountB
            .from(table)
            .update({column: second})
            .eq('id', rowId)
            .select();
        expect(changed, isEmpty);

        // The other account cannot delete it.
        final removed = await accountB
            .from(table)
            .delete()
            .eq('id', rowId)
            .select();
        expect(removed, isEmpty);

        // The row is untouched.
        final after = await accountA
            .from(table)
            .select()
            .eq('id', rowId)
            .single();
        expect(after[column], first);

        // The other account cannot create a row in the first account's name.
        final forgedId = uuid.v4();
        addTearDown(() => accountA.from(table).delete().eq('id', forgedId));
        await expectLater(
          accountB.from(table).insert({
            'id': forgedId,
            'user_id': idOfA,
            column: first,
          }),
          throwsA(isA<PostgrestException>()),
        );

        // Someone who is not signed in gets nothing.
        List<Map<String, dynamic>> publicView;
        try {
          publicView = await signedOut.from(table).select();
        } on PostgrestException {
          publicView = const [];
        }
        expect(publicView, isEmpty);
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  }
}
