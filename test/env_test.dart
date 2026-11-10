import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/app/env.dart';

void main() {
  const complete = {
    AppEnv.supabaseUrlName: 'https://abc.supabase.co',
    AppEnv.supabasePublishableKeyName: 'sb_publishable_123',
    AppEnv.powerSyncUrlName: 'https://abc.powersync.journeyapps.com',
  };

  test('is complete when all three values are filled in', () {
    final env = AppEnv.fromMap(complete);
    expect(env.isComplete, isTrue);
    expect(env.missing, isEmpty);
  });

  test('trims spaces around values', () {
    final env = AppEnv.fromMap({
      ...complete,
      AppEnv.supabaseUrlName: '  https://abc.supabase.co  ',
    });
    expect(env.supabaseUrl, 'https://abc.supabase.co');
  });

  test('reports every value when the file is empty', () {
    final env = AppEnv.fromMap(const {});
    expect(env.isComplete, isFalse);
    expect(env.missing, [
      AppEnv.supabaseUrlName,
      AppEnv.supabasePublishableKeyName,
      AppEnv.powerSyncUrlName,
    ]);
  });

  test('treats the example text as missing', () {
    final env = AppEnv.fromMap(const {
      AppEnv.supabaseUrlName: 'https://your-project-ref.supabase.co',
      AppEnv.supabasePublishableKeyName: 'your-publishable-key',
      AppEnv.powerSyncUrlName:
          'https://your-instance-id.powersync.journeyapps.com',
    });
    expect(env.missing, hasLength(3));
  });

  test('rejects an address that is not https', () {
    final env = AppEnv.fromMap({
      ...complete,
      AppEnv.powerSyncUrlName: 'abc.powersync.journeyapps.com',
    });
    expect(env.missing, [AppEnv.powerSyncUrlName]);
  });
}
