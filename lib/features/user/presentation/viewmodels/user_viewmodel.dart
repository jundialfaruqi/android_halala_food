import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_management_model.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';

class UserState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<UserManagementModel> users;
  final List<RoleModel> availableRoles;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMore;
  final String searchQuery;
  final String selectedRole; // 'all', 'dev', 'manager', 'kurir', dll.
  final String? errorMessage;

  const UserState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.users = const [],
    this.availableRoles = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.hasMore = false,
    this.searchQuery = '',
    this.selectedRole = 'all',
    this.errorMessage,
  });

  bool get hasFilter => searchQuery.isNotEmpty || selectedRole != 'all';

  UserState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<UserManagementModel>? users,
    List<RoleModel>? availableRoles,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? hasMore,
    String? searchQuery,
    String? selectedRole,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      users: users ?? this.users,
      availableRoles: availableRoles ?? this.availableRoles,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRole: selectedRole ?? this.selectedRole,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final userViewModelProvider =
    NotifierProvider<UserViewModel, UserState>(UserViewModel.new);

class UserViewModel extends Notifier<UserState> {
  late final UserRepository _repository;
  Timer? _debounceTimer;

  @override
  UserState build() {
    _repository = ref.watch(userRepositoryProvider);
    Future.microtask(() {
      fetchRoles();
      fetchUsers(refresh: true);
    });
    return const UserState(isLoading: true);
  }

  Future<void> fetchRoles() async {
    try {
      final roles = await _repository.getRoles();
      state = state.copyWith(availableRoles: roles);
    } catch (_) {
      // Ignore error roles fetch
    }
  }

  Future<void> fetchUsers({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getUsers(
        search: state.searchQuery,
        role: state.selectedRole,
        page: 1,
        perPage: 20,
      );

      state = state.copyWith(
        isLoading: false,
        users: result.users,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        hasMore: result.hasMore,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _repository.getUsers(
        search: state.searchQuery,
        role: state.selectedRole,
        page: nextPage,
        perPage: 20,
      );

      state = state.copyWith(
        isLoadingMore: false,
        users: [...state.users, ...result.users],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(searchQuery: query.trim());
      fetchUsers(refresh: true);
    });
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(searchQuery: '');
    fetchUsers(refresh: true);
  }

  void selectRole(String role) {
    if (state.selectedRole == role) return;
    state = state.copyWith(selectedRole: role);
    fetchUsers(refresh: true);
  }

  void resetFilters() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      searchQuery: '',
      selectedRole: 'all',
    );
    fetchUsers(refresh: true);
  }

  Future<UserManagementModel> createUser(Map<String, dynamic> data) async {
    final newUser = await _repository.createUser(data);
    await fetchUsers(refresh: true);
    return newUser;
  }

  Future<UserManagementModel> updateUser(int id, Map<String, dynamic> data) async {
    final updatedUser = await _repository.updateUser(id, data);
    await fetchUsers(refresh: true);
    return updatedUser;
  }

  Future<void> deleteUser(int id) async {
    await _repository.deleteUser(id);
    state = state.copyWith(
      users: state.users.where((u) => u.id != id).toList(),
      total: state.total > 0 ? state.total - 1 : 0,
    );
  }
}
