import '../../data/models/auth_tokens_model.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<UserModel?> getSavedUser();

  Future<bool> isAuthenticated();

  Future<AuthTokensModel?> getSavedTokens();
}
