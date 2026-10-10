import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/account_model.dart';
import '../../data/models/cash_transaction_model.dart';
import '../../data/repositories/cash_book_repository_impl.dart';
import '../../domain/repositories/cash_book_repository.dart';

class CashBookState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<CashTransactionModel> transactions;
  final List<AccountModel> accounts;
  final double totalCashBalance;
  final double filteredIncome;
  final double filteredExpense;
  final double filteredPrive;
  final int currentPage;
  final int lastPage;
  final int total;
  final String searchQuery;
  final String selectedType; // 'all', 'income', 'expense', 'prive'
  final int? selectedAccountId;
  final String selectedPeriod; // 'all', 'today', 'this_month'
  final String? startDate;
  final String? endDate;
  final bool canCreate;
  final bool canDelete;
  final String? errorMessage;

  const CashBookState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.transactions = const [],
    this.accounts = const [],
    this.totalCashBalance = 0.0,
    this.filteredIncome = 0.0,
    this.filteredExpense = 0.0,
    this.filteredPrive = 0.0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.searchQuery = '',
    this.selectedType = 'all',
    this.selectedAccountId,
    this.selectedPeriod = 'all',
    this.startDate,
    this.endDate,
    this.canCreate = false,
    this.canDelete = false,
    this.errorMessage,
  });

  bool get hasMore => currentPage < lastPage;
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedType != 'all' ||
      selectedAccountId != null ||
      selectedPeriod != 'all';

  CashBookState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<CashTransactionModel>? transactions,
    List<AccountModel>? accounts,
    double? totalCashBalance,
    double? filteredIncome,
    double? filteredExpense,
    double? filteredPrive,
    int? currentPage,
    int? lastPage,
    int? total,
    String? searchQuery,
    String? selectedType,
    int? selectedAccountId,
    bool clearAccount = false,
    String? selectedPeriod,
    String? startDate,
    String? endDate,
    bool clearDates = false,
    bool? canCreate,
    bool? canDelete,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashBookState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      transactions: transactions ?? this.transactions,
      accounts: accounts ?? this.accounts,
      totalCashBalance: totalCashBalance ?? this.totalCashBalance,
      filteredIncome: filteredIncome ?? this.filteredIncome,
      filteredExpense: filteredExpense ?? this.filteredExpense,
      filteredPrive: filteredPrive ?? this.filteredPrive,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType ?? this.selectedType,
      selectedAccountId:
          clearAccount ? null : (selectedAccountId ?? this.selectedAccountId),
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      canCreate: canCreate ?? this.canCreate,
      canDelete: canDelete ?? this.canDelete,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final cashBookViewModelProvider =
    NotifierProvider<CashBookViewModel, CashBookState>(
        CashBookViewModel.new);

class CashBookViewModel extends Notifier<CashBookState> {
  late final CashBookRepository _repository;

  @override
  CashBookState build() {
    _repository = ref.watch(cashBookRepositoryProvider);
    Future.microtask(() => loadCashBook());
    return const CashBookState();
  }

  Future<void> loadCashBook({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final res = await _repository.getCashBook(
        search: state.searchQuery,
        type: state.selectedType,
        accountId: state.selectedAccountId,
        startDate: state.startDate,
        endDate: state.endDate,
        page: 1,
      );

      state = state.copyWith(
        isLoading: false,
        transactions: res.transactions,
        accounts: res.accounts,
        totalCashBalance: res.totalCashBalance,
        filteredIncome: res.filteredIncome,
        filteredExpense: res.filteredExpense,
        filteredPrive: res.filteredPrive,
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
        canCreate: res.canCreate,
        canDelete: res.canDelete,
      );
    } catch (e, stack) {
      debugPrint('[CashBookViewModel] loadCashBook failed: $e\n$stack');
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
      final res = await _repository.getCashBook(
        search: state.searchQuery,
        type: state.selectedType,
        accountId: state.selectedAccountId,
        startDate: state.startDate,
        endDate: state.endDate,
        page: nextPage,
      );

      state = state.copyWith(
        isLoadingMore: false,
        transactions: [...state.transactions, ...res.transactions],
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        total: res.total,
      );
    } catch (e, stack) {
      debugPrint('[CashBookViewModel] loadMore failed: $e\n$stack');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadCashBook();
  }

  void setType(String type) {
    if (state.selectedType == type) return;
    state = state.copyWith(selectedType: type);
    loadCashBook();
  }

  void setAccount(int? accountId) {
    if (state.selectedAccountId == accountId) return;
    state = state.copyWith(
      selectedAccountId: accountId,
      clearAccount: accountId == null,
    );
    loadCashBook();
  }

  void setQuickPeriod(String period) {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    String? start;
    String? end;

    if (period == 'today') {
      final todayStr = fmt.format(now);
      start = todayStr;
      end = todayStr;
    } else if (period == 'this_month') {
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      start = fmt.format(firstDay);
      end = fmt.format(lastDay);
    } else {
      // all
      start = null;
      end = null;
    }

    state = state.copyWith(
      selectedPeriod: period,
      startDate: start,
      endDate: end,
      clearDates: period == 'all',
    );
    loadCashBook();
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedType: 'all',
      clearAccount: true,
      selectedPeriod: 'all',
      clearDates: true,
    );
    loadCashBook();
  }

  Future<bool> createTransaction(Map<String, dynamic> data) async {
    try {
      await _repository.createTransaction(data);
      await loadCashBook(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[CashBookViewModel] createTransaction failed: $e\n$stack');
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadCashBook(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[CashBookViewModel] deleteTransaction failed: $e\n$stack');
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> createAccount(Map<String, dynamic> data) async {
    try {
      await _repository.createAccount(data);
      await loadCashBook(refresh: true);
      return true;
    } catch (e, stack) {
      debugPrint('[CashBookViewModel] createAccount failed: $e\n$stack');
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
