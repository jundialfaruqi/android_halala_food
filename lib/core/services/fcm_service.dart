import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('FCM Background Init Error: $e');
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return FcmService(dioClient: dioClient);
});

class FcmService {
  final DioClient _dioClient;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'halala_food_notifications',
    'Notifikasi Halala Food',
    description: 'Channel untuk notifikasi surat jalan dan faktur pengantaran',
    importance: Importance.max,
    playSound: true,
  );

  FcmService({required DioClient dioClient}) : _dioClient = dioClient;

  /// Inisialisasi konfigurasi notifikasi lokal dan FCM listener
  Future<void> initialize({Function(RemoteMessage)? onNotificationTap}) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Minta izin notifikasi (Pop-up permission pada Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Permission Status: ${settings.authorizationStatus}');

      // 2. Setup Android Local Notification Channel
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Callback saat user mengklik banner notifikasi lokal
          debugPrint('Local notification clicked: ${response.payload}');
        },
      );

      // 3. Listener notifikasi saat aplikasi berada di FOREGROUND
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.messageId}');
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title ?? 'Halala Food',
            notification.body ?? '',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: message.data['type'] ?? '',
          );
        }
      });

      // 4. Listener saat notifikasi diklik dari BACKGROUND
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification tapped from background: ${message.data}');
        if (onNotificationTap != null) {
          onNotificationTap(message);
        }
      });

      // 5. Cek jika aplikasi dibuka dari kondisi KILLED/TERMINATED melalui notifikasi
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && onNotificationTap != null) {
        onNotificationTap(initialMessage);
      }

      // 6. Listener jika FCM token diperbarui oleh Google Play Services
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        syncTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('FCM Initialize Error: $e');
    }
  }

  /// Mengambil FCM Device Token saat ini
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Gagal mengambil FCM Token: $e');
      return null;
    }
  }

  /// Sinkronisasi token FCM ke backend Laravel
  Future<void> syncTokenToBackend([String? token]) async {
    try {
      final fcmToken = token ?? await getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      debugPrint('Mengirim FCM Token ke Backend: $fcmToken');
      await _dioClient.post(
        ApiEndpoints.updateFcmToken,
        data: {'fcm_token': fcmToken},
      );
      debugPrint('FCM Token berhasil disinkronkan ke server.');
    } catch (e) {
      // Non-blocking, abaikan kegagalan sync tanpa mengganggu user
      debugPrint('Gagal mengirim FCM Token ke server: $e');
    }
  }
}
