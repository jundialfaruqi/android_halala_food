import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);

class AuthViewModel extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Jalankan pengecekan status autentikasi awal secara asynchronous
    Future.microtask(() => checkAuthStatus());
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _connectWebSocket(UserModel? user) async {
    if (user == null) return;
    try {
      final token =
          await ref.read(secureStorageServiceProvider).getAccessToken();
      if (token != null && token.isNotEmpty) {
        final isManagerOrDev =
            user.hasRole('dev') || user.hasRole('manager');
        await ref.read(webSocketServiceProvider).connect(
              token: token,
              userId: user.id,
              isManagerOrDev: isManagerOrDev,
            );
      }
    } catch (_) {
      // Non-blocking: kegagalan websocket tidak memutus sesi login
    }
  }

  Future<void> _syncFcmToken(UserModel? user) async {
    if (user == null) return;
    try {
      await ref.read(fcmServiceProvider).syncTokenToBackend();
    } catch (_) {
      // Non-blocking: kegagalan sync fcm tidak memutus sesi login
    }
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final isAuth = await _repository.isAuthenticated();
      if (isAuth) {
        final user = await _repository.getSavedUser();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );

        if (user != null) {
          _connectWebSocket(user);
          _syncFcmToken(user);
        }

        // Sinkronisasi data user & permissions terbaru dari API di latar belakang
        _repository.fetchUserProfile().then((freshUser) {
          state = state.copyWith(user: freshUser);
          _connectWebSocket(freshUser);
          _syncFcmToken(freshUser);
        }).catchError((_) {
          // Abaikan error jaringan saat background sync
        });
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          errorMessage: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      _connectWebSocket(user);
      _syncFcmToken(user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      ref.read(webSocketServiceProvider).disconnect();
    } catch (_) {}
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void handleSessionExpired() {
    if (state.status != AuthStatus.authenticated) return;
    try {
      ref.read(webSocketServiceProvider).disconnect();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
    AppSnackBar.showError(
      null,
      message: 'Sesi Anda telah berakhir. Silakan login kembali.',
    );
  }

  Future<UserModel?> refreshUserProfile() async {
    try {
      final user = await _repository.fetchUserProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
      return user;
    } catch (_) {
      return state.user;
    }
  }
}

/// Provider untuk mengambil data profil user realtime dari API auth me
final userProfileProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  try {
    return await repository.fetchUserProfile();
  } catch (e) {
    // Fallback ke profil yang tersimpan di lokal jika jaringan bermasalah
    final savedUser = await repository.getSavedUser();
    if (savedUser != null) {
      return savedUser;
    }
    rethrow;
  }
});
