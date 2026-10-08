import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_dropdown_search_field.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_search_selection_dialog.dart';

class MockStoreRepository implements StoreRepository {
  int getStoresCallCount = 0;
  String? lastSearch;
  int? lastPerPage;
  int? lastPage;

  final List<StoreModel> allDummyStores = List.generate(
    25,
    (index) => StoreModel(
      id: index + 1,
      name: 'Toko Sumber Rezeki ${index + 1}',
      ownerName: 'Pemilik ${index + 1}',
      route: 'Rute ${index % 3 + 1}',
      address: 'Jl. Ahmad Yani No. ${index + 1}',
      phone: '081234567${index.toString().padLeft(3, '0')}',
      isActive: true,
    ),
  );

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    getStoresCallCount++;
    lastSearch = search;
    lastPerPage = perPage;
    lastPage = page;

    var filtered = allDummyStores.where((s) {
      if (search == null || search.trim().isEmpty) return true;
      final q = search.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          (s.ownerName?.toLowerCase().contains(q) ?? false) ||
          (s.route?.toLowerCase().contains(q) ?? false);
    }).toList();

    final startIndex = (page - 1) * perPage;
    final paged = filtered.skip(startIndex).take(perPage).toList();
    final hasMore = (startIndex + perPage) < filtered.length;

    return StoreListResult(
      stores: paged,
      pagination: StorePaginationModel(
        currentPage: page,
        lastPage: (filtered.length / perPage).ceil(),
        perPage: perPage,
        total: filtered.length,
        hasMore: hasMore,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => ['Rute 1', 'Rute 2', 'Rute 3'];

  @override
  Future<StoreModel> getStoreDetail(int id) async => allDummyStores.first;

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async =>
      allDummyStores.first;

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async =>
      allDummyStores.first;

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  late MockStoreRepository mockRepo;

  setUp(() {
    mockRepo = MockStoreRepository();
  });

  Widget createWidgetUnderTest({
    ValueChanged<StoreSelectOption?>? onSelected,
    int? initialValue,
  }) {
    return ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StoreDropdownSearchField(
              labelText: 'Toko Mitra Tujuan *',
              hintText: 'Pilih Toko Mitra...',
              initialValue: initialValue,
              initialStores: mockRepo.allDummyStores.take(5).toList(),
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'UX: user ketik < 3 huruf fungsi pencarian belum jalan, ketik >= 3 huruf baru jalan dan dibatasi max 5',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Verifikasi render field
    expect(find.text('Toko Mitra Tujuan *'), findsOneWidget);
    expect(find.text('Pilih Toko Mitra...'), findsOneWidget);

    // 2. Tap field untuk membuka dropdown
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Dropdown terbuka dan ada tombol 'Tampilkan semua mitra toko'
    expect(find.text('Tampilkan semua mitra toko'), findsOneWidget);

    // 3. User ketik 2 huruf ("to") -> pencarian BELUM jalan
    await tester.enterText(find.byType(TextField), 'to');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      find.text('Ketik minimal 3 huruf untuk mencari toko mitra.'),
      findsOneWidget,
    );
    expect(mockRepo.getStoresCallCount, 0); // Memastikan API belum dipanggil

    // 4. User ketik 3 huruf ("tok") -> fungsi pencarian jalan
    await tester.enterText(find.byType(TextField), 'tok');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(mockRepo.getStoresCallCount, 1);
    expect(mockRepo.lastSearch, 'tok');
    expect(mockRepo.lastPerPage, 5); // Dibatasi 5 data di dropdown

    // Verifikasi hasil di dropdown dibatasi hanya 5 item
    expect(find.text('Toko Sumber Rezeki 1'), findsOneWidget);
    expect(find.text('Toko Sumber Rezeki 5'), findsOneWidget);
    expect(find.text('Tampilkan semua mitra toko'), findsOneWidget);
  });

  testWidgets(
      'Klik "Tampilkan semua mitra toko" membuka modal dialog dengan infinite scroll 10 data',
      (tester) async {
    StoreSelectOption? selectedResult;

    await tester.pumpWidget(createWidgetUnderTest(
      onSelected: (option) {
        selectedResult = option;
      },
    ));
    await tester.pumpAndSettle();

    // Buka dropdown
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Klik tombol "Tampilkan semua mitra toko"
    final showAllButton = find.text('Tampilkan semua mitra toko');
    expect(showAllButton, findsOneWidget);
    await tester.tap(showAllButton);
    await tester.pumpAndSettle();

    // Verifikasi dialog StoreSearchSelectionDialog terbuka
    expect(find.byType(StoreSearchSelectionDialog), findsOneWidget);
    expect(find.text('Daftar Mitra Toko'), findsOneWidget);

    // Verifikasi API dipanggil untuk dialog dengan perPage 10
    expect(mockRepo.lastPerPage, 10);

    // Di dialog awal ada 10 toko (Toko Sumber Rezeki 1 s/d 10)
    expect(find.text('Toko Sumber Rezeki 1'), findsOneWidget);

    // Tap salah satu toko di dialog
    await tester.tap(find.text('Toko Sumber Rezeki 1'));
    await tester.pumpAndSettle();

    // Dialog tertutup dan toko terpilih
    expect(find.byType(StoreSearchSelectionDialog), findsNothing);
    expect(selectedResult, isNotNull);
    expect(selectedResult!.id, 1);
    expect(find.text('Toko Sumber Rezeki 1 (Rute 1)'), findsOneWidget);
  });
}
