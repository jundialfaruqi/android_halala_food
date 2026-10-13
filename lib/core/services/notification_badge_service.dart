import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationBadgeProvider =
    NotifierProvider<NotificationBadgeNotifier, int>(
  NotificationBadgeNotifier.new,
);

class NotificationBadgeNotifier extends Notifier<int> {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  @override
  int build() {
    return 0;
  }

  /// Memperbarui badge count ke nilai tertentu
  Future<void> setBadge(int count) async {
    final sanitizedCount = count < 0 ? 0 : count;
    state = sanitizedCount;
    await _updateLauncherBadge(sanitizedCount);
  }

  /// Menambah badge count (+1 atau +step)
  Future<void> increment({int step = 1}) async {
    final newCount = state + step;
    state = newCount;
    await _updateLauncherBadge(newCount);
  }

  /// Menghilangkan badge notifikasi (reset ke 0 & hapus notifikasi tray status bar)
  Future<void> clearBadge() async {
    if (state == 0) {
      // Tetap panggil update launcher badge dan cancelAll untuk memastikan bersih
      await _updateLauncherBadge(0);
      try {
        await _localNotifications.cancelAll();
      } catch (e) {
        debugPrint('[NotificationBadge] Gagal membatalkan notifikasi: $e');
      }
      return;
    }

    state = 0;
    await _updateLauncherBadge(0);
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('[NotificationBadge] Gagal membatalkan notifikasi: $e');
    }
  }

  Future<void> _updateLauncherBadge(int count) async {
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (e) {
      debugPrint('[NotificationBadge] Platform tidak mendukung app badge: $e');
    }
  }
}
