import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_management_model.dart';

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UserRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class UserRemoteDataSource {
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

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final DioClient _dioClient;

  UserRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<UserListResult> getUsers({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    if (role != null && role.trim().isNotEmpty && role != 'all') {
      queryParams['role'] = role.trim();
    }

    final response = await _dioClient.get(
      ApiEndpoints.users,
      queryParameters: queryParams,
    );

    final List<UserManagementModel> users = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            users.add(UserManagementModel.fromJson(item));
          }
        }
      }
    }

    int currentPage = page;
    int lastPage = page;
    int total = users.length;
    bool hasMore = false;

    if (response is Map<String, dynamic> && response.containsKey('pagination')) {
      final pagination = response['pagination'];
      if (pagination is Map<String, dynamic>) {
        currentPage = pagination['current_page'] ?? page;
        lastPage = pagination['last_page'] ?? page;
        total = pagination['total'] ?? users.length;
        hasMore = pagination['has_more'] ?? (currentPage < lastPage);
      }
    }

    return UserListResult(
      users: users,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      hasMore: hasMore,
    );
  }

  @override
  Future<List<RoleModel>> getRoles() async {
    final response = await _dioClient.get(ApiEndpoints.userRoles);

    final List<RoleModel> roles = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            roles.add(RoleModel.fromJson(item));
          }
        }
      }
    }

    return roles;
  }

  @override
  Future<UserManagementModel> getUserDetail(int id) async {
    final response = await _dioClient.get('${ApiEndpoints.users}/$id');

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return UserManagementModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }

    throw Exception('Format data pengguna tidak valid.');
  }

  @override
  Future<UserManagementModel> createUser(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.users,
      data: data,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return UserManagementModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }

    throw Exception('Gagal menyimpan data pengguna.');
  }

  @override
  Future<UserManagementModel> updateUser(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dioClient.put(
      '${ApiEndpoints.users}/$id',
      data: data,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return UserManagementModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }

    throw Exception('Gagal memperbarui data pengguna.');
  }

  @override
  Future<void> deleteUser(int id) async {
    await _dioClient.delete('${ApiEndpoints.users}/$id');
  }
}
