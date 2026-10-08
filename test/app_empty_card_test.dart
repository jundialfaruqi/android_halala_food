import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_empty_card.dart';
import 'package:android_halala_food/core/widgets/app_card.dart';

void main() {
  group('AppEmptyCard Global Padding & Consistency Tests', () {
    testWidgets('default AppEmptyCard is wrapped in SingleChildScrollView with vertical 40 padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyCard(
              title: 'Data Kosong',
              message: 'Tidak ada data.',
            ),
          ),
        ),
      );

      // Verify SingleChildScrollView exists
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(
        scrollWidget.padding,
        equals(const EdgeInsets.symmetric(vertical: 40.0)),
      );
      expect(
        scrollWidget.physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );

      // Verify Center exists inside scroll view
      expect(find.descendant(of: scrollFinder, matching: find.byType(Center)), findsAtLeastNWidgets(1));

      // Verify internal card padding
      final cardFinder = find.byType(AppCard);
      expect(cardFinder, findsOneWidget);
      final cardWidget = tester.widget<AppCard>(cardFinder);
      expect(
        cardWidget.padding,
        equals(const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0)),
      );
    });

    testWidgets('AppEmptyCard.search inherits global scrollable and vertical 40 padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyCard.search(
              query: 'keyword',
              onReset: () {},
            ),
          ),
        ),
      );

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(
        scrollWidget.padding,
        equals(const EdgeInsets.symmetric(vertical: 40.0)),
      );
    });

    testWidgets('AppEmptyCard.inline does not wrap in SingleChildScrollView and fits in unconstrained Column', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppEmptyCard.inline(
                  title: 'Inline Kosong',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Inline Kosong'), findsOneWidget);
    });

    testWidgets('Custom outerPadding can override default vertical 40', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyCard(
              title: 'Custom Outer',
              outerPadding: EdgeInsets.all(20),
            ),
          ),
        ),
      );

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(
        scrollWidget.padding,
        equals(const EdgeInsets.all(20)),
      );
    });
  });
}
