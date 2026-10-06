import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/shimmer_loading.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';

class DelayedProductRepository implements ProductRepository {
  final Completer<ProductListResult> productsCompleter = Completer<ProductListResult>();

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) {
    return productsCompleter.future;
  }

  @override
  Future<List<ProductUnitModel>> getUnits() async {
    return const [
      ProductUnitModel(id: 1, name: 'Pouch', shortName: 'Pch'),
    ];
  }

  @override
  Future<ProductModel> getProductDetail(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<ProductModel> updateProduct(int id, Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProduct(int id) async {
    throw UnimplementedError();
  }
}

class FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Admin Test',
        email: 'admin@halala-food.id',
        permissions: ['produk-view'],
        roles: ['admin'],
      ),
    );
  }
}

void main() {
  testWidgets('ProductScreen displays ShimmerLoading skeleton item cards when loading', (tester) async {
    final mockRepo = DelayedProductRepository();
    final authVm = FakeAuthViewModel();

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

    // Initial pump while getProducts is still pending
    await tester.pump();

    // Verify ShimmerLoading core widgets are rendered
    expect(find.byType(ShimmerLoading), findsWidgets);

    // Complete the loading future
    mockRepo.productsCompleter.complete(
      ProductListResult(
        products: [
          const ProductModel(
            id: 1,
            name: 'Keripik Tempe Super',
            unitName: 'Pouch',
            unitShort: 'Pch',
            consignmentPrice: 8500,
            consignmentPriceFormatted: 'Rp 8.500',
            retailPrice: 10000,
            retailPriceFormatted: 'Rp 10.000',
            stockReady: 45,
            isActive: true,
          ),
        ],
        pagination: const ProductPaginationModel(
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          total: 1,
          hasMore: false,
        ),
      ),
    );

    // Pump to process the completion
    await tester.pump();

    // Now product data should be displayed and ShimmerLoading gone
    expect(find.text('Keripik Tempe Super'), findsOneWidget);
    expect(find.text('Rp 8.500'), findsOneWidget);
    expect(find.text('Rp 10.000'), findsOneWidget);
    expect(find.text('45 Pch'), findsOneWidget);
  });
}
