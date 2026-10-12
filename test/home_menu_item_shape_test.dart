import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/home/presentation/views/home_screen.dart';
import 'package:android_halala_food/core/widgets/app_card.dart';

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

void main() {
  testWidgets('Home screen menu item icon container has custom asymmetric rounded corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _MockAuthViewModel()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Produk menu item text is rendered
    expect(find.text('Produk'), findsOneWidget);

    // Find the Container that holds the icon with 58x58 dimensions
    final containerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 58 &&
          widget.constraints?.maxHeight == 58 &&
          widget.decoration is BoxDecoration,
    );

    expect(containerFinder, findsWidgets);

    final containerWidget = tester.widget<Container>(containerFinder.first);
    final decoration = containerWidget.decoration as BoxDecoration;

    expect(decoration.borderRadius, isA<BorderRadius>());
    final borderRadius = decoration.borderRadius as BorderRadius;

    expect(borderRadius.topLeft, equals(const Radius.circular(24)));
    expect(borderRadius.topRight, equals(Radius.zero));
    expect(borderRadius.bottomRight, equals(const Radius.circular(24)));
    expect(borderRadius.bottomLeft, equals(Radius.zero));
  });

  testWidgets('Home screen stats card and stack have inverted custom asymmetric rounded corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _MockAuthViewModel()),
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
