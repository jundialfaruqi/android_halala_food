import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:android_halala_food/core/widgets/widgets.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/data/repositories/invoice_repository_impl.dart';
import 'package:android_halala_food/features/invoice/domain/repositories/invoice_repository.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_detail_sheet.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_screen.dart';

class MockInvoiceRepository implements InvoiceRepository {
  final List<InvoiceModel> dummyInvoices = [
    const InvoiceModel(
      id: 1,
      invoiceNumber: 'INV-20261008-001',
      invoiceDate: '2026-10-08',
      dueDate: '2026-10-15',
      totalAmount: 1500000,
      paidAmount: 500000,
      remainingBalance: 1000000,
      status: 'sebagian',
      statusLabel: 'Dibayar Sebagian',
      store: InvoiceStoreModel(
        id: 10,
        name: 'Toko Berkah Abadi',
        route: 'Rute Selatan',
        address: 'Jl. Malioboro No. 12',
      ),
      items: [
        InvoiceItemModel(
          id: 1,
          invoiceId: 1,
          productId: 101,
          productName: 'Keripik Tempe Pcs',
          productUnit: 'pcs',
          quantity: 100,
          unitPrice: 15000,
          subtotal: 1500000,
        ),
      ],
      payments: [
        InvoicePaymentModel(
          id: 1,
          invoiceId: 1,
          amount: 500000,
          paymentDate: '2026-10-08T00:00:00.000000Z',
          paymentMethod: 'tunai',
          userName: 'Kasir Utama',
        ),
      ],
    ),
  ];

  final List<InvoiceStoreModel> dummyStores = const [
    InvoiceStoreModel(
      id: 10,
      name: 'Toko Berkah Abadi',
      route: 'Rute Selatan',
    ),
  ];

  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
  }) async {
    return InvoiceListResult(
      invoices: dummyInvoices,
      hasMore: false,
      total: dummyInvoices.length,
      currentPage: 1,
      lastPage: 1,
      statusCounts: {
        'all': 1,
        'belum_dibayar': 0,
        'sebagian': 1,
        'lunas': 0,
        'overdue': 0,
        'dibatalkan': 0,
      },
      stores: dummyStores,
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) async {
    return dummyInvoices.first;
  }

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async {
    return const InvoiceCreateOptionsModel();
  }

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    return dummyInvoices.first;
  }

  @override
  Future<InvoiceModel> updateInvoice(
      int id, Map<String, dynamic> payload) async {
    return dummyInvoices.first;
  }

  @override
  Future<InvoiceModel> cancelInvoice(int id) async {
    return dummyInvoices.first;
  }

  @override
  Future<void> deleteInvoice(int id) async {}

  @override
  Future<InvoiceModel> recordPayment(
      int id, Map<String, dynamic> payload) async {
    return dummyInvoices.first;
  }

  @override
  Future<InvoiceModel> deletePayment(int invoiceId, int paymentId) async {
    return dummyInvoices.first;
  }

  @override
  Future<InvoiceModel> reconcileInvoice(
      int id, List<Map<String, dynamic>> items) async {
    return dummyInvoices.first;
  }
}

class FakeAuthViewModelWithFakturPermissions extends AuthViewModel {
  final List<String> permissions;
  final List<String> roles;

  FakeAuthViewModelWithFakturPermissions({
    this.permissions = const ['faktur-view', 'faktur-create'],
    this.roles = const ['dev'],
  });

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Admin Tester',
        email: 'admin@halala-food.id',
        roles: roles,
        permissions: permissions,
      ),
    );
  }
}

void main() {
  testWidgets(
      'InvoiceScreen renders with AppStatusBar, AppScaffold, AppCard, and AppFloatingActionButton',
      (tester) async {
    final mockRepo = MockInvoiceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModelWithFakturPermissions(),
          ),
        ],
        child: const MaterialApp(
          home: InvoiceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Komponen 1: AppStatusBar
    expect(find.byType(AppStatusBar), findsWidgets);

    // Verify Komponen 2: AppScaffold
    expect(find.byType(AppScaffold), findsOneWidget);

    // Verify Komponen 3: AppCard
    expect(find.byType(AppCard), findsWidgets);

    // Verify Komponen 4: AppFloatingActionButton (FAB Button)
    expect(find.byType(AppFloatingActionButton), findsOneWidget);

    // Verify Text invoice data
    expect(find.text('INV-20261008-001'), findsOneWidget);
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('Dibayar Sebagian'), findsOneWidget);
    expect(find.text('Faktur & Piutang Toko'), findsOneWidget);

    // Verify icons on invoice number and store name are removed from card
    expect(find.byIcon(TablerIcons.building_store), findsNothing);
  });

  testWidgets(
      'InvoiceScreen hides FAB button when user does not have faktur-create permission',
      (tester) async {
    final mockRepo = MockInvoiceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModelWithFakturPermissions(
              permissions: const ['faktur-view'],
              roles: const ['kurir'],
            ),
          ),
        ],
        child: const MaterialApp(
          home: InvoiceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Should NOT have FAB button
    expect(find.byType(AppFloatingActionButton), findsNothing);

    // But should still display the invoice list
    expect(find.text('INV-20261008-001'), findsOneWidget);
  });

  testWidgets('Tapping invoice AppCard opens InvoiceDetailSheet',
      (tester) async {
    final mockRepo = MockInvoiceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModelWithFakturPermissions(),
          ),
        ],
        child: const MaterialApp(
          home: InvoiceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on the invoice card
    await tester.tap(find.text('INV-20261008-001'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Bottom sheet is displayed
    expect(find.byType(InvoiceDetailSheet), findsOneWidget);
    expect(find.text('Ringkasan Tagihan'), findsOneWidget);
    expect(find.text('Keripik Tempe Pcs'), findsOneWidget);
    expect(find.text('Riwayat Pembayaran'), findsOneWidget);
    expect(find.text('Tunai (Cash)'), findsOneWidget);
    expect(find.text('8 Okt 2026'), findsWidgets);
    expect(find.text('2026-10-08T00:00:00.000000Z'), findsNothing);

    // Verify thousand separator on product item prices
    expect(find.text('100 pcs @ Rp 15.000'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsWidgets);
    expect(find.text('100 pcs @ Rp 15000'), findsNothing);
    expect(find.text('Rp 1500000'), findsNothing);

    // Verify invoice icon in detail sheet is black
    final invoiceIcon =
        tester.widget<Icon>(find.byIcon(TablerIcons.file_invoice));
    expect(invoiceIcon.color, equals(Colors.black));
  });
}
