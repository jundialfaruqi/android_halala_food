import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class AuthRemoteDataSource {
  Future<({AuthTokensModel tokens, UserModel user})> login({
    required String email,
    required String password,
  });

  Future<AuthTokensModel> refreshToken(String refreshToken);

  Future<void> logout();

  Future<UserModel> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({AuthTokensModel tokens, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response is Map<String, dynamic> && response.containsKey('data')
        ? response['data']
        : response;

    final tokens = AuthTokensModel.fromJson(data);
    final user = UserModel.fromJson(data['user'] ?? data);

    return (tokens: tokens, user: user);
  }

  @override
  Future<AuthTokensModel> refreshToken(String refreshToken) async {
    final response = await _dioClient.post(
      ApiEndpoints.refreshToken,
      data: {'refresh_token': refreshToken},
    );

    final data = response is Map<String, dynamic> && response.containsKey('data')
        ? response['data']
        : response;

    return AuthTokensModel.fromJson(data);
  }

  @override
  Future<void> logout() async {
    await _dioClient.post(ApiEndpoints.logout);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _dioClient.get(ApiEndpoints.me);
    final data = response is Map<String, dynamic> && response.containsKey('data')
        ? response['data']
        : response;

    return UserModel.fromJson(data);
  }
}
