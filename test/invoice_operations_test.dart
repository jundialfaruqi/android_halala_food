import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/presentation/utils/invoice_share_helper.dart';
import 'package:android_halala_food/features/invoice/presentation/widgets/invoice_payment_dialog.dart';
import 'package:android_halala_food/features/invoice/presentation/widgets/invoice_reconciliation_dialog.dart';

void main() {
  const dummyInvoice = InvoiceModel(
    id: 99,
    invoiceNumber: 'INV-20261009-0099',
    invoiceDate: '2026-10-09',
    dueDate: '2026-10-23',
    deliveryNumber: 'SJ-20261009-0001',
    totalAmount: 1000000,
    paidAmount: 200000,
    remainingBalance: 800000,
    discount: 50000,
    status: 'sebagian',
    statusLabel: 'Dibayar Sebagian',
    store: InvoiceStoreModel(
      id: 5,
      name: 'Toko Sumber Barokah',
      ownerName: 'Budi Santoso',
      phone: '081234567890',
    ),
    items: [
      InvoiceItemModel(
        id: 1,
        invoiceId: 99,
        productId: 10,
        productName: 'Keripik Pisang 250g',
        productUnit: 'pcs',
        quantity: 50,
        deliveredQuantity: 50,
        remainingQuantity: 0,
        damagedQuantity: 0,
        returnedQuantity: 0,
        unitPrice: 20000,
        subtotal: 1000000,
      ),
    ],
  );

  group('InvoiceShareHelper Tests', () {
    test('formatInvoiceReceiptText generates correct text formatting', () {
      final receipt = InvoiceShareHelper.formatInvoiceReceiptText(dummyInvoice);

      expect(receipt.contains('Halo *Toko Sumber Barokah (Bpk/Ibu Budi Santoso)*,'), isTrue);
      expect(receipt.contains('INV-20261009-0099'), isTrue);
      expect(receipt.contains('SJ-20261009-0001'), isTrue);
      expect(receipt.contains('Keripik Pisang 250g'), isTrue);
      expect(receipt.contains('Rp 1.000.000'), isTrue);
      expect(receipt.contains('Diskon: - Rp 50.000'), isTrue);
      expect(receipt.contains('Sudah Dibayar: Rp 200.000'), isTrue);
      expect(receipt.contains('Sisa Tagihan: Rp 800.000'), isTrue);
    });
  });

  group('InvoicePaymentDialog Widget Tests', () {
    testWidgets('renders payment dialog and fills full payment on CTA click',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => InvoicePaymentDialog.show(
                    context: context,
                    invoice: dummyInvoice,
                  ),
                  child: const Text('Buka Payment'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Catat Pembayaran'), findsOneWidget);
      expect(find.text('INV-20261009-0099'), findsOneWidget);
      expect(find.text('Rp 800.000'), findsWidgets);
      expect(find.text('Bayar Lunas (100%)'), findsOneWidget);

      // Tap Bayar Lunas CTA
      await tester.tap(find.text('Bayar Lunas (100%)'));
      await tester.pump();

      // Field has the full remaining amount
      expect(find.text('800.000'), findsOneWidget);
    });
  });

  group('InvoiceReconciliationDialog Widget Tests', () {
    testWidgets('renders reconciliation dialog with products and calculates sold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => InvoiceReconciliationDialog.show(
                      context: context,
                      invoice: dummyInvoice,
                    ),
                    child: const Text('Buka Reconcile'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Reconcile'));
      await tester.pumpAndSettle();

      expect(find.text('Rekonsiliasi Titip Jual'), findsOneWidget);
      expect(find.text('Keripik Pisang 250g'), findsOneWidget);
      expect(find.text('Terkirim: 50 pcs'), findsOneWidget);
      expect(find.text('Sisa Etalase'), findsOneWidget);
      expect(find.text('Rusak / BS'), findsOneWidget);
      expect(find.text('Retur Fisik'), findsOneWidget);
      expect(find.text('50 pcs'), findsOneWidget); // sold = 50 - 0 - 0 - 0
    });
  });

  group('Invoice Date Parsing Tests', () {
    test('InvoiceModel parses ISO8601 timestamp string cleanly without time part', () {
      const timestampInvoice = InvoiceModel(
        id: 1,
        invoiceNumber: 'INV-001',
        invoiceDate: '2026-10-09T00:00:00.000000Z',
        dueDate: '2026-10-23 15:30:00',
        status: 'belum_dibayar',
        statusLabel: 'Belum Dibayar',
      );

      expect(timestampInvoice.parsedInvoiceDate, isNotNull);
      expect(timestampInvoice.parsedInvoiceDate!.year, equals(2026));
      expect(timestampInvoice.parsedInvoiceDate!.month, equals(10));
      expect(timestampInvoice.parsedInvoiceDate!.day, equals(9));

      expect(timestampInvoice.parsedDueDate, isNotNull);
      expect(timestampInvoice.parsedDueDate!.year, equals(2026));
      expect(timestampInvoice.parsedDueDate!.month, equals(10));
      expect(timestampInvoice.parsedDueDate!.day, equals(23));

      expect(timestampInvoice.simpleInvoiceDate, equals('2026-10-09'));
      expect(timestampInvoice.simpleDueDate, equals('2026-10-23'));
      expect(timestampInvoice.simpleInvoiceDate.contains('T'), isFalse);
      expect(timestampInvoice.simpleDueDate.contains('15:30:00'), isFalse);
    });
  });
}
