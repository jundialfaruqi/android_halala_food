import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    secureStorage: secureStorage,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.login(
      email: email,
      password: password,
    );

    // Simpan access token & refresh token ke Secure Storage
    await _secureStorage.saveAccessToken(result.tokens.accessToken);
    if (result.tokens.refreshToken != null) {
      await _secureStorage.saveRefreshToken(result.tokens.refreshToken!);
    }

    // Simpan user profile ke Secure Storage
    await _secureStorage.write(
      StorageKeys.userProfile,
      jsonEncode(result.user.toJson()),
    );

    return result.user;
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Abaikan error jaringan saat logout, tetap bersihkan data lokal
    } finally {
      await _secureStorage.clearSession();
    }
  }

  @override
  Future<UserModel?> getSavedUser() async {
    final userJsonStr = await _secureStorage.read(StorageKeys.userProfile);
    if (userJsonStr != null && userJsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        return UserModel.fromJson(userMap);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<AuthTokensModel?> getSavedTokens() async {
    final accessToken = await _secureStorage.getAccessToken();
    final refreshToken = await _secureStorage.getRefreshToken();

    if (accessToken != null) {
      return AuthTokensModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
    return null;
  }
}
