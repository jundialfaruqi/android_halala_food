import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_text_field.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_edit_screen.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';

class MockProductRepoForEditTest implements ProductRepository {
  Map<String, dynamic>? lastUpdatedPayload;
  int? lastUpdatedId;

  final List<ProductUnitModel> dummyUnits = const [
    ProductUnitModel(id: 1, name: 'Pouch', shortName: 'Pch'),
    ProductUnitModel(id: 2, name: 'Toples', shortName: 'Tpl'),
  ];

  final ProductModel dummyProduct = const ProductModel(
    id: 10,
    name: 'Marie Wijen Halala 150g',
    unitId: 1,
    unitName: 'Pouch',
    unitShort: 'Pch',
    consignmentPrice: 12000,
    consignmentPriceFormatted: 'Rp 12.000',
    retailPrice: 15000,
    retailPriceFormatted: 'Rp 15.000',
    stockReady: 30,
    description: 'Kemasan pouch 150 gram renyah gurih',
    isActive: true,
  );

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) async {
    return ProductListResult(
      products: [dummyProduct],
      pagination: const ProductPaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 1,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<ProductUnitModel>> getUnits() async => dummyUnits;

  @override
  Future<ProductModel> getProductDetail(int id) async => dummyProduct;

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async => dummyProduct;

  @override
  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async {
    lastUpdatedId = id;
    lastUpdatedPayload = data;
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

class FakeAuthViewModelWithPermission extends AuthViewModel {
  final List<String> permissions;

  FakeAuthViewModelWithPermission({
    this.permissions = const ['produk-edit', 'produk-view'],
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
        roles: ['manager'],
      ),
    );
  }
}

void main() {
  testWidgets('Edit button is visible on ProductScreen when user has produk-edit permission', (tester) async {
    final mockRepo = MockProductRepoForEditTest();
    final authVm = FakeAuthViewModelWithPermission(permissions: ['produk-edit', 'produk-view']);

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

    expect(find.byIcon(Icons.edit, skipOffstage: false), findsNothing);
    // Finds pencil edit icon
    expect(find.byType(InkWell), findsWidgets);
    expect(find.text('Marie Wijen Halala 150g'), findsOneWidget);
  });

  testWidgets('ProductEditScreen pre-fills existing product data in all fields', (tester) async {
    final mockRepo = MockProductRepoForEditTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: MaterialApp(
          home: ProductEditScreen(product: mockRepo.dummyProduct),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Produk Jadi'), findsOneWidget);
    expect(find.text('Marie Wijen Halala 150g'), findsOneWidget);
    expect(find.widgetWithText(AppTextField, 'Harga Setor Konsinyasi (Rp) *'), findsOneWidget);
    expect(find.widgetWithText(AppTextField, 'Harga Jual Eceran Toko (Rp) *'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Kemasan pouch 150 gram renyah gurih'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });

  testWidgets('ProductEditScreen submits updated data when Save button tapped', (tester) async {
    final mockRepo = MockProductRepoForEditTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: MaterialApp(
          home: ProductEditScreen(product: mockRepo.dummyProduct),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clear and enter new name
    final nameField = find.widgetWithText(AppTextField, 'Nama Produk Kemasan *');
    await tester.enterText(nameField, 'Marie Wijen Rasa Pandan 150g');
    await tester.pump();

    // Tap Simpan Perubahan
    final saveButton = find.text('Simpan Perubahan');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(mockRepo.lastUpdatedId, 10);
    expect(mockRepo.lastUpdatedPayload?['name'], 'Marie Wijen Rasa Pandan 150g');
    expect(mockRepo.lastUpdatedPayload?['consignment_price'], 12000.0);
    expect(mockRepo.lastUpdatedPayload?['retail_price'], 15000.0);
  });

  testWidgets('ProductEditScreen clears dynamic validation error on user input', (tester) async {
    final mockRepo = MockProductRepoForEditTest();
    final authVm = FakeAuthViewModelWithPermission();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => authVm),
        ],
        child: MaterialApp(
          home: ProductEditScreen(product: mockRepo.dummyProduct),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Empty the name field and submit
    final nameField = find.widgetWithText(AppTextField, 'Nama Produk Kemasan *');
    await tester.enterText(nameField, '');
    await tester.pump();

    final saveButton = find.text('Simpan Perubahan');
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsOneWidget);

    // Type text, validation error should immediately disappear dynamically
    await tester.enterText(nameField, 'Nama Baru');
    await tester.pump();

    expect(find.text('Nama produk kemasan wajib diisi.'), findsNothing);
  });
}
