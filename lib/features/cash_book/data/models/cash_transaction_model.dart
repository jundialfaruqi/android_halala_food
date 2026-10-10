import 'account_model.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class CashTransactionModel {
  final int id;
  final String transactionDate;
  final int accountId;
  final String type; // 'income', 'expense', 'prive'
  final String category;
  final double amount;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final String? materialsSummary;
  final AccountModel? account;

  // Detail relations (saat show atau nested)
  final Map<String, dynamic>? purchase;
  final Map<String, dynamic>? invoicePayment;
  final Map<String, dynamic>? fixedAsset;

  const CashTransactionModel({
    required this.id,
    required this.transactionDate,
    required this.accountId,
    required this.type,
    required this.category,
    required this.amount,
    this.referenceType,
    this.referenceId,
    this.description,
    this.materialsSummary,
    this.account,
    this.purchase,
    this.invoicePayment,
    this.fixedAsset,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isPrive => type == 'prive';

  String get typeLabel {
    switch (type) {
      case 'income':
        return 'Pemasukan Usaha';
      case 'expense':
        return 'Pengeluaran Usaha';
      case 'prive':
        return 'Prive';
      default:
        return type;
    }
  }

  factory CashTransactionModel.fromJson(Map<String, dynamic> json) {
    return CashTransactionModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      transactionDate: json['transaction_date']?.toString() ?? '',
      accountId: json['account_id'] is int
          ? json['account_id'] as int
          : (int.tryParse(json['account_id']?.toString() ?? '') ?? 0),
      type: json['type']?.toString() ?? 'expense',
      category: json['category']?.toString() ?? '-',
      amount: _parseDouble(json['amount']),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'] is int
          ? json['reference_id'] as int?
          : int.tryParse(json['reference_id']?.toString() ?? ''),
      description: json['description']?.toString(),
      materialsSummary: json['materials_summary']?.toString(),
      account: json['account'] != null && json['account'] is Map<String, dynamic>
          ? AccountModel.fromJson(json['account'] as Map<String, dynamic>)
          : null,
      purchase: json['purchase'] as Map<String, dynamic>?,
      invoicePayment: json['invoice_payment'] as Map<String, dynamic>?,
      fixedAsset: json['fixed_asset'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_date': transactionDate,
      'account_id': accountId,
      'type': type,
      'category': category,
      'amount': amount,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'materials_summary': materialsSummary,
      'account': account?.toJson(),
      'purchase': purchase,
      'invoice_payment': invoicePayment,
      'fixed_asset': fixedAsset,
    };
  }
}
