import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000/api';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '') ?? 30000;
  static String get appName => dotenv.env['APP_NAME'] ?? 'Halala Food';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static bool get isDev => appEnv == 'development';

  // Laravel Reverb WebSocket configuration
  static String get reverbAppKey =>
      dotenv.env['REVERB_APP_KEY'] ?? 'halalafoodkey123';

  static String get reverbHost {
    final customHost = dotenv.env['REVERB_HOST'];
    if (customHost != null && customHost.isNotEmpty) return customHost;
    try {
      final parsed = Uri.parse(baseUrl);
      return parsed.host.isNotEmpty ? parsed.host : '10.0.2.2';
    } catch (_) {
      return '10.0.2.2';
    }
  }

  static int get reverbPort {
    final customPort = int.tryParse(dotenv.env['REVERB_PORT'] ?? '');
    if (customPort != null) return customPort;
    try {
      final parsed = Uri.parse(baseUrl);
      if (parsed.scheme == 'https') return 443;
    } catch (_) {}
    return 8080;
  }

  static String get reverbScheme {
    final customScheme = dotenv.env['REVERB_SCHEME'];
    if (customScheme != null && customScheme.isNotEmpty) return customScheme;
    try {
      final parsed = Uri.parse(baseUrl);
      return parsed.scheme == 'https' ? 'https' : 'http';
    } catch (_) {
      return 'http';
    }
  }

  static bool get reverbUseTls => reverbScheme == 'https';

  static String get broadcastingAuthUrl {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/broadcasting/auth';
  }
}
