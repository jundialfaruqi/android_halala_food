import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/data/repositories/home_repository_impl.dart';
import 'package:android_halala_food/features/home/domain/repositories/home_repository.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';

const _businessStat = DashboardStatModel(
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
      label: 'Pemasukan Periode ini',
      value: 'Rp 1.000.000',
      color: Color(0xFF10B981),
    ),
  ],
);

const _courierStat = DashboardStatModel(
  type: 'pengantaran',
  title: 'Tugas Pengantaran Hari Ini',
  dateFormatted: 'Senin, 13 Okt 2026',
  donut: DashboardDonutModel(
    percentage: 50,
    centerLabel: '50%',
    centerSublabel: 'Selesai',
    slices: [
      DashboardDonutSliceModel(
        label: 'Selesai',
        value: 5,
        color: Color(0xFF10B981),
      ),
    ],
  ),
  metrics: [
    DashboardMetricModel(
      label: 'Total Toko',
      value: '5 Toko',
      color: Color(0xFF3B82F6),
    ),
  ],
);

class _TestHomeRepository implements HomeRepository {
  UserModel? currentUser;

  @override
  Future<DashboardStatModel> getDashboardStat() async {
    if (currentUser?.hasPermission('dashboard-stat-bisnis') ?? false) {
      return _businessStat;
    }
    if (currentUser?.hasPermission('dashboard-stat-pengantaran') ?? false) {
      return _courierStat;
    }
    return _businessStat;
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

class _TestAuthViewModel extends AuthViewModel {
  final _TestHomeRepository homeRepo;
  final UserModel? initialUser;

  _TestAuthViewModel(this.homeRepo, [this.initialUser]);

  @override
  AuthState build() {
    if (initialUser != null) {
      homeRepo.currentUser = initialUser;
      return AuthState(
        status: AuthStatus.authenticated,
        user: initialUser,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  void loginAs(UserModel user) {
    homeRepo.currentUser = user;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  @override
  Future<void> logout() async {
    homeRepo.currentUser = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  group('HomeStat Switch User Tests', () {
    test('HomeStatViewModel clears stat on logout and loads courier stat on login', () async {
      final repo = _TestHomeRepository();
      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(repo),
          authViewModelProvider.overrideWith(() => _TestAuthViewModel(repo)),
        ],
      );

      final adminUser = UserModel(
        id: 1,
        name: 'Admin Bisnis',
        email: 'admin@mail.com',
        permissions: const ['dashboard-stat-bisnis'],
        roles: const ['dev'],
      );

      final courierUser = UserModel(
        id: 4,
        name: 'Kurir Budi',
        email: 'kurir@mail.com',
        permissions: const ['dashboard-stat-pengantaran'],
        roles: const ['kurir'],
      );

      // Listen agar provider selalu aktif di Riverpod container
      final sub = container.listen(homeStatViewModelProvider, (_, __) {});

      final authNotifier = container.read(authViewModelProvider.notifier) as _TestAuthViewModel;

      // 1. Awalnya unauthenticated: stat harus null
      expect(sub.read().stat, isNull);

      // 2. Login sebagai Admin
      authNotifier.loginAs(adminUser);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final adminStat = sub.read().stat;
      expect(adminStat, isNotNull);
      expect(adminStat?.type, equals('bisnis'));
      expect(adminStat?.title, equals('Ringkasan Bisnis'));

      // 3. Logout -> stat otomatis ter-reset ke null
      await authNotifier.logout();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sub.read().stat, isNull);

      // 4. Login kembali sebagai Kurir -> stat termuat untuk Kurir
      authNotifier.loginAs(courierUser);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final courierStat = sub.read().stat;
      expect(courierStat, isNotNull);
      expect(courierStat?.type, equals('pengantaran'));
      expect(courierStat?.title, equals('Tugas Pengantaran Hari Ini'));

      sub.close();
      container.dispose();
    });

    testWidgets('HomeScreen updates from business stat to courier stat when user switches', (tester) async {
      final repo = _TestHomeRepository();

      final adminUser = UserModel(
        id: 1,
        name: 'Admin Bisnis',
        email: 'admin@mail.com',
        permissions: const ['dashboard-stat-bisnis'],
        roles: const ['dev'],
      );

      final courierUser = UserModel(
        id: 4,
        name: 'Kurir Budi',
        email: 'kurir@mail.com',
        permissions: const ['dashboard-stat-pengantaran'],
        roles: const ['kurir'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeRepositoryProvider.overrideWithValue(repo),
            storeRepositoryProvider.overrideWithValue(_DummyStoreRepo()),
            authViewModelProvider.overrideWith(() => _TestAuthViewModel(repo, adminUser)),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan Ringkasan Bisnis tampil untuk Admin
      expect(find.text('Ringkasan Bisnis'), findsOneWidget);
      expect(find.text('Pemasukan Periode ini'), findsOneWidget);

      // Dapatkan authNotifier dari element tree
      final element = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(element);
      final authNotifier = container.read(authViewModelProvider.notifier) as _TestAuthViewModel;

      // Logout
      await authNotifier.logout();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Login sebagai Kurir
      authNotifier.loginAs(courierUser);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Memastikan Ringkasan Bisnis sudah HILANG dan Tugas Pengantaran Hari Ini tampil
      expect(find.text('Ringkasan Bisnis'), findsNothing);
      expect(find.text('Tugas Pengantaran Hari Ini'), findsOneWidget);
      expect(find.text('Total Toko'), findsOneWidget);
    });
  });
}
