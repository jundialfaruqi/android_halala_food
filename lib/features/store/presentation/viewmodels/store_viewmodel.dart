import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/store_model.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../domain/repositories/store_repository.dart';

class StoreState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<StoreModel> stores;
  final StorePaginationModel? pagination;
  final String searchQuery;
  final String? selectedRoute;
  final List<String> availableRoutes;
  final String? errorMessage;

  const StoreState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.stores = const [],
    this.pagination,
    this.searchQuery = '',
    this.selectedRoute,
    this.availableRoutes = const [],
    this.errorMessage,
  });

  bool get hasMore => pagination?.hasMore ?? false;
  int get currentPage => pagination?.currentPage ?? 1;
  int get total => pagination?.total ?? stores.length;
  bool get hasFilter => searchQuery.isNotEmpty || selectedRoute != null;

  StoreState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<StoreModel>? stores,
    StorePaginationModel? pagination,
    String? searchQuery,
    String? selectedRoute,
    bool clearRoute = false,
    List<String>? availableRoutes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      stores: stores ?? this.stores,
      pagination: pagination ?? this.pagination,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRoute: clearRoute ? null : (selectedRoute ?? this.selectedRoute),
      availableRoutes: availableRoutes ?? this.availableRoutes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final storeViewModelProvider =
    NotifierProvider<StoreViewModel, StoreState>(StoreViewModel.new);

class StoreViewModel extends Notifier<StoreState> {
  late final StoreRepository _repository;

  @override
  StoreState build() {
    _repository = ref.watch(storeRepositoryProvider);
    // Fetch data dan daftar rute otomatis saat pertama kali dibuka
    Future.microtask(() {
      fetchRoutes();
      fetchStores(refresh: true);
    });
    return const StoreState(isLoading: true);
  }

  Future<void> fetchRoutes() async {
    try {
      final routes = await _repository.getRoutes();
      state = state.copyWith(availableRoutes: routes);
    } catch (_) {
      // Ignore route fetch error or keep existing routes
    }
  }

  Future<void> fetchStores({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getStores(
        search: state.searchQuery,
        route: state.selectedRoute,
        page: 1,
        perPage: 15,
      );

      state = state.copyWith(
        isLoading: false,
        stores: result.stores,
        pagination: result.pagination,
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
      final result = await _repository.getStores(
        search: state.searchQuery,
        route: state.selectedRoute,
        page: nextPage,
        perPage: 15,
      );

      state = state.copyWith(
        isLoadingMore: false,
        stores: [...state.stores, ...result.stores],
        pagination: result.pagination,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void onSearchChanged(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
    fetchStores(refresh: true);
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    state = state.copyWith(searchQuery: '');
    fetchStores(refresh: true);
  }

  void selectRoute(String? route) {
    // 1. Jika memilih 'Semua Rute' (route == null)
    if (route == null) {
      if (state.selectedRoute == null) return; // Sudah di 'Semua Rute', tidak perlu request ulang
      state = state.copyWith(clearRoute: true);
      fetchStores(refresh: true);
      return;
    }

    // 2. Jika menekan rute yang sama (toggle off ke 'Semua Rute')
    if (state.selectedRoute == route) {
      state = state.copyWith(clearRoute: true);
      fetchStores(refresh: true);
      return;
    }

    // 3. Jika memilih rute baru
    state = state.copyWith(selectedRoute: route);
    fetchStores(refresh: true);
  }

  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: '',
      clearRoute: true,
    );
    fetchStores(refresh: true);
  }
}
