import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi konfigurasi dotenv
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Gagal memuat file .env: $e');
  }

  runApp(
    const ProviderScope(
      child: HalalaFoodApp(),
    ),
  );
}

class HalalaFoodApp extends ConsumerWidget {
  const HalalaFoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
