import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connects PowerSync to Supabase.
///
/// It does two jobs: it hands PowerSync the signed-in user's access token,
/// and it uploads changes made on this device to Supabase.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector({required this.supabase, required this.powerSyncUrl});

  final SupabaseClient supabase;
  final String powerSyncUrl;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    var session = supabase.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      // Throws while offline. PowerSync then retries later.
      session = (await supabase.auth.refreshSession()).session;
      if (session == null) return null;
    }
    final expiresAt = session.expiresAt;
    return PowerSyncCredentials(
      endpoint: powerSyncUrl,
      token: session.accessToken,
      userId: session.user.id,
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (final change in transaction.crud) {
        final table = supabase.from(change.table);
        switch (change.op) {
          case UpdateType.put:
            await table.upsert({...?change.opData, 'id': change.id});
          case UpdateType.patch:
            await table.update(change.opData ?? {}).eq('id', change.id);
          case UpdateType.delete:
            await table.delete().eq('id', change.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (error) {
      if (isPermanentUploadError(error.code)) {
        // The server will never accept this change (for example it breaks an
        // access rule). Skip it so later changes are not blocked for ever.
        debugPrint('Upload rejected by the server and skipped: $error');
        await transaction.complete();
        return;
      }
      // Anything else may be temporary (no internet, server paused).
      // Throwing makes PowerSync keep the change and try again later.
      rethrow;
    }
  }
}

/// True for PostgreSQL error codes that retrying cannot fix:
/// class 22 (bad data), class 23 (broken constraint) and 42501 (access rule).
bool isPermanentUploadError(String? code) {
  if (code == null) return false;
  return code.startsWith('22') || code.startsWith('23') || code == '42501';
}
