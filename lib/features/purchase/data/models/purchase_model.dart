import 'package:intl/intl.dart';
import 'purchase_item_model.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class PurchaseModel {
  final int id;
  final String purchaseNumber;
  final String supplierName;
  final String purchaseDate;
  final double totalAmount;
  final String paymentMethod; // 'tunai', 'transfer_bank', 'tempo'
  final String paymentStatus; // 'lunas', 'belum_lunas'
  final double paidAmount;
  final double remainingDebt;
  final String? paidAt;
  final int? paidAccountId;
  final String? paidAccountName;
  final String? notes;
  final int? createdBy;
  final String? creatorName;
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    required this.purchaseNumber,
    required this.supplierName,
    required this.purchaseDate,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paidAmount,
    required this.remainingDebt,
    this.paidAt,
    this.paidAccountId,
    this.paidAccountName,
    this.notes,
    this.createdBy,
    this.creatorName,
    this.items = const [],
  });

  bool get isLunas => paymentStatus == 'lunas';
  bool get isTempo => paymentMethod == 'tempo';

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'tunai':
        return 'Tunai (Cash)';
      case 'transfer_bank':
        return 'Transfer Bank';
      case 'tempo':
        return 'Tempo (Kredit)';
      default:
        return paymentMethod;
    }
  }

  String get paymentStatusLabel {
    if (paymentStatus == 'lunas') {
      return 'Lunas';
    }
    return 'Belum Lunas';
  }

  String get formattedPurchaseDate {
    try {
      final dt = DateTime.parse(purchaseDate);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return purchaseDate;
    }
  }

  String get itemsSummary {
    if (items.isEmpty) return 'Tanpa rincian item';
    return items
        .map((it) =>
            '${it.rawMaterialName} (${it.quantity.toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2)} ${it.unitName})')
        .join(', ');
  }

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseItemModel.fromJson)
            .toList() ??
        [];

    final creator = json['creator'] is Map<String, dynamic>
        ? json['creator'] as Map<String, dynamic>
        : null;

    final paidAccount = json['paid_account'] is Map<String, dynamic>
        ? json['paid_account'] as Map<String, dynamic>
        : null;

    final total = _parseDouble(json['total_amount']);
    final paid = _parseDouble(json['paid_amount']);
    final remainingRaw = json['remaining_debt'];
    final remaining = remainingRaw != null
        ? _parseDouble(remainingRaw)
        : (json['payment_method'] == 'tempo' && json['payment_status'] != 'lunas'
            ? (total - paid > 0 ? total - paid : 0.0)
            : 0.0);

    return PurchaseModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      purchaseNumber: json['purchase_number']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      purchaseDate: json['purchase_date']?.toString() ?? '',
      totalAmount: total,
      paymentMethod: json['payment_method']?.toString() ?? 'tunai',
      paymentStatus: json['payment_status']?.toString() ?? 'lunas',
      paidAmount: paid,
      remainingDebt: remaining,
      paidAt: json['paid_at']?.toString(),
      paidAccountId: json['paid_account_id'] is int
          ? json['paid_account_id'] as int
          : int.tryParse(json['paid_account_id']?.toString() ?? ''),
      paidAccountName: paidAccount?['name']?.toString(),
      notes: json['notes']?.toString(),
      createdBy: json['created_by'] is int
          ? json['created_by'] as int
          : int.tryParse(json['created_by']?.toString() ?? ''),
      creatorName: creator?['name']?.toString(),
      items: itemsList,
    );
  }
}
