import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../../domain/repositories/delivery_repository.dart';

class DeliveryState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<DeliveryModel> deliveries;
  final int total;
  final int currentPage;
  final int lastPage;
  final String selectedStatus; // 'all', 'diproses', 'dikirim', 'selesai', 'dibatalkan'
  final String? selectedRoute;
  final String searchQuery;
  final Map<String, int> statusCounts;
  final List<String> availableRoutes;
  final bool isCourier;
  final int? currentUserId;
  final String? errorMessage;

  const DeliveryState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.deliveries = const [],
    this.total = 0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.selectedStatus = 'all',
    this.selectedRoute,
    this.searchQuery = '',
    this.statusCounts = const {
      'all': 0,
      'diproses': 0,
      'dikirim': 0,
      'selesai': 0,
      'dibatalkan': 0,
    },
    this.availableRoutes = const [],
    this.isCourier = false,
    this.currentUserId,
    this.errorMessage,
  });

  bool get hasMore => currentPage < lastPage;
  bool get hasFilter =>
      selectedStatus != 'all' ||
      selectedRoute != null ||
      searchQuery.isNotEmpty;

  DeliveryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<DeliveryModel>? deliveries,
    int? total,
    int? currentPage,
    int? lastPage,
    String? selectedStatus,
    String? selectedRoute,
    bool clearRoute = false,
    String? searchQuery,
    Map<String, int>? statusCounts,
    List<String>? availableRoutes,
    bool? isCourier,
    int? currentUserId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DeliveryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      deliveries: deliveries ?? this.deliveries,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedRoute: clearRoute ? null : (selectedRoute ?? this.selectedRoute),
      searchQuery: searchQuery ?? this.searchQuery,
      statusCounts: statusCounts ?? this.statusCounts,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      isCourier: isCourier ?? this.isCourier,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final deliveryViewModelProvider =
    NotifierProvider<DeliveryViewModel, DeliveryState>(DeliveryViewModel.new);

class DeliveryViewModel extends Notifier<DeliveryState> {
  late final DeliveryRepository _repository;

  @override
  DeliveryState build() {
    _repository = ref.watch(deliveryRepositoryProvider);
    Future.microtask(() => loadInitialData());
    return const DeliveryState(isLoading: true);
  }

  Future<void> loadInitialData() async {
    try {
      final options = await _repository.getOptions();
      state = state.copyWith(availableRoutes: options.routes);
    } catch (_) {}
    await loadDeliveries(refresh: true);
  }

  Future<void> loadDeliveries({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getDeliveries(
        page: 1,
        perPage: 15,
        search: state.searchQuery,
        status: state.selectedStatus,
        route: state.selectedRoute,
      );

      state = state.copyWith(
        isLoading: false,
        deliveries: result.deliveries,
        total: result.total,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        statusCounts: result.statusCounts,
        availableRoutes: result.routes.isNotEmpty
            ? result.routes
            : state.availableRoutes,
        isCourier: result.isCourier,
        currentUserId: result.currentUserId,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _repository.getDeliveries(
        page: nextPage,
        perPage: 15,
        search: state.searchQuery,
        status: state.selectedStatus,
        route: state.selectedRoute,
      );

      state = state.copyWith(
        isLoadingMore: false,
        deliveries: [...state.deliveries, ...result.deliveries],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        statusCounts: result.statusCounts,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setStatusFilter(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    loadDeliveries(refresh: true);
  }

  void setRouteFilter(String? route) {
    if (state.selectedRoute == route) return;
    state = state.copyWith(
      selectedRoute: route,
      clearRoute: route == null,
    );
    loadDeliveries(refresh: true);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadDeliveries(refresh: true);
  }

  Future<bool> dispatchDelivery(int id) async {
    try {
      final updated = await _repository.dispatchDelivery(id);
      final list = state.deliveries.map((d) => d.id == id ? updated : d).toList();
      state = state.copyWith(deliveries: list);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> cancelDelivery(int id) async {
    try {
      final updated = await _repository.cancelDelivery(id);
      final list = state.deliveries.map((d) => d.id == id ? updated : d).toList();
      state = state.copyWith(deliveries: list);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteDelivery(int id) async {
    try {
      await _repository.deleteDelivery(id);
      final list = state.deliveries.where((d) => d.id != id).toList();
      state = state.copyWith(
        deliveries: list,
        total: state.total > 0 ? state.total - 1 : 0,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
