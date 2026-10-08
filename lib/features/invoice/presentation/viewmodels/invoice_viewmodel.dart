import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/repositories/invoice_repository.dart';

class InvoiceState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<InvoiceModel> invoices;
  final int total;
  final int currentPage;
  final int lastPage;
  final String selectedStatus; // 'all', 'belum_dibayar', 'sebagian', 'lunas', 'overdue', 'dibatalkan'
  final int? selectedStoreId;
  final String searchQuery;
  final Map<String, int> statusCounts;
  final List<InvoiceStoreModel> availableStores;
  final String? errorMessage;

  const InvoiceState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.invoices = const [],
    this.total = 0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.selectedStatus = 'all',
    this.selectedStoreId,
    this.searchQuery = '',
    this.statusCounts = const {
      'all': 0,
      'belum_dibayar': 0,
      'sebagian': 0,
      'lunas': 0,
      'overdue': 0,
      'dibatalkan': 0,
    },
    this.availableStores = const [],
    this.errorMessage,
  });

  bool get hasMore => currentPage < lastPage;
  bool get hasFilter =>
      selectedStatus != 'all' ||
      selectedStoreId != null ||
      searchQuery.isNotEmpty;

  InvoiceState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<InvoiceModel>? invoices,
    int? total,
    int? currentPage,
    int? lastPage,
    String? selectedStatus,
    int? selectedStoreId,
    bool clearStore = false,
    String? searchQuery,
    Map<String, int>? statusCounts,
    List<InvoiceStoreModel>? availableStores,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InvoiceState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      invoices: invoices ?? this.invoices,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedStoreId:
          clearStore ? null : (selectedStoreId ?? this.selectedStoreId),
      searchQuery: searchQuery ?? this.searchQuery,
      statusCounts: statusCounts ?? this.statusCounts,
      availableStores: availableStores ?? this.availableStores,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final invoiceViewModelProvider =
    NotifierProvider<InvoiceViewModel, InvoiceState>(InvoiceViewModel.new);

class InvoiceViewModel extends Notifier<InvoiceState> {
  late final InvoiceRepository _repository;

  @override
  InvoiceState build() {
    _repository = ref.watch(invoiceRepositoryProvider);
    Future.microtask(() => loadInvoices(refresh: true));
    return const InvoiceState(isLoading: true);
  }

  Future<void> loadInvoices({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getInvoices(
        page: 1,
        perPage: 15,
        search: state.searchQuery,
        status: state.selectedStatus,
        storeId: state.selectedStoreId,
      );

      state = state.copyWith(
        isLoading: false,
        invoices: result.invoices,
        total: result.total,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        statusCounts: result.statusCounts,
        availableStores: result.stores.isNotEmpty
            ? result.stores
            : state.availableStores,
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
      final result = await _repository.getInvoices(
        page: nextPage,
        perPage: 15,
        search: state.searchQuery,
        status: state.selectedStatus,
        storeId: state.selectedStoreId,
      );

      state = state.copyWith(
        isLoadingMore: false,
        invoices: [...state.invoices, ...result.invoices],
        total: result.total,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        statusCounts: result.statusCounts,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setStatusFilter(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    loadInvoices(refresh: true);
  }

  void setStoreFilter(int? storeId) {
    if (state.selectedStoreId == storeId) return;
    if (storeId == null) {
      state = state.copyWith(clearStore: true);
    } else {
      state = state.copyWith(selectedStoreId: storeId);
    }
    loadInvoices(refresh: true);
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadInvoices(refresh: true);
  }

  void clearFilters() {
    state = state.copyWith(
      selectedStatus: 'all',
      clearStore: true,
      searchQuery: '',
    );
    loadInvoices(refresh: true);
  }
}
