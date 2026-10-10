import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/purchase_options_model.dart';
import '../../data/repositories/purchase_repository_impl.dart';
import '../../domain/repositories/purchase_repository.dart';

class PurchaseState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting;
  final List<PurchaseModel> purchases;
  final String searchQuery;
  final String selectedPaymentMethod; // 'all', 'tunai', 'transfer_bank', 'tempo'
  final String selectedPaymentStatus; // 'all', 'lunas', 'belum_lunas'
  final double monthlyTotalAmount;
  final int monthlyTotalCount;
  final double totalUnpaidDebt;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final String? errorMessage;

  const PurchaseState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.purchases = const [],
    this.searchQuery = '',
    this.selectedPaymentMethod = 'all',
    this.selectedPaymentStatus = 'all',
    this.monthlyTotalAmount = 0.0,
    this.monthlyTotalCount = 0,
    this.totalUnpaidDebt = 0.0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.errorMessage,
  });

  bool get hasMore => currentPage < lastPage;
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedPaymentMethod != 'all' ||
      selectedPaymentStatus != 'all';

  PurchaseState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    List<PurchaseModel>? purchases,
    String? searchQuery,
    String? selectedPaymentMethod,
    String? selectedPaymentStatus,
    double? monthlyTotalAmount,
    int? monthlyTotalCount,
    double? totalUnpaidDebt,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      purchases: purchases ?? this.purchases,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedPaymentStatus:
          selectedPaymentStatus ?? this.selectedPaymentStatus,
      monthlyTotalAmount: monthlyTotalAmount ?? this.monthlyTotalAmount,
      monthlyTotalCount: monthlyTotalCount ?? this.monthlyTotalCount,
      totalUnpaidDebt: totalUnpaidDebt ?? this.totalUnpaidDebt,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final purchaseViewModelProvider =
    NotifierProvider<PurchaseViewModel, PurchaseState>(PurchaseViewModel.new);

class PurchaseViewModel extends Notifier<PurchaseState> {
  late final PurchaseRepository _repository;

  @override
  PurchaseState build() {
    _repository = ref.watch(purchaseRepositoryProvider);
    Future.microtask(() => loadPurchases());
    return const PurchaseState();
  }

  Future<void> loadPurchases({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final res = await _repository.getPurchases(
        search: state.searchQuery,
        paymentMethod: state.selectedPaymentMethod,
        paymentStatus: state.selectedPaymentStatus,
        page: 1,
      );

      state = state.copyWith(
        isLoading: false,
        purchases: res.purchases,
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
        monthlyTotalAmount: res.monthlyTotalAmount,
        monthlyTotalCount: res.monthlyTotalCount,
        totalUnpaidDebt: res.totalUnpaidDebt,
        canCreate: res.canCreate,
        canEdit: res.canEdit,
        canDelete: res.canDelete,
      );
    } catch (e, stack) {
      debugPrint('[PurchaseViewModel] loadPurchases failed: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final res = await _repository.getPurchases(
        search: state.searchQuery,
        paymentMethod: state.selectedPaymentMethod,
        paymentStatus: state.selectedPaymentStatus,
        page: nextPage,
      );

      state = state.copyWith(
        isLoadingMore: false,
        purchases: [...state.purchases, ...res.purchases],
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
      );
    } catch (e, stack) {
      debugPrint('[PurchaseViewModel] loadMore failed: $e\n$stack');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadPurchases();
  }

  void setPaymentMethod(String method) {
    if (state.selectedPaymentMethod == method) return;
    state = state.copyWith(selectedPaymentMethod: method);
    loadPurchases();
  }

  void setPaymentStatus(String status) {
    if (state.selectedPaymentStatus == status) return;
    state = state.copyWith(selectedPaymentStatus: status);
    loadPurchases();
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedPaymentMethod: 'all',
      selectedPaymentStatus: 'all',
    );
    loadPurchases();
  }

  Future<PurchaseOptionsModel> getPurchaseOptions() {
    return _repository.getPurchaseOptions();
  }

  Future<PurchaseModel> getPurchaseDetail(int id) {
    return _repository.getPurchaseDetail(id);
  }

  Future<bool> createPurchase(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.createPurchase(data);
      state = state.copyWith(isSubmitting: false);
      await loadPurchases(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[PurchaseViewModel] createPurchase failed: $e\n$stack');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> payDebt(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.payDebt(id, data);
      state = state.copyWith(isSubmitting: false);
      await loadPurchases(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[PurchaseViewModel] payDebt failed: $e\n$stack');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deletePurchase(int id) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.deletePurchase(id);
      state = state.copyWith(isSubmitting: false);
      await loadPurchases(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[PurchaseViewModel] deletePurchase failed: $e\n$stack');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
