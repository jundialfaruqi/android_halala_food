import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_dropdown_search_field.dart';

void main() {
  group('AppDropdownSearchField Debounce & MinSearchLength Tests', () {
    const testItems = [
      'Semua Toko',
      'Toko Berkah Abadi',
      'Toko Barokah Jaya',
      'Toko Maju Bersama',
      'Toko Sumber Rejeki',
      'Warung Makmur',
    ];

    testWidgets(
        'does not trigger search when typed characters are less than minSearchLength (e.g. 3)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownSearchField<String>(
              hintText: 'Semua Toko',
              items: testItems,
              minSearchLength: 3,
              debounceDuration: const Duration(milliseconds: 300),
              itemLabel: (item) => item,
            ),
          ),
        ),
      );

      // Tap to open overlay
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Enter only 2 characters: "ma"
      await tester.enterText(find.byType(TextField), 'ma');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // With only 2 characters (< 3), it keeps showing the default items list
      expect(find.text('Semua Toko'), findsWidgets);
      expect(find.text('Toko Berkah Abadi'), findsOneWidget);
      expect(find.text('Toko Sumber Rejeki'), findsOneWidget);
    });

    testWidgets(
        'triggers search only after minSearchLength reached and debounce duration elapsed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownSearchField<String>(
              hintText: 'Semua Toko',
              items: testItems,
              minSearchLength: 3,
              debounceDuration: const Duration(milliseconds: 300),
              itemLabel: (item) => item,
            ),
          ),
        ),
      );

      // Tap to open overlay
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Enter 3 characters: "mak" (matches "Warung Makmur")
      await tester.enterText(find.byType(TextField), 'mak');
      await tester.pump();

      // Immediately before debounce fires (100ms in), search hasn't updated yet
      await tester.pump(const Duration(milliseconds: 100));

      // Advance clock past 300ms debounce
      await tester.pump(const Duration(milliseconds: 250));

      // Now "Warung Makmur" should be displayed, and non-matching stores filtered out
      expect(find.text('Warung Makmur'), findsOneWidget);
      expect(find.text('Toko Berkah Abadi'), findsNothing);
      expect(find.text('Toko Sumber Rejeki'), findsNothing);
    });

    testWidgets('clearing search restores the default list of items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownSearchField<String>(
              hintText: 'Semua Toko',
              items: testItems,
              minSearchLength: 3,
              debounceDuration: const Duration(milliseconds: 300),
              itemLabel: (item) => item,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Enter "mak" and wait for debounce
      await tester.enterText(find.byType(TextField), 'mak');
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(find.text('Warung Makmur'), findsOneWidget);
      expect(find.text('Toko Berkah Abadi'), findsNothing);

      // Clear the text field back to empty
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Default list is immediately restored
      expect(find.text('Semua Toko'), findsWidgets);
      expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    });
  });
}
