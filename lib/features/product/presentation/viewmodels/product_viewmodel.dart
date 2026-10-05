import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/product_repository.dart';

class ProductState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<ProductModel> products;
  final ProductPaginationModel? pagination;
  final String searchQuery;
  final String selectedStatus; // 'all', 'active', 'inactive'
  final int? selectedUnitId;
  final List<ProductUnitModel> availableUnits;
  final String? errorMessage;

  const ProductState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.products = const [],
    this.pagination,
    this.searchQuery = '',
    this.selectedStatus = 'all',
    this.selectedUnitId,
    this.availableUnits = const [],
    this.errorMessage,
  });

  bool get hasMore => pagination?.hasMore ?? false;
  int get currentPage => pagination?.currentPage ?? 1;
  int get total => pagination?.total ?? products.length;
  bool get hasFilter =>
      searchQuery.isNotEmpty ||
      selectedStatus != 'all' ||
      selectedUnitId != null;

  ProductState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<ProductModel>? products,
    ProductPaginationModel? pagination,
    String? searchQuery,
    String? selectedStatus,
    int? selectedUnitId,
    bool clearUnit = false,
    List<ProductUnitModel>? availableUnits,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      products: products ?? this.products,
      pagination: pagination ?? this.pagination,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedUnitId: clearUnit ? null : (selectedUnitId ?? this.selectedUnitId),
      availableUnits: availableUnits ?? this.availableUnits,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final productViewModelProvider =
    NotifierProvider<ProductViewModel, ProductState>(ProductViewModel.new);

class ProductViewModel extends Notifier<ProductState> {
  late final ProductRepository _repository;

  @override
  ProductState build() {
    _repository = ref.watch(productRepositoryProvider);
    Future.microtask(() {
      fetchUnits();
      fetchProducts(refresh: true);
    });
    return const ProductState(isLoading: true);
  }

  Future<void> fetchUnits() async {
    try {
      final units = await _repository.getUnits();
      state = state.copyWith(availableUnits: units);
    } catch (_) {
      // Ignore units fetch error
    }
  }

  Future<void> fetchProducts({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getProducts(
        search: state.searchQuery,
        status: state.selectedStatus,
        unitId: state.selectedUnitId,
        page: 1,
        perPage: 20,
      );

      state = state.copyWith(
        isLoading: false,
        products: result.products,
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
      final result = await _repository.getProducts(
        search: state.searchQuery,
        status: state.selectedStatus,
        unitId: state.selectedUnitId,
        page: nextPage,
        perPage: 20,
      );

      state = state.copyWith(
        isLoadingMore: false,
        products: [...state.products, ...result.products],
        pagination: result.pagination,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void onSearchChanged(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
    fetchProducts(refresh: true);
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    state = state.copyWith(searchQuery: '');
    fetchProducts(refresh: true);
  }

  void selectStatus(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    fetchProducts(refresh: true);
  }

  void selectUnit(int? unitId) {
    final effectiveUnitId = (unitId == null || unitId <= 0) ? null : unitId;
    if (state.selectedUnitId == effectiveUnitId) return;
    state = state.copyWith(
      selectedUnitId: effectiveUnitId,
      clearUnit: effectiveUnitId == null,
    );
    fetchProducts(refresh: true);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedStatus: 'all',
      clearUnit: true,
    );
    fetchProducts(refresh: true);
  }
}
