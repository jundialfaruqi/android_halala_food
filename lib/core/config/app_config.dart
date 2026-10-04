import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000/api';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '') ?? 30000;
  static String get appName => dotenv.env['APP_NAME'] ?? 'Halala Food';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static bool get isDev => appEnv == 'development';
}
