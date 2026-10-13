import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';

class _FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Ahmad Manager',
        email: 'ahmad@halala-food.id',
        permissions: const ['dashboard-stat-bisnis', 'produk-view'],
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
            label: 'Penjualan',
            value: 'Rp 1,0 Jt',
            color: Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('HomeScreen sticky user info header renders glass blur and fades on scroll', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1200);
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
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial State at top: User name and avatar are rendered
    expect(find.text('Ahmad Manager'), findsOneWidget);
    expect(find.byKey(const Key('home_user_avatar_image')), findsOneWidget);
    expect(find.byIcon(TablerIcons.bell), findsNothing);
    expect(find.byIcon(TablerIcons.dots_vertical), findsOneWidget);

    // Initial state: glass blur and solid white status bar are not rendered (value <= 0.001)
    expect(find.byKey(const Key('home_sticky_glass_blur')), findsNothing);
    expect(find.byKey(const Key('home_sticky_status_bar_solid')), findsNothing);

    // 2. Scroll down by 250 pixels
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // allow animation to finish

    // Sticky header: User name and buttons remain visible at the top!
    expect(find.text('Ahmad Manager'), findsOneWidget);
    expect(find.byIcon(TablerIcons.bell), findsNothing);
    expect(find.byIcon(TablerIcons.dots_vertical), findsOneWidget);

    // Status bar solid white background is now rendered
    expect(find.byKey(const Key('home_sticky_status_bar_solid')), findsOneWidget);
    final statusBarContainer = tester.widget<Container>(
      find.byKey(const Key('home_sticky_status_bar_solid')),
    );
    expect(statusBarContainer.color, equals(Colors.white));

    // Glass blur is now rendered on app bar info user due to scroll trigger
    expect(find.byKey(const Key('home_sticky_glass_blur')), findsOneWidget);

    // 3. Scroll back to top
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // allow fade-out animation to settle

    // Glass blur and solid status bar fade out and return to SizedBox.shrink
    expect(find.byKey(const Key('home_sticky_glass_blur')), findsNothing);
    expect(find.byKey(const Key('home_sticky_status_bar_solid')), findsNothing);
    expect(find.text('Ahmad Manager'), findsOneWidget);
  });
}
