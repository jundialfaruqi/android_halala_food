import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/app_button.dart';
import 'package:android_halala_food/core/widgets/app_text_field.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/auth/presentation/views/login_screen.dart';

class _FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  testWidgets('LoginScreen renders rounded pill text fields and rounded pill login button', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify email and password AppTextField widgets have rounded pill radius (28.0)
    final textFields = tester.widgetList<AppTextField>(find.byType(AppTextField)).toList();
    expect(textFields.length, equals(2));
    expect(textFields[0].borderRadius, equals(28.0)); // Email
    expect(textFields[1].borderRadius, equals(28.0)); // Password

    // Verify login AppButton has rounded pill radius (28.0)
    final loginButton = tester.widget<AppButton>(find.byType(AppButton));
    expect(loginButton.borderRadius, equals(28.0));
    expect(loginButton.text, equals('Masuk'));
  });
}
