import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/services/notification_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationBadgeNotifier Tests', () {
    test('initial unread count is 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(notificationBadgeProvider), equals(0));
    });

    test('increment increases count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationBadgeProvider.notifier);
      await notifier.increment();
      expect(container.read(notificationBadgeProvider), equals(1));

      await notifier.increment(step: 2);
      expect(container.read(notificationBadgeProvider), equals(3));
    });

    test('setBadge sets count directly and sanitizes negative numbers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationBadgeProvider.notifier);
      await notifier.setBadge(7);
      expect(container.read(notificationBadgeProvider), equals(7));

      await notifier.setBadge(-3);
      expect(container.read(notificationBadgeProvider), equals(0));
    });

    test('clearBadge resets count to 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationBadgeProvider.notifier);
      await notifier.setBadge(10);
      expect(container.read(notificationBadgeProvider), equals(10));

      await notifier.clearBadge();
      expect(container.read(notificationBadgeProvider), equals(0));
    });
  });
}
