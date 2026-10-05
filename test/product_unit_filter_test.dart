import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/product/data/models/product_model.dart';
import 'package:android_halala_food/features/product/data/repositories/product_repository_impl.dart';
import 'package:android_halala_food/features/product/domain/repositories/product_repository.dart';
import 'package:android_halala_food/features/product/presentation/views/product_screen.dart';

class MockProductRepository implements ProductRepository {
  int? lastUnitIdRequested;

  final List<ProductUnitModel> dummyUnits = const [
    ProductUnitModel(id: 1, name: 'Pieces', shortName: 'Pcs'),
    ProductUnitModel(id: 2, name: 'Kardus', shortName: 'Dus'),
  ];

  final List<ProductModel> dummyProducts = const [
    ProductModel(
      id: 1,
      name: 'Keripik Tempe Pcs',
      unitId: 1,
      unitName: 'Pieces',
      unitShort: 'Pcs',
      consignmentPrice: 8000,
      consignmentPriceFormatted: 'Rp 8.000',
      retailPrice: 10000,
      retailPriceFormatted: 'Rp 10.000',
      stockReady: 50,
      isActive: true,
    ),
    ProductModel(
      id: 2,
      name: 'Keripik Tempe Dus',
      unitId: 2,
      unitName: 'Kardus',
      unitShort: 'Dus',
      consignmentPrice: 90000,
      consignmentPriceFormatted: 'Rp 90.000',
      retailPrice: 100000,
      retailPriceFormatted: 'Rp 100.000',
      stockReady: 20,
      isActive: true,
    ),
  ];

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) async {
    lastUnitIdRequested = unitId;

    final filtered = dummyProducts.where((p) {
      if (unitId != null && p.unitId != unitId) return false;
      return true;
    }).toList();

    return ProductListResult(
      products: filtered,
      pagination: ProductPaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: filtered.length,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<ProductUnitModel>> getUnits() async => dummyUnits;

  @override
  Future<ProductModel> getProductDetail(int id) async => dummyProducts.first;
}

void main() {
  testWidgets(
      'ProductScreen unit filter allows selecting a unit and then reset via Semua Satuan',
      (tester) async {
    final mockRepo = MockProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ProductScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial state: dropdown displays 'Semua Satuan' and summary text below filter
    expect(find.text('Semua Satuan'), findsOneWidget);
    expect(find.text('Menampilkan 2 Produk'), findsOneWidget);
    expect(find.text('Keripik Tempe Pcs'), findsOneWidget);
    expect(find.text('Keripik Tempe Dus'), findsOneWidget);
    expect(mockRepo.lastUnitIdRequested, isNull);

    // 2. Tap unit dropdown to open popup
    await tester.tap(find.text('Semua Satuan'));
    await tester.pumpAndSettle();

    // Popup shows options: 'Semua Satuan', 'Pieces (Pcs)', 'Kardus (Dus)'
    expect(find.text('Kardus (Dus)'), findsOneWidget);
    expect(find.text('Pieces (Pcs)'), findsOneWidget);

    // 3. Select 'Kardus (Dus)'
    await tester.tap(find.text('Kardus (Dus)'));
    await tester.pumpAndSettle();

    // Label should now be 'Dus' and repository called with unitId: 2
    expect(find.text('Dus'), findsOneWidget);
    expect(find.text('Menampilkan 1 dari 1 Produk'), findsOneWidget);
    expect(find.text('Reset Filter'), findsOneWidget);
    expect(mockRepo.lastUnitIdRequested, equals(2));
    expect(find.text('Keripik Tempe Dus'), findsOneWidget);
    expect(find.text('Keripik Tempe Pcs'), findsNothing);

    // 4. Tap unit dropdown again to select 'Semua Satuan'
    await tester.tap(find.text('Dus'));
    await tester.pumpAndSettle();

    // Tap 'Semua Satuan' in the popup menu
    expect(find.text('Semua Satuan'), findsOneWidget);
    await tester.tap(find.text('Semua Satuan'));
    await tester.pumpAndSettle();

    // 5. Verify dropdown returns to 'Semua Satuan', count text resets, and repository called with unitId: null
    expect(find.text('Semua Satuan'), findsOneWidget);
    expect(find.text('Menampilkan 2 Produk'), findsOneWidget);
    expect(mockRepo.lastUnitIdRequested, isNull);
    expect(find.text('Keripik Tempe Pcs'), findsOneWidget);
    expect(find.text('Keripik Tempe Dus'), findsOneWidget);
  });
}
