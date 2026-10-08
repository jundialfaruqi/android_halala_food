import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_create_screen.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';

class FakeAuthViewModelWithPermission extends AuthViewModel {
  final List<String> permissions;
  final List<String> roles;

  FakeAuthViewModelWithPermission({
    this.permissions = const ['produk-create', 'produk-view'],
    this.roles = const ['manager'],
  });

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Manager Test',
        email: 'manager@halala-food.id',
        permissions: permissions,
        roles: roles,
      ),
    );
  }
}

class MockProductRepoForCreateTest implements ProductRepository {
  Map<String, dynamic>? lastCreatedPayload;

  final List<ProductUnitModel> dummyUnits = const [
    ProductUnitModel(id: 1, name: 'Pouch', shortName: 'Pch'),
    ProductUnitModel(id: 2, name: 'Toples', shortName: 'Tpl'),
  ];

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) async {
    return ProductListResult(
      products: [],
      pagination: const ProductPaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 0,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<ProductUnitModel>> getUnits() async => dummyUnits;

  @override
  Future<ProductModel> getProductDetail(int id) async => const ProductModel(
        id: 1,
        name: 'Dummy',
        consignmentPrice: 10000,
        consignmentPriceFormatted: 'Rp 10.000',
        retailPrice: 12000,
        retailPriceFormatted: 'Rp 12.000',
        stockReady: 5,
      );

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    lastCreatedPayload = data;
    return ProductModel(
      id: 99,
      name: data['name'] ?? '',
      unitId: data['unit_id'],
      consignmentPrice: (data['consignment_price'] as num).toDouble(),
      consignmentPriceFormatted: 'Rp ${data['consignment_price']}',
      retailPrice: (data['retail_price'] as num).toDouble(),
      retailPriceFormatted: 'Rp ${data['retail_price']}',
      stockReady: data['stock_ready'] ?? 0,
      description: data['description'],
      isActive: data['is_active'] ?? true,
    );
  }

  @override
  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async {
    return ProductModel(
      id: id,
      name: data['name'] ?? '',
      unitId: data['unit_id'],
      consignmentPrice: (data['consignment_price'] as num?)?.toDouble() ?? 0.0,
      consignmentPriceFormatted: 'Rp ${data['consignment_price'] ?? 0}',
      retailPrice: (data['retail_price'] as num?)?.toDouble() ?? 0.0,
      retailPriceFormatted: 'Rp ${data['retail_price'] ?? 0}',
      stockReady: data['stock_ready'] ?? 0,
      description: data['description'],
      isActive: data['is_active'] ?? true,
    );
  }

  @override
  Future<void> deleteProduct(int id) async {}
}

void main() {
  testWidgets('FAB Tambah Produk is visible on ProductScreen when user has produk-create permission', (tester) async {
    final mockRepo = MockProductRepoForCreateTest();
    final authVm = FakeAuthViewModelWithPermission(permissions: ['produk-create']);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: const MaterialApp(
          home: ProductScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tambah Produk'), findsWidgets);
  });

  testWidgets('FAB Tambah Produk is NOT visible when user lacks produk-create permission', (tester) async {
    final mockRepo = MockProductRepoForCreateTest();
    final authVm = FakeAuthViewModelWithPermission(permissions: ['produk-view'], roles: []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: const MaterialApp(
          home: ProductScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tambah Produk'), findsNothing);
  });

  testWidgets('ProductCreateScreen renders all form inputs, calculations, and bottom action bar', (tester) async {
    final mockRepo = MockProductRepoForCreateTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: const MaterialApp(
          home: ProductCreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and labels
    expect(find.text('Tambah Produk Baru'), findsOneWidget);
    expect(find.text('Informasi Produk & Harga'), findsOneWidget);
    expect(find.text('Nama Produk Kemasan *'), findsOneWidget);
    expect(find.text('Satuan Kemasan *'), findsOneWidget);
    expect(find.text('Harga Setor Konsinyasi (Rp) *'), findsOneWidget);
    expect(find.text('Harga Jual Eceran Toko (Rp) *'), findsOneWidget);
    expect(find.text('Stok Awal Siap Kirim (Kemasan) *'), findsOneWidget);
    expect(find.text('Produk Aktif'), findsOneWidget);
    expect(find.text('Deskripsi / Keterangan Produk (Opsional)'), findsOneWidget);
    expect(find.text('Foto Produk Kemasan (Opsional)'), findsOneWidget);

    // Bottom action bar
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Simpan Produk'), findsOneWidget);

    // Validation check when pressing Simpan without input
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsOneWidget);

    // Dynamic Validation Clearing: Typing into the field immediately clears the error!
    await tester.enterText(
        find.byType(TextFormField).first, 'Keripik Tempe Renyah');
    await tester.pumpAndSettle();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsNothing);
  });

  testWidgets('AppDynamicValidationForm and AppTextField clear validation errors dynamically', (tester) async {
    final mockRepo = MockProductRepoForCreateTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: const MaterialApp(
          home: ProductCreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Trigger validation error
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsOneWidget);

    // Enter name -> dynamic clearing
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, 'Keripik Wijen');
    await tester.pumpAndSettle();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsNothing);
  });

  testWidgets('ProductCreateScreen shows "Pilih satuan kemasan" placeholder and requires unit selection', (tester) async {
    final mockRepo = MockProductRepoForCreateTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: const MaterialApp(
          home: ProductCreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify placeholder text is "Pilih satuan kemasan"
    expect(find.text('Pilih satuan kemasan'), findsOneWidget);

    // Try saving without selecting unit
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    // Verify required unit error message
    expect(find.text('Pilih satuan kemasan produk.'), findsOneWidget);

    // Tap to open unit picker
    await tester.tap(find.text('Pilih satuan kemasan'));
    await tester.pumpAndSettle();

    // Select 'Pouch'
    await tester.tap(find.text('Pouch'));
    await tester.pumpAndSettle();

    // Verify error is cleared and 'Pouch' is displayed
    expect(find.text('Pilih satuan kemasan produk.'), findsNothing);
    expect(find.text('Pouch (Pch)'), findsOneWidget);
  });
}
