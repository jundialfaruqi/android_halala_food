import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_bar.dart';

void main() {
  testWidgets('AppAppBar dynamically toggles shadow on scroll', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const AppAppBar(title: 'Test', hasShadow: true),
          body: ListView.builder(
            controller: scrollController,
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
          ),
        ),
      ),
    );

    // Initial state: at offset 0, no shadow
    AnimatedContainer container = tester.widget(
      find.byType(AnimatedContainer).first,
    );
    BoxDecoration decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);

    // Scroll down 100 pixels
    scrollController.jumpTo(100);
    await tester.pumpAndSettle();

    // Scrolled state: shadow appears
    container = tester.widget(
      find.byType(AnimatedContainer).first,
    );
    decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.isNotEmpty, isTrue);

    // Scroll back to top
    scrollController.jumpTo(0);
    await tester.pumpAndSettle();

    // Back to top: shadow disappears
    container = tester.widget(
      find.byType(AnimatedContainer).first,
    );
    decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('AppAppBar toggles shadow in Column + Expanded + ListView structure', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const AppAppBar(title: 'Mitra Toko', hasShadow: true),
          body: Column(
            children: [
              Container(height: 60, color: Colors.white, child: const Text('Header')),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    AnimatedContainer container = tester.widget(
      find.byType(AnimatedContainer).first,
    );
    BoxDecoration decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);

    scrollController.jumpTo(100);
    await tester.pumpAndSettle();

    container = tester.widget(
      find.byType(AnimatedContainer).first,
    );
    decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNotNull);
  });
}
