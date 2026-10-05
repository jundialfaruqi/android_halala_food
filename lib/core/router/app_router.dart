import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/viewmodels/auth_state.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_screen.dart';
import '../../features/auth/presentation/views/splash_screen.dart';
import '../../features/home/presentation/views/home_screen.dart';
import '../widgets/widgets.dart';
import 'app_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [
      appRouteObserver,
    ],
    initialLocation: AppRoutes.splash,
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authState = ref.read(authViewModelProvider);
      final currentLoc = state.matchedLocation;

      final isSplash = currentLoc == AppRoutes.splash;
      final isLoggingIn = currentLoc == AppRoutes.login;

      // 1. Saat masih initial status (aplikasi baru dibuka, sedang cek auth di splash screen)
      if (authState.status == AuthStatus.initial) {
        return isSplash ? null : AppRoutes.splash;
      }

      // 2. Jika user sudah login (authenticated)
      if (authState.isAuthenticated) {
        if (isSplash || isLoggingIn) {
          return AppRoutes.home;
        }
        return null; // biarkan menuju route yang dituju
      }

      // 3. Jika sedang loading (misal: memproses login di LoginScreen)
      if (authState.isLoading) {
        return isSplash ? null : null;
      }

      // 4. Jika belum login (unauthenticated / error)
      if (!isLoggingIn) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authViewModelProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          // Tutup seluruh modal/pushed screen di atas root navigator jika sesi berakhir / logout
          if (next.status == AuthStatus.unauthenticated &&
              previous?.status == AuthStatus.authenticated) {
            rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
          notifyListeners();
        }
      },
    );
  }
}
