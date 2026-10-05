import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';

class MockStoreRepository implements StoreRepository {
  final List<StoreModel> dummyStores = [
    const StoreModel(
      id: 1,
      name: 'Toko Berkah Jaya',
      route: 'Rute A',
      latitude: -7.98,
      longitude: 112.63,
      phone: '08123456789',
      address: 'Jl. Merdeka No. 1',
    ),
    const StoreModel(
      id: 2,
      name: 'Toko Sumber Rejeki',
      route: 'Rute B',
      latitude: -7.99,
      longitude: 112.64,
      phone: '08129876543',
      address: 'Jl. Sudirman No. 2',
    ),
  ];

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    int page = 1,
    int perPage = 15,
  }) async {
    return StoreListResult(
      stores: dummyStores,
      pagination: const StorePaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 2,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => ['Rute A', 'Rute B'];

  @override
  Future<StoreModel> getStoreDetail(int id) async => dummyStores.first;

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async =>
      dummyStores.first;

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async =>
      dummyStores.first;

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  testWidgets('StoreCoordinatesScreen search displays result and moves map on click',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    // Initial pump and fetch completion
    await tester.pumpAndSettle();

    // Verify search field exists
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    expect(find.text('2 Toko Terpetakan'), findsOneWidget);

    // 1. Enter 1 letter ('B') - should NOT trigger search even after 400ms
    await tester.enterText(textFieldFinder, 'B');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ListView), findsNothing);

    // 2. Enter 2 letters ('Be') - should NOT trigger search even after 400ms
    await tester.enterText(textFieldFinder, 'Be');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ListView), findsNothing);

    // 3. Enter 3+ letters ('Ber')
    await tester.enterText(textFieldFinder, 'Ber');
    // Pump before debounce finishes (200ms) - should not show yet
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ListView), findsNothing);

    // Pump past debounce (350ms total)
    await tester.pump(const Duration(milliseconds: 250));

    // Verify search dropdown shows 'Toko Berkah Jaya'
    expect(find.text('Toko Berkah Jaya'), findsWidgets);

    // Tap on the search result
    await tester.tap(find.text('Toko Berkah Jaya').first);
    await tester.pumpAndSettle();

    // Verify store detail modal card is opened
    expect(find.text('Buka di Google Maps'), findsOneWidget);
    expect(find.text('+628123456789'), findsOneWidget);
  });
}
