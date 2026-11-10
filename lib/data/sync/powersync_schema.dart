import 'package:powersync/powersync.dart';

/// The tables PowerSync keeps on the device. This must match the Drift tables
/// in `lib/data/local/app_database.dart` and the SQL in `supabase/`.
///
/// PowerSync adds the `id` column by itself, so it is not listed.
const powerSyncSchema = Schema([
  Table('sync_test', [
    Column.text('user_id'),
    Column.text('text'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
]);
