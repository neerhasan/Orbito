import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The three public values the app needs to reach the server.
///
/// They come from the `.env` file, which Git ignores. Only public values
/// belong here. Secret keys must never be put in the app.
class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.powerSyncUrl,
  });

  static const supabaseUrlName = 'SUPABASE_URL';
  static const supabasePublishableKeyName = 'SUPABASE_PUBLISHABLE_KEY';
  static const powerSyncUrlName = 'POWERSYNC_URL';

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String powerSyncUrl;

  /// Reads the `.env` file bundled with the app.
  static Future<AppEnv> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);
    return AppEnv.fromMap(dotenv.env);
  }

  factory AppEnv.fromMap(Map<String, String> values) {
    String read(String name) => (values[name] ?? '').trim();
    return AppEnv(
      supabaseUrl: read(supabaseUrlName),
      supabasePublishableKey: read(supabasePublishableKeyName),
      powerSyncUrl: read(powerSyncUrlName),
    );
  }

  /// Names of the values that are empty or still hold the example text.
  List<String> get missing => [
    if (!_isUrl(supabaseUrl)) supabaseUrlName,
    if (_isPlaceholder(supabasePublishableKey)) supabasePublishableKeyName,
    if (!_isUrl(powerSyncUrl)) powerSyncUrlName,
  ];

  bool get isComplete => missing.isEmpty;

  static bool _isPlaceholder(String value) =>
      value.isEmpty || value.toLowerCase().contains('your-');

  static bool _isUrl(String value) {
    if (_isPlaceholder(value)) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
