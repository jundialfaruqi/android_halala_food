import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/core/widgets/app_card.dart';

import 'package:android_halala_food/features/home/data/models/dashboard_stat_model.dart';
import 'package:android_halala_food/features/home/presentation/viewmodels/home_stat_viewmodel.dart';

class _MockAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Manager Test',
        email: 'manager@halala-food.id',
        permissions: const ['produk-view'],
        roles: const ['manager'],
      ),
    );
  }
}

class _MockHomeStatViewModel extends HomeStatViewModel {
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

void main() {
  testWidgets('Home screen menu item icon container has custom asymmetric rounded corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _MockAuthViewModel()),
          homeStatViewModelProvider.overrideWith(() => _MockHomeStatViewModel()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Produk menu item text is rendered
    expect(find.text('Produk'), findsOneWidget);

    // Verify GridView has 5 columns
    final gridFinder = find.byType(GridView);
    expect(gridFinder, findsOneWidget);
    final gridView = tester.widget<GridView>(gridFinder);
    final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, equals(5));

    // Find the Container that holds the icon with 52x52 dimensions
    final containerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 52 &&
          widget.constraints?.maxHeight == 52 &&
          widget.decoration is BoxDecoration,
    );

    expect(containerFinder, findsWidgets);

    final containerWidget = tester.widget<Container>(containerFinder.first);
    final decoration = containerWidget.decoration as BoxDecoration;

    expect(decoration.borderRadius, isA<BorderRadius>());
    final borderRadius = decoration.borderRadius as BorderRadius;

    expect(borderRadius.topLeft, equals(const Radius.circular(22)));
    expect(borderRadius.topRight, equals(Radius.zero));
    expect(borderRadius.bottomRight, equals(const Radius.circular(22)));
    expect(borderRadius.bottomLeft, equals(Radius.zero));
  });

  testWidgets('Home screen stats card and stack have inverted custom asymmetric rounded corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _MockAuthViewModel()),
          homeStatViewModelProvider.overrideWith(() => _MockHomeStatViewModel()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header Ringkasan Hari Ini is present in stats card
    expect(find.text('Ringkasan Hari Ini'), findsOneWidget);

    // Find the AppCard widget used for the stats card
    final appCardFinder = find.byWidgetPredicate(
      (widget) => widget is AppCard && widget.customBorderRadius != null,
    );

    expect(appCardFinder, findsOneWidget);

    final appCardWidget = tester.widget<AppCard>(appCardFinder);
    final borderRadius = appCardWidget.customBorderRadius!;

    expect(borderRadius.topLeft, equals(Radius.zero));
    expect(borderRadius.topRight, equals(const Radius.circular(24)));
    expect(borderRadius.bottomRight, equals(Radius.zero));
    expect(borderRadius.bottomLeft, equals(const Radius.circular(24)));
  });
}
