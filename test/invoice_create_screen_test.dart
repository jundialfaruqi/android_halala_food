import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/widgets.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/data/repositories/invoice_repository_impl.dart';
import 'package:android_halala_food/features/invoice/domain/repositories/invoice_repository.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_create_screen.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_dropdown_search_field.dart';

class MockInvoiceCreateRepository implements InvoiceRepository {
  bool createCalled = false;
  Map<String, dynamic>? lastPayload;

  final InvoiceCreateOptionsModel dummyOptions = const InvoiceCreateOptionsModel(
    nextInvoiceNumber: 'INV-20261009-0001',
    defaultInvoiceDate: '2026-10-09',
    defaultDueDate: '2026-10-23',
    stores: [
      InvoiceStoreModel(
        id: 1,
        name: 'Toko Berkah Utama',
        route: 'Rute Utara',
      ),
      InvoiceStoreModel(
        id: 2,
        name: 'Toko Sumber Rejeki',
        route: 'Rute Selatan',
      ),
    ],
    products: [
      ProductOptionModel(
        id: 101,
        name: 'Keripik Tempe Pcs',
        unit: 'pcs',
        stockReady: 50,
        consignmentPrice: 15000,
        depositPrice: 20000,
      ),
      ProductOptionModel(
        id: 102,
        name: 'Kue Kacang Halala',
        unit: 'box',
        stockReady: 30,
        consignmentPrice: 25000,
        depositPrice: 30000,
      ),
    ],
    deliveries: [
      InvoiceDeliveryOptionModel(
        id: 501,
        deliveryNumber: 'SJ-20261009-001',
        storeId: 1,
        deliveryDate: '2026-10-09',
        items: [
          InvoiceDeliveryItemOptionModel(
            productId: 101,
            productName: 'Keripik Tempe Pcs',
            productUnit: 'pcs',
            quantity: 10,
            unitPrice: 15000,
            subtotal: 150000,
          ),
        ],
      ),
    ],
  );

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
  Future<InvoiceModel> getInvoiceDetail(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async {
    return dummyOptions;
  }

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    createCalled = true;
    lastPayload = payload;
    return const InvoiceModel(
      id: 99,
      invoiceNumber: 'INV-20261009-0001',
      totalAmount: 150000,
      paidAmount: 0,
      remainingBalance: 150000,
      status: 'belum_dibayar',
      statusLabel: 'Belum Dibayar',
    );
  }
}

class FakeAuthViewModelWithManagerRole extends AuthViewModel {
  final List<String> permissions;
  final List<String> roles;

  FakeAuthViewModelWithManagerRole({
    this.permissions = const ['faktur-create', 'faktur-view'],
    this.roles = const ['manager'],
  });

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Manager Operasional',
        email: 'manager@halala-food.id',
        roles: roles,
        permissions: permissions,
      ),
    );
  }
}

void main() {
  testWidgets('InvoiceCreateScreen merender seluruh Core Widget komponen lengkap',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockInvoiceCreateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider
              .overrideWith(() => FakeAuthViewModelWithManagerRole()),
        ],
        child: const MaterialApp(
          home: InvoiceCreateScreen(),
        ),
      ),
    );

    // 1. Verifikasi ShimmerLoading muncul saat awal sebelum data selesai dimuat
    expect(find.byType(ShimmerLoading), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Tunggu asynchronous loadOptions selesai
    await tester.pumpAndSettle();

    // 2. Verifikasi AppStatusBar & AppScaffold & AppAppBar
    expect(find.byType(AppStatusBar), findsWidgets);
    expect(find.byType(AppScaffold), findsOneWidget);
    expect(find.byType(AppAppBar), findsOneWidget);
    expect(find.text('Buat Faktur Baru'), findsOneWidget);

    // 3. Verifikasi AppDynamicValidationForm
    expect(find.byType(AppDynamicValidationForm), findsOneWidget);

    // 4. Verifikasi Sub Form Titles tanpa wrapper card
    expect(find.text('Informasi Faktur'), findsOneWidget);
    expect(find.text('Tujuan Penagihan'), findsOneWidget);
    expect(find.text('Rincian Produk Tertagih'), findsOneWidget);
    expect(find.text('Ringkasan Keuangan & Catatan'), findsOneWidget);

    // 5. Verifikasi UI/UX Muatan Barang Jadi (Empty State saat awal)
    expect(find.byType(AppEmptyCard), findsOneWidget);
    expect(find.text('Belum Ada Muatan Produk'), findsOneWidget);
    expect(find.text('Tambahkan Produk Jadi'), findsOneWidget);

    // 6. Verifikasi AppTextField (Nomor Faktur, Tanggal Faktur, Jatuh Tempo, Diskon, Catatan)
    expect(find.byType(AppTextField), findsWidgets);
    expect(find.text('INV-20261009-0001'), findsOneWidget);
    expect(find.text('2026-10-09'), findsWidgets);

    // 7. Verifikasi StoreDropdownSearchField untuk Toko Mitra dan AppMenuSelect untuk Surat Jalan
    expect(find.byType(StoreDropdownSearchField), findsOneWidget);
    expect(find.byType(AppMenuSelect<int?>), findsOneWidget);

    // 8. Verifikasi AppBottomActionBar dengan tombol Batal dan Simpan Faktur
    expect(find.byType(AppBottomActionBar), findsOneWidget);
    expect(find.text('Simpan Faktur'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });

  testWidgets(
      'InvoiceCreateScreen menolak user tanpa izin faktur-create',
      (tester) async {
    final mockRepo = MockInvoiceCreateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModelWithManagerRole(
              roles: ['kurir'],
              permissions: ['faktur-view'],
            ),
          ),
        ],
        child: const MaterialApp(
          home: InvoiceCreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pastikan tombol simpan di bottom bar tidak muncul dan pesan ditolak tampil
    expect(find.byType(AppBottomActionBar), findsNothing);
    expect(
      find.text(
        'Anda tidak memiliki hak akses (faktur-create) untuk membuat faktur tagihan baru.',
      ),
      findsOneWidget,
    );
  });

  test('InvoiceDeliveryOptionModel mem-parse keterangan tanggal dan waktu surat jalan dengan benar', () {
    // 1. Tanggal standar yyyy-MM-dd
    const deliveryDateOnly = InvoiceDeliveryOptionModel(
      id: 1,
      deliveryNumber: 'SJ-001',
      storeId: 1,
      deliveryDate: '2026-10-09',
    );
    expect(deliveryDateOnly.formattedDeliveryDate, '9 Okt 2026');

    // 2. Tanggal dengan timestamp jam dan menit
    const deliveryWithTime = InvoiceDeliveryOptionModel(
      id: 2,
      deliveryNumber: 'SJ-002',
      storeId: 1,
      deliveryDate: '2026-10-09 14:30:00',
    );
    expect(deliveryWithTime.formattedDeliveryDate, '9 Okt 2026, 14:30');

    // 3. Tanggal yang sudah diformat dari backend
    const deliveryPreformatted = InvoiceDeliveryOptionModel(
      id: 3,
      deliveryNumber: 'SJ-003',
      storeId: 1,
      deliveryDate: '2026-10-09',
      deliveryDateFormatted: '09 Okt 2026',
    );
    expect(deliveryPreformatted.formattedDeliveryDate, '09 Okt 2026');
  });
}
