import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_halala_food/core/widgets/widgets.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:android_halala_food/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:android_halala_food/features/delivery/presentation/viewmodels/delivery_viewmodel.dart';
import 'package:android_halala_food/features/delivery/presentation/views/delivery_screen.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/data/repositories/invoice_repository_impl.dart';
import 'package:android_halala_food/features/invoice/domain/repositories/invoice_repository.dart';
import 'package:android_halala_food/features/invoice/presentation/viewmodels/invoice_viewmodel.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_screen.dart';

class MockDeliveryRepository implements DeliveryRepository {
  String? lastRequestedDate;
  int getDeliveriesCallCount = 0;

  @override
  Future<DeliveryListResult> getDeliveries({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? route,
    String? date,
    int? courierId,
  }) async {
    getDeliveriesCallCount++;
    lastRequestedDate = date;
    return DeliveryListResult(
      deliveries: [
        DeliveryModel(
          id: 1,
          deliveryNumber: 'SJ-20261013-001',
          deliveryDate: '2026-10-13',
          storeId: 10,
          status: 'diproses',
          statusLabel: 'Menunggu Pengambilan',
          store: const DeliveryStoreModel(
            id: 10,
            name: 'Toko Berkah',
            route: 'Rute Utara',
          ),
          items: const [],
        ),
      ],
      total: 1,
      currentPage: 1,
      lastPage: 1,
      statusCounts: {'all': 1, 'diproses': 1, 'dikirim': 0, 'selesai': 0, 'dibatalkan': 0},
      routes: ['Rute Utara', 'Rute Selatan'],
      isCourier: false,
    );
  }

  @override
  Future<DeliveryOptionsModel> getOptions() async => const DeliveryOptionsModel(
        routes: ['Rute Utara', 'Rute Selatan'],
        couriers: [],
        stores: [],
        products: [],
      );

  @override
  Future<DeliveryModel> getDeliveryDetail(int id) async => throw UnimplementedError();
  @override
  Future<DeliveryModel> createDelivery(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<DeliveryModel> updateDelivery(int id, Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<void> deleteDelivery(int id) async {}
  @override
  Future<DeliveryModel> dispatchDelivery(int id) async => throw UnimplementedError();
  @override
  Future<DeliveryModel> completeDelivery(int id, Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<DeliveryModel> cancelDelivery(int id) async => throw UnimplementedError();
  @override
  Future<void> watchDelivery(int id) async {}
  @override
  Future<void> unwatchDelivery(int id) async {}
  @override
  Future<void> updateDeliveryLocation(int id, {required double latitude, required double longitude, double? heading, double? speed}) async {}
}

class MockInvoiceRepository implements InvoiceRepository {
  String? lastRequestedDate;
  int getInvoicesCallCount = 0;

  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
    String? route,
  }) async {
    getInvoicesCallCount++;
    lastRequestedDate = invoiceDate;
    return const InvoiceListResult(
      invoices: [
        InvoiceModel(
          id: 1,
          invoiceNumber: 'INV-20261013-001',
          invoiceDate: '2026-10-13',
          totalAmount: 500000,
          paidAmount: 0,
          remainingBalance: 500000,
          status: 'belum_dibayar',
          statusLabel: 'Belum Dibayar',
          store: InvoiceStoreModel(
            id: 10,
            name: 'Toko Berkah',
            route: 'Rute Utara',
          ),
          items: [],
          payments: [],
        ),
      ],
      hasMore: false,
      total: 1,
      currentPage: 1,
      lastPage: 1,
      statusCounts: {'all': 1, 'belum_dibayar': 1, 'sebagian': 0, 'lunas': 0, 'overdue': 0, 'dibatalkan': 0},
      stores: [
        InvoiceStoreModel(id: 10, name: 'Toko Berkah', route: 'Rute Utara'),
      ],
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) async => throw UnimplementedError();
  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async => throw UnimplementedError();
  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async => throw UnimplementedError();
  @override
  Future<InvoiceModel> updateInvoice(int id, Map<String, dynamic> payload) async => throw UnimplementedError();
  @override
  Future<InvoiceModel> cancelInvoice(int id) async => throw UnimplementedError();
  @override
  Future<void> deleteInvoice(int id) async {}
  @override
  Future<InvoiceModel> recordPayment(int id, Map<String, dynamic> payload) async => throw UnimplementedError();
  @override
  Future<InvoiceModel> deletePayment(int invoiceId, int paymentId) async => throw UnimplementedError();
  @override
  Future<InvoiceModel> reconcileInvoice(int id, List<Map<String, dynamic>> items) async => throw UnimplementedError();
}

class FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      user: UserModel(
        id: 1,
        name: 'Manager User',
        email: 'manager@halalafood.com',
        roles: const ['manager'],
        permissions: const ['pengantaran-view', 'faktur-view'],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('AppFilterDatePicker Widget Tests', () {
    testWidgets('displays placeholder "Pilih Tanggal" and calendar icon when selectedDate is null', (tester) async {
      DateTime? chosenDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFilterDatePicker(
              selectedDate: null,
              placeholder: 'Pilih Tanggal',
              onDateSelected: (date) {
                chosenDate = date;
              },
            ),
          ),
        ),
      );

      expect(find.text('Pilih Tanggal'), findsOneWidget);
      expect(find.byIcon(TablerIcons.calendar), findsOneWidget);
      expect(find.byIcon(TablerIcons.x), findsNothing);
      expect(chosenDate, isNull);
    });

    testWidgets('displays formatted date and clear icon when selectedDate is set, and clears on tap', (tester) async {
      DateTime? chosenDate = DateTime(2026, 10, 13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppFilterDatePicker(
                  selectedDate: chosenDate,
                  placeholder: 'Pilih Tanggal',
                  onDateSelected: (date) {
                    setState(() {
                      chosenDate = date;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('13 Okt 2026'), findsOneWidget);
      expect(find.byIcon(TablerIcons.x), findsOneWidget);

      // Tap clear icon
      await tester.tap(find.byIcon(TablerIcons.x));
      await tester.pumpAndSettle();

      expect(chosenDate, isNull);
      expect(find.text('Pilih Tanggal'), findsOneWidget);
    });
  });

  group('DeliveryScreen 1-Row Filter Integration Tests', () {
    testWidgets('renders route filter and date picker in 1 row with initial null date', (tester) async {
      final mockRepo = MockDeliveryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(mockRepo),
            authViewModelProvider.overrideWith(FakeAuthViewModel.new),
          ],
          child: const MaterialApp(
            home: DeliveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check date picker is rendered with "Pilih Tanggal"
      expect(find.text('Pilih Tanggal'), findsOneWidget);
      expect(find.text('Semua Rute'), findsOneWidget);

      // Check they are siblings in the same Row
      final rowFinder = find.ancestor(
        of: find.byType(AppFilterDatePicker),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);

      // Verify that initial API call was made with date = null
      expect(mockRepo.lastRequestedDate, isNull);
      expect(find.text('SJ-20261013-001'), findsOneWidget);
    });

    testWidgets('filtering by date in DeliveryViewModel passes yyyy-MM-dd to repository', (tester) async {
      final mockRepo = MockDeliveryRepository();
      late WidgetRef refContainer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(mockRepo),
            authViewModelProvider.overrideWith(FakeAuthViewModel.new),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                refContainer = ref;
                return const DeliveryScreen();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(mockRepo.lastRequestedDate, isNull);

      // Set date filter to 2026-10-13
      refContainer.read(deliveryViewModelProvider.notifier).setDateFilter(DateTime(2026, 10, 13));
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedDate, '2026-10-13');

      // Clear date filter
      refContainer.read(deliveryViewModelProvider.notifier).setDateFilter(null);
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedDate, isNull);
    });
  });

  group('InvoiceScreen 1-Row Filter Integration Tests', () {
    testWidgets('renders store filter and date picker in 1 row with initial null date', (tester) async {
      final mockRepo = MockInvoiceRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(mockRepo),
            authViewModelProvider.overrideWith(FakeAuthViewModel.new),
          ],
          child: const MaterialApp(
            home: InvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check date picker is rendered with "Pilih Tanggal"
      expect(find.text('Pilih Tanggal'), findsOneWidget);
      expect(find.text('Semua Toko'), findsOneWidget);

      // Check they are siblings in the same Row
      final rowFinder = find.ancestor(
        of: find.byType(AppFilterDatePicker),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);

      // Verify that initial API call was made with invoiceDate = null
      expect(mockRepo.lastRequestedDate, isNull);
      expect(find.text('INV-20261013-001'), findsOneWidget);
    });

    testWidgets('filtering by date in InvoiceViewModel passes yyyy-MM-dd to repository', (tester) async {
      final mockRepo = MockInvoiceRepository();
      late WidgetRef refContainer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(mockRepo),
            authViewModelProvider.overrideWith(FakeAuthViewModel.new),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                refContainer = ref;
                return const InvoiceScreen();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(mockRepo.lastRequestedDate, isNull);

      // Set date filter to 2026-10-13
      refContainer.read(invoiceViewModelProvider.notifier).setDateFilter(DateTime(2026, 10, 13));
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedDate, '2026-10-13');

      // Clear date filter
      refContainer.read(invoiceViewModelProvider.notifier).setDateFilter(null);
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedDate, isNull);
    });
  });
}
