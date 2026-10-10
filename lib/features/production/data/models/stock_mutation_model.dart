import 'package:intl/intl.dart';

/// Model Kartu Stok Mutasi Bahan Baku
class StockMutationModel {
  final int id;
  final int rawMaterialId;
  final String rawMaterialName;
  final String unit;
  final String referenceType;
  final int? referenceId;
  final String referenceNumber;
  final String type; // 'out' | 'in'
  final String typeLabel;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final double costPerUnit;
  final String notes;
  final int? userId;
  final String userName;
  final DateTime? createdAt;

  const StockMutationModel({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.unit,
    required this.referenceType,
    this.referenceId,
    required this.referenceNumber,
    required this.type,
    required this.typeLabel,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.costPerUnit,
    required this.notes,
    this.userId,
    required this.userName,
    this.createdAt,
  });

  bool get isOut => type == 'out';
  bool get isIn => type == 'in';

  factory StockMutationModel.fromJson(Map<String, dynamic> json) {
    return StockMutationModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      rawMaterialId: json['raw_material_id'] is int
          ? json['raw_material_id']
          : int.tryParse(json['raw_material_id'].toString()) ?? 0,
      rawMaterialName: json['raw_material_name']?.toString() ?? 'Bahan Baku',
      unit: json['unit']?.toString() ?? 'gr',
      referenceType: json['reference_type']?.toString() ?? '-',
      referenceId: json['reference_id'] is int
          ? json['reference_id']
          : int.tryParse(json['reference_id']?.toString() ?? ''),
      referenceNumber: json['reference_number']?.toString() ?? '-',
      type: json['type']?.toString() ?? 'out',
      typeLabel: json['type_label']?.toString() ??
          (json['type'] == 'out' ? 'Produksi (Keluar)' : 'Masuk (Koreksi)'),
      quantity: json['quantity'] is num
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity'].toString()) ?? 0.0,
      stockBefore: json['stock_before'] is num
          ? (json['stock_before'] as num).toDouble()
          : double.tryParse(json['stock_before'].toString()) ?? 0.0,
      stockAfter: json['stock_after'] is num
          ? (json['stock_after'] as num).toDouble()
          : double.tryParse(json['stock_after'].toString()) ?? 0.0,
      costPerUnit: json['cost_per_unit'] is num
          ? (json['cost_per_unit'] as num).toDouble()
          : double.tryParse(json['cost_per_unit'].toString()) ?? 0.0,
      notes: json['notes']?.toString() ?? '-',
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? ''),
      userName: json['user_name']?.toString() ?? 'Sistem',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  String get quantityFormatted {
    final prefix = isOut ? '- ' : '+ ';
    final qtyStr = quantity.truncateToDouble() == quantity
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
    return '$prefix$qtyStr $unit';
  }

  String get stockBeforeFormatted {
    return stockBefore.truncateToDouble() == stockBefore
        ? stockBefore.toInt().toString()
        : stockBefore.toStringAsFixed(2);
  }

  String get stockAfterFormatted {
    return stockAfter.truncateToDouble() == stockAfter
        ? stockAfter.toInt().toString()
        : stockAfter.toStringAsFixed(2);
  }

  String get formattedDate {
    if (createdAt == null) return '-';
    return DateFormat('d MMM y, HH:mm', 'id_ID').format(createdAt!.toLocal());
  }
}
