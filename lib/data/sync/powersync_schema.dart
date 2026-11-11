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
  Table('life_areas', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table('goals', [
    Column.text('user_id'),
    Column.text('title'),
    Column.text('life_area_id'),
    Column.text('target_date'),
    Column.text('done_when'),
    Column.integer('progress'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table('projects', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('goal_id'),
    Column.text('color'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table('tasks', [
    Column.text('user_id'),
    Column.text('title'),
    Column.text('project_id'),
    Column.text('goal_id'),
    Column.text('due_date'),
    Column.text('priority'),
    Column.text('status'),
    Column.text('completed_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
]);
