import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_schema.dart';
import 'supabase_connector.dart';

/// Opens the local database file that PowerSync keeps in step with the server.
Future<PowerSyncDatabase> openPowerSyncDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final separator = directory.path.contains('\\') ? '\\' : '/';
  final database = PowerSyncDatabase(
    schema: powerSyncSchema,
    path: '${directory.path}${separator}orbito.db',
  );
  await database.initialize();
  return database;
}

/// Starts and stops sync for the signed-in user.
class SyncService {
  SyncService({
    required this.powerSync,
    required this.supabase,
    required this.powerSyncUrl,
  });

  final PowerSyncDatabase powerSync;
  final SupabaseClient supabase;
  final String powerSyncUrl;

  /// Starts syncing. Call only when a user is signed in.
  Future<void> connect() {
    return powerSync.connect(
      connector: SupabaseConnector(
        supabase: supabase,
        powerSyncUrl: powerSyncUrl,
      ),
    );
  }

  /// Signs out and removes this user's data from the device, so the next
  /// person to sign in on this device cannot see it.
  Future<void> signOut() async {
    await powerSync.disconnectAndClear();
    await supabase.auth.signOut();
  }
}
