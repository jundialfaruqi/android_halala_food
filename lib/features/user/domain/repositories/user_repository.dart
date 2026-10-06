import '../../data/models/user_management_model.dart';

abstract class UserRepository {
  Future<UserListResult> getUsers({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  });

  Future<List<RoleModel>> getRoles();

  Future<UserManagementModel> getUserDetail(int id);

  Future<UserManagementModel> createUser(Map<String, dynamic> data);

  Future<UserManagementModel> updateUser(int id, Map<String, dynamic> data);

  Future<void> deleteUser(int id);
}
