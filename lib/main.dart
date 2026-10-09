import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase & FCM Background Handler
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Gagal inisialisasi Firebase: $e');
  }

  // Inisialisasi locale formatting Indonesia
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Gagal inisialisasi date formatting id_ID: $e');
  }

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

class HalalaFoodApp extends ConsumerStatefulWidget {
  const HalalaFoodApp({super.key});

  @override
  ConsumerState<HalalaFoodApp> createState() => _HalalaFoodAppState();
}

class _HalalaFoodAppState extends ConsumerState<HalalaFoodApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize(
        onNotificationTap: (message) {
          final router = ref.read(appRouterProvider);
          final type = message.data['type'];
          final id =
              message.data['id'] ?? message.data['delivery_id'] ?? message.data['invoice_id'];
          if (type == 'delivery' && id != null) {
            router.push('/deliveries/$id');
          } else if (type == 'invoice' && id != null) {
            router.push('/invoices/$id');
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return AppSecurityWrapper(
          child: AppConnectivityWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
