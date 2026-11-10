import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/sync/supabase_connector.dart';

void main() {
  group('isPermanentUploadError', () {
    test('an access-rule refusal is permanent', () {
      expect(isPermanentUploadError('42501'), isTrue);
    });

    test('bad data and broken constraints are permanent', () {
      expect(isPermanentUploadError('22P02'), isTrue);
      expect(isPermanentUploadError('23505'), isTrue);
    });

    test('other errors are retried', () {
      expect(isPermanentUploadError(null), isFalse);
      expect(isPermanentUploadError('08006'), isFalse);
      expect(isPermanentUploadError('PGRST301'), isFalse);
    });
  });
}
