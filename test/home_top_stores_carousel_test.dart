import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_top_stores_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';

class _FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Manager Test',
        email: 'manager@halala-food.id',
        permissions: const ['toko-view', 'produk-view'],
        roles: const ['manager'],
      ),
    );
  }
}

class _FakeHomeStatViewModel extends HomeStatViewModel {
  @override
  HomeStatState build() {
    return const HomeStatState(
      isLoading: false,
      stat: DashboardStatModel(
        type: 'bisnis',
        title: 'Ringkasan Hari Ini',
        dateFormatted: 'Senin, 13 Okt 2026',
        donut: DashboardDonutModel(
          percentage: 75,
          centerLabel: '75%',
          centerSublabel: 'Selesai',
          slices: [
            DashboardDonutSliceModel(
              label: 'Selesai',
              value: 9,
              color: Color(0xFF10B981),
            ),
          ],
        ),
        metrics: [
          DashboardMetricModel(
            label: 'Penjualan',
            value: 'Rp 4,8 Jt',
            color: Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _FakeHomeTopStoresViewModel extends HomeTopStoresViewModel {
  @override
  HomeTopStoresState build() {
    return const HomeTopStoresState(
      isLoading: false,
      stores: [
        StoreModel(
          id: 101,
          name: 'Toko Berkah Jaya',
          address: 'Jl. Ahmad Yani No. 45',
          latitude: -7.250445,
          longitude: 112.768845,
          totalSales: 8500000.0,
          salesCount: 25,
          photoUrl: null,
        ),
        StoreModel(
          id: 102,
          name: 'Toko Makmur Sentosa',
          address: 'Jl. Pemuda No. 10',
          latitude: -7.260000,
          longitude: 112.750000,
          totalSales: 750000.0,
          salesCount: 3,
        ),
      ],
    );
  }
}

class _DummyStoreRepo implements StoreRepository {
  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    bool? isActive,
    String? sortBy,
    int page = 1,
    int perPage = 15,
  }) async {
    return const StoreListResult(
      stores: [],
      pagination: StorePaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 0,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => [];

  @override
  Future<StoreModel> getStoreDetail(int id) async => throw UnimplementedError();

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  testWidgets('HomeScreen renders Material 3 Carousel section for Toko Mitra Terlaris with stars and button', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _FakeAuthViewModel()),
          homeStatViewModelProvider.overrideWith(() => _FakeHomeStatViewModel()),
          homeTopStoresViewModelProvider.overrideWith(() => _FakeHomeTopStoresViewModel()),
          storeRepositoryProvider.overrideWithValue(_DummyStoreRepo()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify section header exists
    expect(find.text('Toko Mitra Terlaris'), findsOneWidget);
    expect(find.text('Lihat Semua'), findsOneWidget);

    // Verify Material 3 CarouselView is present
    expect(find.byType(CarouselView), findsOneWidget);

    // Verify store info on first card
    expect(find.text('Toko Berkah Jaya'), findsOneWidget);
    expect(find.text('Jl. Ahmad Yani No. 45'), findsOneWidget);

    // Verify star icons are rendered (Toko Berkah Jaya with 8.5M sales has 5 stars)
    expect(find.byIcon(TablerIcons.star_filled), findsWidgets);

    // Verify "Lihat Toko" button with arrow right icon
    expect(find.text('Lihat Toko'), findsWidgets);
    expect(find.byIcon(TablerIcons.arrow_right), findsWidgets);

    // Scroll into view if needed and tap "Lihat Toko" button on first store
    final lihatTokoButton = find.text('Lihat Toko').first;
    await tester.ensureVisible(lihatTokoButton);
    await tester.pumpAndSettle();
    await tester.tap(lihatTokoButton);
    await tester.pumpAndSettle();

    // Verify navigation to StoreCoordinatesScreen was triggered
    expect(find.byType(StoreCoordinatesScreen), findsOneWidget);
  });
}
