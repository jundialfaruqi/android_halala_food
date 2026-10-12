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

void main() {
  group('HomeScreen Donut Stat Card Tests', () {
    testWidgets('Courier sees delivery stat title, donut chart, and 45-degree diamond bullets with black text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => _FakeCourierAuthViewModel()),
            homeStatViewModelProvider.overrideWith(() => _FakeCourierHomeStatViewModel()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
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
    });
  });
}
