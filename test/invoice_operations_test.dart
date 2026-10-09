import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/data/repositories/invoice_repository_impl.dart';
import 'package:android_halala_food/features/invoice/domain/repositories/invoice_repository.dart';
import 'package:android_halala_food/features/invoice/presentation/utils/invoice_share_helper.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_detail_sheet.dart';
import 'package:android_halala_food/features/invoice/presentation/widgets/invoice_payment_dialog.dart';
import 'package:android_halala_food/features/invoice/presentation/widgets/invoice_reconciliation_dialog.dart';

class _MockInvoiceRepo implements InvoiceRepository {
  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
  }) async {
    return const InvoiceListResult(
      invoices: [],
      hasMore: false,
      total: 0,
      currentPage: 1,
      lastPage: 1,
      statusCounts: {},
      stores: [],
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) async => throw UnimplementedError();

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async =>
      const InvoiceCreateOptionsModel();

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<InvoiceModel> updateInvoice(int id, Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<void> deleteInvoice(int id) async {}

  @override
  Future<InvoiceModel> cancelInvoice(int id) async => throw UnimplementedError();

  @override
  Future<InvoiceModel> recordPayment(int invoiceId, Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<InvoiceModel> deletePayment(int invoiceId, int paymentId) async => throw UnimplementedError();

  @override
  Future<InvoiceModel> reconcileInvoice(int id, List<Map<String, dynamic>> items) async => throw UnimplementedError();
}

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

  group('InvoiceDetailSheet Granular Permissions Tests', () {
    const invoiceWithCourier = InvoiceModel(
      id: 99,
      courierId: 77,
      invoiceNumber: 'INV-20261009-0099',
      invoiceDate: '2026-10-09',
      dueDate: '2026-10-23',
      totalAmount: 1000000,
      paidAmount: 200000,
      remainingBalance: 800000,
      status: 'sebagian',
      statusLabel: 'Dibayar Sebagian',
      store: InvoiceStoreModel(
        id: 5,
        name: 'Toko Sumber Barokah',
      ),
      items: [
        InvoiceItemModel(
          id: 1,
          invoiceId: 99,
          productId: 10,
          productName: 'Keripik Pisang 250g',
          productUnit: 'pcs',
          quantity: 50,
          unitPrice: 20000,
          subtotal: 1000000,
        ),
      ],
      payments: [
        InvoicePaymentModel(
          id: 101,
          invoiceId: 99,
          amount: 200000,
          paymentDate: '2026-10-09',
          paymentMethod: 'tunai',
          userName: 'Kurir Pengantar',
        ),
      ],
    );

    testWidgets(
        'Assigned courier can see Catat Pembayaran and Rekonsiliasi, but cannot see delete payment icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(_MockInvoiceRepo()),
            authViewModelProvider.overrideWith(
              () => _FakeAuthVM(
                user: UserModel(
                  id: 77, // Same as invoice courierId
                  name: 'Ahmad Kurir',
                  email: 'kurir@halala-food.id',
                  roles: const ['kurir'],
                  permissions: const ['faktur-view'], // No faktur-pembayaran-delete
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InvoiceDetailSheet(invoice: invoiceWithCourier),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Catat Pembayaran and Rekonsiliasi buttons ARE visible
      expect(find.text('Catat Pembayaran'), findsOneWidget);
      expect(find.text('Rekonsiliasi'), findsOneWidget);

      // Trash icon for deleting payment history is NOT visible for courier
      expect(find.byIcon(TablerIcons.trash), findsNothing);
    });

    testWidgets(
        'Unassigned courier without permissions cannot see Catat Pembayaran or Rekonsiliasi',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(_MockInvoiceRepo()),
            authViewModelProvider.overrideWith(
              () => _FakeAuthVM(
                user: UserModel(
                  id: 999, // Different from invoice courierId (77)
                  name: 'Kurir Lain',
                  email: 'kurirlain@halala-food.id',
                  roles: const ['kurir'],
                  permissions: const ['faktur-view'], // No payment or reconcile permission
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InvoiceDetailSheet(invoice: invoiceWithCourier),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Buttons are NOT visible
      expect(find.text('Catat Pembayaran'), findsNothing);
      expect(find.text('Rekonsiliasi'), findsNothing);
      expect(find.byIcon(TablerIcons.trash), findsNothing);
    });

    testWidgets(
        'Manager or user with faktur-pembayaran-delete can see delete payment icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(_MockInvoiceRepo()),
            authViewModelProvider.overrideWith(
              () => _FakeAuthVM(
                user: UserModel(
                  id: 1,
                  name: 'Ibu Manager',
                  email: 'manager@halala-food.id',
                  roles: const ['manager'],
                  permissions: const [
                    'faktur-view',
                    'faktur-pembayaran',
                    'faktur-rekonsiliasi',
                    'faktur-pembayaran-delete',
                  ],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InvoiceDetailSheet(invoice: invoiceWithCourier),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All management buttons and trash icon are visible for manager
      expect(find.text('Catat Pembayaran'), findsOneWidget);
      expect(find.text('Rekonsiliasi'), findsOneWidget);
      expect(find.byIcon(TablerIcons.trash), findsOneWidget);
    });
  });
}

class _FakeAuthVM extends AuthViewModel {
  final UserModel user;

  _FakeAuthVM({required this.user});

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }
}

