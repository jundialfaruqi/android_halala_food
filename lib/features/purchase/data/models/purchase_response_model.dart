import 'purchase_model.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class PurchaseResponseModel {
  final List<PurchaseModel> purchases;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final double monthlyTotalAmount;
  final int monthlyTotalCount;
  final double totalUnpaidDebt;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const PurchaseResponseModel({
    required this.purchases,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.monthlyTotalAmount,
    required this.monthlyTotalCount,
    required this.totalUnpaidDebt,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });

  bool get hasMore => currentPage < lastPage;

  factory PurchaseResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['purchases'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseModel.fromJson)
            .toList() ??
        [];

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final permissions = json['permissions'] as Map<String, dynamic>? ?? {};

    return PurchaseResponseModel(
      purchases: list,
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
      monthlyTotalAmount: _parseDouble(stats['monthly_total_amount']),
      monthlyTotalCount: stats['monthly_total_count'] is int
          ? stats['monthly_total_count'] as int
          : (int.tryParse(stats['monthly_total_count']?.toString() ?? '') ?? 0),
      totalUnpaidDebt: _parseDouble(stats['total_unpaid_debt']),
      canCreate: permissions['can_create'] == true,
      canEdit: permissions['can_edit'] == true,
      canDelete: permissions['can_delete'] == true,
    );
  }
}
