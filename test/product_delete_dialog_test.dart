import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_confirm_dialog.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';

class MockProductRepoForDeleteTest implements ProductRepository {
  int? deletedProductId;

  final ProductModel dummyProduct = const ProductModel(
    id: 99,
    name: 'Keripik Singkong Renyah',
    unitId: 1,
    unitName: 'Bungkus',
    unitShort: 'Bks',
    consignmentPrice: 7000,
    consignmentPriceFormatted: 'Rp 7.000',
    retailPrice: 9000,
    retailPriceFormatted: 'Rp 9.000',
    stockReady: 40,
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
      products: deletedProductId == dummyProduct.id ? [] : [dummyProduct],
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
  Future<ProductModel> createProduct(Map<String, dynamic> data) async => dummyProduct;

  @override
  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async => dummyProduct;

  @override
  Future<void> deleteProduct(int id) async {
    deletedProductId = id;
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
  testWidgets('Card footer shows Edit and Hapus ghost buttons when user has permissions', (tester) async {
    final mockRepo = MockProductRepoForDeleteTest();
    final authVm = FakeAuthViewModelWithPermissions(
      permissions: ['produk-view', 'produk-edit', 'produk-delete'],
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

    expect(find.text('Keripik Singkong Renyah'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
  });

  testWidgets('Tapping Hapus opens AppConfirmDialog and confirming deletes product with success snackbar', (tester) async {
    final mockRepo = MockProductRepoForDeleteTest();
    final authVm = FakeAuthViewModelWithPermissions(
      permissions: ['produk-view', 'produk-edit', 'produk-delete'],
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

    // Tap Hapus button
    await tester.ensureVisible(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    // Verify AppConfirmDialog appears
    expect(find.byType(AppConfirmDialog), findsOneWidget);
    expect(find.text('Hapus Produk'), findsOneWidget);
    expect(
      find.text('Apakah Anda yakin ingin menghapus produk "Keripik Singkong Renyah"? Tindakan ini tidak dapat dibatalkan.'),
      findsOneWidget,
    );

    // Tap confirm button 'Hapus' inside dialog
    // There are 2 'Hapus' texts now: one on footer button, one on confirm button inside dialog.
    // The one in dialog is within the AppConfirmDialog.
    final dialogHapusButton = find.descendant(
      of: find.byType(AppConfirmDialog),
      matching: find.text('Hapus'),
    );
    await tester.tap(dialogHapusButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify product was deleted
    expect(mockRepo.deletedProductId, 99);

    // Verify AppSnackBar success is visible
    expect(
      find.text('Produk "Keripik Singkong Renyah" berhasil dihapus.'),
      findsOneWidget,
    );
  });

  testWidgets('Tapping Batal in AppConfirmDialog cancels deletion', (tester) async {
    final mockRepo = MockProductRepoForDeleteTest();
    final authVm = FakeAuthViewModelWithPermissions(
      permissions: ['produk-view', 'produk-edit', 'produk-delete'],
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

    // Tap Hapus button
    await tester.ensureVisible(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    // Tap Batal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Dialog closed and not deleted
    expect(find.byType(AppConfirmDialog), findsNothing);
    expect(mockRepo.deletedProductId, isNull);
  });
}
