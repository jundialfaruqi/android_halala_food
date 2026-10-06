import 'package:android_halala_food/core/utils/app_security_service.dart';
import 'package:android_halala_food/core/widgets/app_security_dialog.dart';
import 'package:android_halala_food/core/widgets/app_security_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppSecurityService.forceEnabledForTesting = false;
    AppSecurityService.violationNotifier.value = null;
  });

  tearDown(() {
    AppSecurityService.forceEnabledForTesting = false;
    AppSecurityService.violationNotifier.value = null;
  });

  group('AppSecurityService & SecurityCheckResult', () {
    test('Default mode (debug/test) should be inactive unless forced', () async {
      expect(AppSecurityService.isProtectionActive, isFalse);
      final result = await AppSecurityService.checkSecurity();
      expect(result.isCompromised, isFalse);
    });

    test('SecurityCheckResult messages and titles match violation type', () {
      const devResult = SecurityCheckResult(
        isCompromised: true,
        isDevMode: true,
        isMockLocation: false,
      );
      expect(devResult.title, 'Mode Pengembang Aktif');
      expect(devResult.message, contains('Developer mode aktif'));

      const mockResult = SecurityCheckResult(
        isCompromised: true,
        isDevMode: false,
        isMockLocation: true,
      );
      expect(mockResult.title, 'Lokasi Palsu Terdeteksi');
      expect(mockResult.message, contains('Fake GPS'));

      const bothResult = SecurityCheckResult(
        isCompromised: true,
        isDevMode: true,
        isMockLocation: true,
      );
      expect(bothResult.title, 'Peringatan Keamanan Perangkat');
      expect(bothResult.message, contains('Mode Pengembang dan Fake GPS'));
    });

    test('reportMockGpsDetected updates violationNotifier when protection is active', () {
      AppSecurityService.forceEnabledForTesting = true;

      expect(AppSecurityService.violationNotifier.value, isNull);
      AppSecurityService.reportMockGpsDetected();

      final violation = AppSecurityService.violationNotifier.value;
      expect(violation, isNotNull);
      expect(violation!.isCompromised, isTrue);
      expect(violation.isMockLocation, isTrue);
    });
  });

  group('AppSecurityDialog Widget', () {
    testWidgets('Renders title, message, and call to action button correctly',
        (tester) async {
      bool killAppCalled = false;
      const testResult = SecurityCheckResult(
        isCompromised: true,
        isDevMode: true,
        isMockLocation: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSecurityDialog(
              result: testResult,
              onKillApp: () {
                killAppCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify title & message
      expect(find.text('Mode Pengembang Aktif'), findsOneWidget);
      expect(
        find.textContaining('Developer mode aktif, silakan matikan developer mode'),
        findsOneWidget,
      );

      // Verify CTA button "Oke, saya mengerti"
      final ctaButton = find.text('Oke, saya mengerti');
      expect(ctaButton, findsOneWidget);

      await tester.tap(ctaButton);
      await tester.pump();
      expect(killAppCalled, isTrue);
    });
  });

  group('AppSecurityWrapper Widget', () {
    testWidgets('Renders child content when no violation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppSecurityWrapper(
            child: Text('Konten Normal Halaman'),
          ),
        ),
      );

      expect(find.text('Konten Normal Halaman'), findsOneWidget);
      expect(find.byType(AppSecurityDialog), findsNothing);
    });

    testWidgets('Dynamically displays dialog when violation occurs mid-session',
        (tester) async {
      AppSecurityService.forceEnabledForTesting = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: AppSecurityWrapper(
            child: Text('Konten Normal Halaman'),
          ),
        ),
      );

      expect(find.text('Konten Normal Halaman'), findsOneWidget);
      expect(find.byType(AppSecurityDialog), findsNothing);

      // Simulasi user mengaktifkan fake GPS / dev mode di tengah sesi
      AppSecurityService.reportMockGpsDetected();
      await tester.pump();

      // Dialog langsung muncul menutupi layar
      expect(find.byType(AppSecurityDialog), findsOneWidget);
      expect(find.text('Lokasi Palsu Terdeteksi'), findsOneWidget);
      expect(find.text('Oke, saya mengerti'), findsOneWidget);
    });
  });
}
