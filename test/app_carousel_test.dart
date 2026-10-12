import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_carousel.dart';

void main() {
  group('AppCarousel Material 3 Core Widget Tests', () {
    testWidgets('renders children in Material 3 CarouselView', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCarousel(
              height: 200,
              itemExtent: 280,
              children: [
                Container(key: const ValueKey('item-0'), child: const Text('Item 0')),
                Container(key: const ValueKey('item-1'), child: const Text('Item 1')),
                Container(key: const ValueKey('item-2'), child: const Text('Item 2')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CarouselView), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('AppCarousel.builder dynamically builds items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCarousel.builder(
              height: 180,
              itemExtent: 250,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Text('Card $index');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CarouselView), findsOneWidget);
      expect(find.text('Card 0'), findsOneWidget);
    });

    testWidgets('renders weighted layout with flexWeights', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCarousel.weighted(
              height: 200,
              flexWeights: const [7, 2],
              children: const [
                Text('Weighted 0'),
                Text('Weighted 1'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CarouselView), findsOneWidget);
      expect(find.text('Weighted 0'), findsOneWidget);
    });
  });
}
