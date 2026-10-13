import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_dropdown_search_field.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_multi_select_field.dart';
import 'package:android_halala_food/core/widgets/app_button.dart';
import 'package:android_halala_food/features/store/presentation/widgets/store_multi_search_selection_dialog.dart';

class MockStoreRepository implements StoreRepository {
  int getStoresCallCount = 0;
  String? lastSearch;

  final List<StoreModel> allDummyStores = List.generate(
    10,
    (index) => StoreModel(
      id: index + 1,
      name: 'Toko Sumber Rezeki ${index + 1}',
      ownerName: 'Pemilik ${index + 1}',
      route: 'Rute ${index % 2 + 1}',
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
    String? sortBy,
    int page = 1,
    int perPage = 10,
  }) async {
    getStoresCallCount++;
    lastSearch = search;

    var filtered = allDummyStores.where((s) {
      if (search == null || search.trim().isEmpty) return true;
      final q = search.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          (s.ownerName?.toLowerCase().contains(q) ?? false) ||
          (s.route?.toLowerCase().contains(q) ?? false);
    }).toList();

    return StoreListResult(
      stores: filtered,
      pagination: StorePaginationModel(
        currentPage: page,
        lastPage: 1,
        perPage: perPage,
        total: filtered.length,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => ['Rute 1', 'Rute 2'];

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

  Widget buildTestableWidget({
    List<StoreSelectOption> initialStores = const [],
    ValueChanged<List<StoreSelectOption>>? onChanged,
    FormFieldValidator<List<StoreSelectOption>>? validator,
  }) {
    return ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StoreMultiSelectField(
              labelText: 'Toko Mitra Tujuan *',
              hintText: 'Pilih satu atau lebih toko mitra...',
              initialStores: initialStores,
              onChanged: onChanged,
              validator: validator,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('StoreMultiSelectField menampilkan hintText saat belum ada toko dipilih', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Toko Mitra Tujuan *'), findsOneWidget);
    expect(find.text('Pilih satu atau lebih toko mitra...'), findsOneWidget);
  });

  testWidgets('StoreMultiSelectField merender chip untuk toko yang dipilih dan dapat dihapus', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<StoreSelectOption> updatedList = [];
    final initialList = [
      const StoreSelectOption(id: 1, name: 'Toko Mawar', route: 'Rute A'),
      const StoreSelectOption(id: 2, name: 'Toko Melati', route: 'Rute B'),
    ];

    await tester.pumpWidget(
      buildTestableWidget(
        initialStores: initialList,
        onChanged: (stores) {
          updatedList = stores;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 toko terpilih'), findsOneWidget);
    expect(find.text('Toko Mawar (Rute A)'), findsOneWidget);
    expect(find.text('Toko Melati (Rute B)'), findsOneWidget);

    // Hapus toko pertama via tombol TablerIcons.x
    final xIcons = find.byIcon(TablerIcons.x);
    expect(xIcons, findsWidgets);

    await tester.tap(xIcons.first);
    await tester.pumpAndSettle();

    expect(updatedList.length, 1);
    expect(updatedList.first.id, 2);
  });

  testWidgets('Klik StoreMultiSelectField membuka StoreMultiSearchSelectionDialog dan memilih toko', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<StoreSelectOption> selectedList = [];

    await tester.pumpWidget(
      buildTestableWidget(
        onChanged: (stores) {
          selectedList = stores;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap StoreMultiSelectField
    await tester.tap(find.text('Pilih satu atau lebih toko mitra...'));
    await tester.pumpAndSettle();

    // Verifikasi dialog StoreMultiSearchSelectionDialog terbuka
    expect(find.byType(StoreMultiSearchSelectionDialog), findsOneWidget);
    expect(find.text('Pilih Mitra Toko'), findsOneWidget);

    // Di dialog awal ada daftar toko, rute, alamat di baris baru, dan info pemilik/kontak
    expect(find.text('Toko Sumber Rezeki 1'), findsOneWidget);
    expect(find.text('Rute 1'), findsWidgets);
    expect(find.text('Jl. Ahmad Yani No. 1'), findsOneWidget);
    expect(find.text('Pemilik 1 • 081234567000'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rute 1').first).dy,
      greaterThan(tester.getTopLeft(find.text('Toko Sumber Rezeki 1')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Jl. Ahmad Yani No. 1')).dy,
      greaterThan(tester.getTopLeft(find.text('Rute 1').first).dy),
    );
    expect(
      tester.getTopLeft(find.text('Pemilik 1 • 081234567000')).dy,
      greaterThan(tester.getTopLeft(find.text('Jl. Ahmad Yani No. 1')).dy),
    );

    // Verifikasi tombol Batal dan Pilih Toko full width 2 kolom berukuran seimbang
    final batalFinder = find.widgetWithText(AppButton, 'Batal');
    final pilihFinder = find.widgetWithText(AppButton, 'Pilih Toko');
    expect(batalFinder, findsOneWidget);
    expect(pilihFinder, findsOneWidget);
    expect((tester.getSize(batalFinder).width - tester.getSize(pilihFinder).width).abs(), lessThan(1.0));

    // Tap toko 1
    await tester.tap(find.text('Toko Sumber Rezeki 1'));
    await tester.pumpAndSettle();

    // Konfirmasi
    await tester.tap(find.text('Pilih (1 Toko)'));
    await tester.pumpAndSettle();

    // Dialog tertutup dan toko terpilih di field
    expect(find.byType(StoreMultiSearchSelectionDialog), findsNothing);
    expect(selectedList.length, 1);
    expect(selectedList.first.id, 1);
  });

  testWidgets('Fitur Pilih Semua (Select All) dapat memilih dan membatalkan semua toko sekaligus', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<StoreSelectOption> selectedList = [];

    await tester.pumpWidget(
      buildTestableWidget(
        onChanged: (stores) {
          selectedList = stores;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Buka dialog
    await tester.tap(find.text('Pilih satu atau lebih toko mitra...'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Semua Toko Mitra'), findsOneWidget);
    expect(find.text('0/10 dipilih'), findsOneWidget);

    // Klik Pilih Semua
    await tester.tap(find.text('Pilih Semua Toko Mitra'));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan Pilih Semua'), findsOneWidget);
    expect(find.text('10/10 dipilih'), findsOneWidget);
    expect(find.text('Pilih (10 Toko)'), findsOneWidget);

    // Klik Batalkan Pilih Semua
    await tester.tap(find.text('Batalkan Pilih Semua'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Semua Toko Mitra'), findsOneWidget);
    expect(find.text('0/10 dipilih'), findsOneWidget);
    expect(find.text('Pilih Toko'), findsOneWidget);

    // Pilih Semua lagi lalu Submit
    await tester.tap(find.text('Pilih Semua Toko Mitra'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih (10 Toko)'));
    await tester.pumpAndSettle();

    expect(find.byType(StoreMultiSearchSelectionDialog), findsNothing);
    expect(selectedList.length, 10);
  });
}

