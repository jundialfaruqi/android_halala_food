import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:android_halala_food/core/constants/app_colors.dart';
import 'package:android_halala_food/features/home/presentation/widgets/home_bottom_navigation_bar.dart';

void main() {
  group('HomeBottomNavigationBar Widget Tests', () {
    testWidgets('renders all 5 navigation items with correct icons and labels', (
      WidgetTester tester,
    ) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
                tappedIndex = index;
              },
            ),
          ),
        ),
      );

      // Verify labels
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Aktifitas'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Buku Besar'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify Tabler icons
      expect(find.byIcon(TablerIcons.home), findsOneWidget);
      expect(find.byIcon(TablerIcons.message_dots), findsOneWidget);
      expect(find.byIcon(TablerIcons.qrcode), findsOneWidget);
      expect(find.byIcon(TablerIcons.notebook), findsOneWidget);
      expect(find.byIcon(TablerIcons.user), findsOneWidget);

      // Tap on Scan QR
      await tester.tap(find.text('Scan QR'));
      await tester.pump();
      expect(tappedIndex, equals(2));

      // Tap on Aktifitas
      await tester.tap(find.text('Aktifitas'));
      await tester.pump();
      expect(tappedIndex, equals(1));
    });

    testWidgets('Scan QR item has rounded circle with brandPrimary background and white text/icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigationBar(),
          ),
        ),
      );

      // Find the circular container
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.shape == BoxShape.circle &&
              decoration.color == AppColors.brandPrimary;
        }
        return false;
      });

      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);

      // Verify QR icon is white
      final qrIcon = tester.widget<Icon>(find.byIcon(TablerIcons.qrcode));
      expect(qrIcon.color, equals(Colors.white));
      expect(qrIcon.size, greaterThan(24.0)); // Larger than the 24px standard icons

      // Verify Scan QR text is white
      final scanQrText = tester.widget<Text>(find.text('Scan QR'));
      expect(scanQrText.style?.color, equals(Colors.white));
    });

    testWidgets('Navbar container has no top border', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigationBar(),
          ),
        ),
      );

      final navbarFinder = find.byType(HomeBottomNavigationBar);
      final navContainerFinder = find.descendant(
        of: navbarFinder,
        matching: find.byType(Container),
      ).first;

      final navContainer = tester.widget<Container>(navContainerFinder);
      final decoration = navContainer.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });
  });
}
