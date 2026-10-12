import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/cash_book/presentation/viewmodels/cash_book_viewmodel.dart';
import 'package:android_halala_food/features/cash_book/presentation/views/cash_book_screen.dart';

class _MockCashBookViewModel extends CashBookViewModel {
  @override
  CashBookState build() {
    return const CashBookState(
      isLoading: false,
      totalCashBalance: 15000000.0,
      filteredIncome: 2500000.0,
      filteredExpense: 1200000.0,
      filteredPrive: 500000.0,
    );
  }
}

void main() {
  testWidgets('CashBookScreen Pemasukan Usaha card and Prive card have equal height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashBookViewModelProvider.overrideWith(() => _MockCashBookViewModel()),
        ],
        child: const MaterialApp(
          home: CashBookScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both headers exist
    final incomeText = find.text('Pemasukan Usaha');
    final priveText = find.text('Prive Pemilik');
    expect(incomeText, findsOneWidget);
    expect(priveText, findsOneWidget);

    // Find the Container enclosing each card
    final incomeCard = find.ancestor(
      of: incomeText,
      matching: find.byType(Container),
    ).first;

    final priveCard = find.ancestor(
      of: priveText,
      matching: find.byType(Container),
    ).first;

    final incomeSize = tester.getSize(incomeCard);
    final priveSize = tester.getSize(priveCard);

    // Both cards must have the exact same height
    expect(incomeSize.height, equals(priveSize.height));
  });
}
