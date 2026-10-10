import 'account_model.dart';
import 'cash_transaction_model.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class CashBookResponseModel {
  final List<CashTransactionModel> transactions;
  final List<AccountModel> accounts;
  final double totalCashBalance;
  final double filteredIncome;
  final double filteredExpense;
  final double filteredPrive;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool canCreate;
  final bool canDelete;

  const CashBookResponseModel({
    required this.transactions,
    required this.accounts,
    required this.totalCashBalance,
    required this.filteredIncome,
    required this.filteredExpense,
    required this.filteredPrive,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.canCreate,
    required this.canDelete,
  });

  bool get hasMore => currentPage < lastPage;

  factory CashBookResponseModel.fromJson(Map<String, dynamic> json) {
    final transactionsList = (json['transactions'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(CashTransactionModel.fromJson)
            .toList() ??
        [];

    final accountsList = (json['accounts'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(AccountModel.fromJson)
            .toList() ??
        [];

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    final permissions = json['permissions'] as Map<String, dynamic>? ?? {};

    return CashBookResponseModel(
      transactions: transactionsList,
      accounts: accountsList,
      totalCashBalance: _parseDouble(json['total_cash_balance']),
      filteredIncome: _parseDouble(json['filtered_income']),
      filteredExpense: _parseDouble(json['filtered_expense']),
      filteredPrive: _parseDouble(json['filtered_prive']),
      currentPage: pagination['current_page'] is int
          ? pagination['current_page'] as int
          : (int.tryParse(pagination['current_page']?.toString() ?? '') ?? 1),
      lastPage: pagination['last_page'] is int
          ? pagination['last_page'] as int
          : (int.tryParse(pagination['last_page']?.toString() ?? '') ?? 1),
      perPage: pagination['per_page'] is int
          ? pagination['per_page'] as int
          : (int.tryParse(pagination['per_page']?.toString() ?? '') ?? 15),
      total: pagination['total'] is int
          ? pagination['total'] as int
          : (int.tryParse(pagination['total']?.toString() ?? '') ?? 0),
      canCreate: permissions['can_create'] == true,
      canDelete: permissions['can_delete'] == true,
    );
  }
}
