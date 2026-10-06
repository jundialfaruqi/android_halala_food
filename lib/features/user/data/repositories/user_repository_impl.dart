import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../models/user_management_model.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final remoteDataSource = ref.watch(userRemoteDataSourceProvider);
  return UserRepositoryImpl(remoteDataSource: remoteDataSource);
});

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _remoteDataSource;

  UserRepositoryImpl({required UserRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<UserListResult> getUsers({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  }) {
    return _remoteDataSource.getUsers(
      search: search,
      role: role,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<RoleModel>> getRoles() {
    return _remoteDataSource.getRoles();
  }

  @override
  Future<UserManagementModel> getUserDetail(int id) {
    return _remoteDataSource.getUserDetail(id);
  }

  @override
  Future<UserManagementModel> createUser(Map<String, dynamic> data) {
    return _remoteDataSource.createUser(data);
  }

  @override
  Future<UserManagementModel> updateUser(int id, Map<String, dynamic> data) {
    return _remoteDataSource.updateUser(id, data);
  }

  @override
  Future<void> deleteUser(int id) {
    return _remoteDataSource.deleteUser(id);
  }
}
