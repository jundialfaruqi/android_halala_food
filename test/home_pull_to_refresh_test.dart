import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/constants/app_colors.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_top_stores_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';

class _MockAuthViewModel extends AuthViewModel {
  int refreshCallCount = 0;

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Ahmad Manager',
        email: 'ahmad@halala-food.id',
        permissions: const ['dashboard-stat-bisnis', 'toko-view'],
        roles: const ['manager'],
      ),
    );
  }

  @override
  Future<UserModel?> refreshUserProfile() async {
    refreshCallCount++;
    return state.user;
  }
}

class _MockHomeStatViewModel extends HomeStatViewModel {
  int loadStatCallCount = 0;

  @override
  HomeStatState build() {
    return const HomeStatState(
      isLoading: false,
      stat: DashboardStatModel(
        type: 'bisnis',
        title: 'Ringkasan Bisnis',
        dateFormatted: 'Senin, 13 Okt 2026',
        donut: DashboardDonutModel(
          percentage: 80,
          centerLabel: '80%',
          centerSublabel: 'Surplus',
          slices: [
            DashboardDonutSliceModel(
              label: 'Pemasukan',
              value: 1000000,
              color: Color(0xFF10B981),
            ),
          ],
        ),
        metrics: [
          DashboardMetricModel(
            label: 'Pemasukan',
            value: 'Rp 1.000.000',
            color: Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> loadStat({bool clearExisting = false}) async {
    loadStatCallCount++;
  }
}

class _MockHomeTopStoresViewModel extends HomeTopStoresViewModel {
  int loadTopStoresCallCount = 0;

  @override
  HomeTopStoresState build() {
    return const HomeTopStoresState(isLoading: false, stores: []);
  }

  @override
  Future<void> loadTopStores({bool clearExisting = false}) async {
    loadTopStoresCallCount++;
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
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  testWidgets(
    'HomeScreen has RefreshIndicator and triggers full refresh on pull-down',
    (tester) async {
      final mockAuth = _MockAuthViewModel();
      final mockStat = _MockHomeStatViewModel();
      final mockTopStores = _MockHomeTopStoresViewModel();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => mockAuth),
            homeStatViewModelProvider.overrideWith(() => mockStat),
            homeTopStoresViewModelProvider.overrideWith(() => mockTopStores),
            storeRepositoryProvider.overrideWithValue(_DummyStoreRepo()),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan RefreshIndicator terpasang
      final refreshIndicatorFinder = find.byType(RefreshIndicator);
      expect(refreshIndicatorFinder, findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        refreshIndicatorFinder,
      );
      expect(refreshIndicator.color, equals(AppColors.brandPrimary));
      expect(refreshIndicator.backgroundColor, equals(Colors.white));

      // Awalnya belum dipanggil pull to refresh
      expect(mockAuth.refreshCallCount, 0);
      expect(mockStat.loadStatCallCount, 0);
      expect(mockTopStores.loadTopStoresCallCount, 0);

      // Simulasikan pull to refresh dengan menarik scrollable ke bawah
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Seluruh provider relevan (auth profil, stat card, dan top stores) berhasil dipanggil ulang
      expect(mockAuth.refreshCallCount, greaterThanOrEqualTo(1));
      expect(mockStat.loadStatCallCount, greaterThanOrEqualTo(1));
      expect(mockTopStores.loadTopStoresCallCount, greaterThanOrEqualTo(1));
    },
  );
}
