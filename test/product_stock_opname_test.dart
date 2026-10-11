import 'package:android_halala_food/core/widgets/widgets.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';

class MockProductRepoForOpnameTest implements ProductRepository {
  int? adjustedId;
  Map<String, dynamic>? adjustedPayload;

  ProductModel dummyProduct = const ProductModel(
    id: 10,
    name: 'Marie Wijen Halala',
    unitId: 1,
    unitName: 'Bungkus',
    unitShort: 'Bks',
    consignmentPrice: 10000,
    consignmentPriceFormatted: 'Rp 10.000',
    retailPrice: 12000,
    retailPriceFormatted: 'Rp 12.000',
    stockReady: 25,
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
  Future<List<ProductUnitModel>> getUnits() async => [];

  @override
  Future<ProductModel> getProductDetail(int id) async => dummyProduct;

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async =>
      dummyProduct;

  @override
  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async =>
      dummyProduct;

  @override
  Future<void> deleteProduct(int id) async {}

  @override
  Future<ProductModel> adjustStock(int id, Map<String, dynamic> data) async {
    adjustedId = id;
    adjustedPayload = data;
    final newStock = data['physical_stock'] as int? ?? dummyProduct.stockReady;
    dummyProduct = ProductModel(
      id: dummyProduct.id,
      name: dummyProduct.name,
      unitId: dummyProduct.unitId,
      unitName: dummyProduct.unitName,
      unitShort: dummyProduct.unitShort,
      consignmentPrice: dummyProduct.consignmentPrice,
      consignmentPriceFormatted: dummyProduct.consignmentPriceFormatted,
      retailPrice: dummyProduct.retailPrice,
      retailPriceFormatted: dummyProduct.retailPriceFormatted,
      stockReady: newStock,
      isActive: dummyProduct.isActive,
    );
    return dummyProduct;
  }
}

class FakeAuthViewModelWithPermissions extends AuthViewModel {
  final List<String> permissions;

  FakeAuthViewModelWithPermissions({required this.permissions});

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
  testWidgets('Opname button is visible when user has produk-edit permission',
      (tester) async {
    final mockRepo = MockProductRepoForOpnameTest();
    final authVm = FakeAuthViewModelWithPermissions(
      permissions: ['produk-view', 'produk-edit'],
    );

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

    expect(find.text('Marie Wijen Halala'), findsOneWidget);
    expect(find.byIcon(TablerIcons.clipboard_check), findsOneWidget);
    expect(find.text('Opname'), findsOneWidget);
  });

  testWidgets(
      'Tapping Opname button opens bottom sheet, calculates diff, and saves adjustment',
      (tester) async {
    final mockRepo = MockProductRepoForOpnameTest();
    final authVm = FakeAuthViewModelWithPermissions(
      permissions: ['produk-view', 'produk-edit'],
    );

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

    // Scroll to and tap Opname button
    await tester.ensureVisible(find.byIcon(TablerIcons.clipboard_check));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerIcons.clipboard_check), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Bottom Sheet elements
    expect(find.text('Stock Opname Produk Jadi'), findsOneWidget);
    expect(find.text('Stok Sistem:'), findsOneWidget);
    expect(find.text('25 Bks'), findsNWidgets(2));

    // Initial diff is 0 Bks
    expect(find.text('Selisih: 0 Bks'), findsOneWidget);

    // Enter new physical stock (e.g., 20)
    final physicalField = find.widgetWithText(AppTextField, 'Stok Fisik Riil *');
    expect(physicalField, findsOneWidget);
    await tester.enterText(physicalField, '20');
    await tester.pumpAndSettle();

    // Diff should now be -5 Bks
    expect(find.text('Selisih: -5 Bks'), findsOneWidget);

    // Enter reason
    final reasonField =
        find.widgetWithText(AppTextField, 'Alasan / Keterangan Penyesuaian');
    await tester.enterText(reasonField, 'Bocor kemasan');
    await tester.pumpAndSettle();

    // Tap Simpan Opname
    await tester.tap(find.text('Simpan Opname'));
    await tester.pumpAndSettle();

    // Verify adjustStock was called on repo
    expect(mockRepo.adjustedId, 10);
    expect(mockRepo.adjustedPayload?['physical_stock'], 20);
    expect(mockRepo.adjustedPayload?['reason'], 'Bocor kemasan');

    // Bottom sheet is closed
    expect(find.text('Stock Opname Produk Jadi'), findsNothing);
  });
}
