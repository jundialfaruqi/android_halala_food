import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/features/home/presentation/widgets/home_donut_chart.dart';

class _FakeCourierAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 4,
        name: 'Kurir Budi',
        email: 'kurir@halala-food.id',
        permissions: const ['dashboard-stat-pengantaran'],
        roles: const ['kurir'],
      ),
    );
  }
}

class _FakeCourierHomeStatViewModel extends HomeStatViewModel {
  @override
  HomeStatState build() {
    return const HomeStatState(
      isLoading: false,
      stat: DashboardStatModel(
        type: 'pengantaran',
        title: 'Tugas Pengantaran Hari Ini',
        dateFormatted: 'Senin, 13 Okt 2026',
        donut: DashboardDonutModel(
          percentage: 80,
          centerLabel: '80%',
          centerSublabel: 'Selesai',
          slices: [
            DashboardDonutSliceModel(
              label: 'Selesai',
              value: 8,
              color: Color(0xFF10B981),
            ),
            DashboardDonutSliceModel(
              label: 'Dalam Rute',
              value: 2,
              color: Color(0xFFF59E0B),
            ),
          ],
        ),
        metrics: [
          DashboardMetricModel(
            label: 'Total Toko',
            value: '10 Toko',
            color: Color(0xFF3B82F6),
          ),
          DashboardMetricModel(
            label: 'Sudah Terkirim',
            value: '8 SJ Selesai',
            color: Color(0xFF10B981),
          ),
          DashboardMetricModel(
            label: 'Sisa Rute',
            value: '2 Belum Selesai',
            color: Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _FakeBusinessAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 2,
        name: 'Manager Siti',
        email: 'manager@halala-food.id',
        permissions: const ['dashboard-stat-bisnis'],
        roles: const ['manager'],
      ),
    );
  }
}

class _FakeBusinessHomeStatViewModel extends HomeStatViewModel {
  @override
  HomeStatState build() {
    return const HomeStatState(
      isLoading: false,
      stat: DashboardStatModel(
        type: 'bisnis',
        title: 'Ringkasan Bisnis',
        dateFormatted: 'Senin, 13 Okt 2026',
        donut: DashboardDonutModel(
          percentage: 88,
          centerLabel: '88%',
          centerSublabel: 'Surplus',
          slices: [
            DashboardDonutSliceModel(
              label: 'Pemasukan',
              value: 8870000,
              color: Color(0xFF10B981),
            ),
            DashboardDonutSliceModel(
              label: 'Biaya Usaha',
              value: 1089500,
              color: Color(0xFFEF4444),
            ),
          ],
        ),
        metrics: [
          DashboardMetricModel(
            label: 'Pemasukan',
            value: 'Rp 8.870.000',
            color: Color(0xFF10B981),
          ),
          DashboardMetricModel(
            label: 'Biaya Usaha',
            value: 'Rp 1.089.500',
            color: Color(0xFFEF4444),
          ),
          DashboardMetricModel(
            label: 'Total Prive',
            value: 'Rp 0',
            color: Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('HomeScreen Donut Stat Card Tests', () {
    testWidgets(
      'Courier sees delivery stat title, donut chart, and 45-degree diamond bullets with black text',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authViewModelProvider.overrideWith(
                () => _FakeCourierAuthViewModel(),
              ),
              homeStatViewModelProvider.overrideWith(
                () => _FakeCourierHomeStatViewModel(),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify courier title is displayed
        expect(find.text('Tugas Pengantaran Hari Ini'), findsOneWidget);

        // Verify center label and sublabel on donut
        expect(find.text('80%'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget); // center sublabel

        // Verify HomeDonutChart widget is present
        expect(find.byType(HomeDonutChart), findsOneWidget);

        // Verify DiamondIndicator (rotated 45-deg square) widgets are present for the 3 metrics
        expect(find.byType(DiamondIndicator), findsNWidgets(3));

        // Verify metric labels
        expect(find.text('Total Toko'), findsOneWidget);
        expect(find.text('10 Toko'), findsOneWidget);
        expect(find.text('Sudah Terkirim'), findsOneWidget);
        expect(find.text('8 SJ Selesai'), findsOneWidget);
        expect(find.text('Sisa Rute'), findsOneWidget);
        expect(find.text('2 Belum Selesai'), findsOneWidget);

        // Verify text styling has black color (#0F172A)
        final labelWidget = tester.widget<Text>(find.text('Total Toko'));
        expect(labelWidget.style?.color, equals(const Color(0xFF0F172A)));
      },
    );

    testWidgets(
      'Business user sees cash book statistics: Total Pemasukan, Total Biaya Usaha, and Total Prive',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authViewModelProvider.overrideWith(
                () => _FakeBusinessAuthViewModel(),
              ),
              homeStatViewModelProvider.overrideWith(
                () => _FakeBusinessHomeStatViewModel(),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify business title is displayed
        expect(find.text('Ringkasan Bisnis'), findsOneWidget);

        // Verify center label and sublabel on donut
        expect(find.text('88%'), findsOneWidget);
        expect(find.text('Surplus'), findsOneWidget);

        // Verify HomeDonutChart widget is present
        expect(find.byType(HomeDonutChart), findsOneWidget);

        // Verify DiamondIndicator (rotated 45-deg square) widgets are present for the 3 metrics
        expect(find.byType(DiamondIndicator), findsNWidgets(3));

        // Verify date is formatted in Indonesian
        expect(find.text('Senin, 13 Okt 2026'), findsOneWidget);

        // Verify the 3 cash book metric labels and values
        expect(find.text('Pemasukan'), findsOneWidget);
        expect(find.text('Rp 8.870.000'), findsOneWidget);
        expect(find.text('Biaya Usaha'), findsOneWidget);
        expect(find.text('Rp 1.089.500'), findsOneWidget);
        expect(find.text('Total Prive'), findsOneWidget);
        expect(find.text('Rp 0'), findsOneWidget);
      },
    );

    testWidgets(
      'Stat card automatically translates English date from API into Indonesian',
      (WidgetTester tester) async {
        final englishDateStat = const DashboardStatModel(
          type: 'bisnis',
          title: 'Ringkasan Bisnis',
          dateFormatted: 'Tuesday, 13 Oct 2026',
          donut: DashboardDonutModel(
            percentage: 88,
            centerLabel: '88%',
            centerSublabel: 'Surplus',
            slices: [],
          ),
          metrics: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authViewModelProvider.overrideWith(
                () => _FakeBusinessAuthViewModel(),
              ),
              homeStatViewModelProvider.overrideWith(
                () => _FakeCustomHomeStatViewModel(englishDateStat),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // English 'Tuesday, 13 Oct 2026' must be translated to Indonesian 'Selasa, 13 Okt 2026'
        expect(find.text('Selasa, 13 Okt 2026'), findsOneWidget);
      },
    );
  });
}

class _FakeCustomHomeStatViewModel extends HomeStatViewModel {
  final DashboardStatModel _stat;
  _FakeCustomHomeStatViewModel(this._stat);

  @override
  HomeStatState build() {
    return HomeStatState(isLoading: false, stat: _stat);
  }
}
