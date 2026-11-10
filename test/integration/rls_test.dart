// Proves on the REAL Supabase project that one account cannot see or change
// another account's rows (row-level security).
//
// It needs the internet, the filled-in `.env`, and two test accounts in
// `.env.test` (see `env.test.example`). Without them the test is skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' show uuid;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  test(
    'a second account cannot read, change, delete or forge the first '
    'account\'s rows',
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
      await accountA.from('sync_test').insert({
        'id': rowId,
        'user_id': idOfA,
        'text': 'rls test row',
      });
      addTearDown(() => accountA.from('sync_test').delete().eq('id', rowId));

      // The owner can read the row.
      final ownView = await accountA.from('sync_test').select().eq('id', rowId);
      expect(ownView, hasLength(1));

      // The other account cannot read it.
      final otherView = await accountB
          .from('sync_test')
          .select()
          .eq('id', rowId);
      expect(otherView, isEmpty);

      // The other account cannot see ANY of the first account's rows.
      final allOfA = await accountB
          .from('sync_test')
          .select()
          .eq('user_id', idOfA);
      expect(allOfA, isEmpty);

      // The other account cannot change it.
      final changed = await accountB
          .from('sync_test')
          .update({'text': 'changed by the wrong account'})
          .eq('id', rowId)
          .select();
      expect(changed, isEmpty);

      // The other account cannot delete it.
      final removed = await accountB
          .from('sync_test')
          .delete()
          .eq('id', rowId)
          .select();
      expect(removed, isEmpty);

      // The row is untouched.
      final after = await accountA
          .from('sync_test')
          .select()
          .eq('id', rowId)
          .single();
      expect(after['text'], 'rls test row');

      // The other account cannot create a row in the first account's name.
      final forgedId = uuid.v4();
      addTearDown(() => accountA.from('sync_test').delete().eq('id', forgedId));
      await expectLater(
        accountB.from('sync_test').insert({
          'id': forgedId,
          'user_id': idOfA,
          'text': 'forged',
        }),
        throwsA(isA<PostgrestException>()),
      );

      // Someone who is not signed in gets nothing.
      List<Map<String, dynamic>> publicView;
      try {
        publicView = await signedOut.from('sync_test').select();
      } on PostgrestException {
        publicView = const [];
      }
      expect(publicView, isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
