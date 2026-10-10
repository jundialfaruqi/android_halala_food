import 'package:intl/intl.dart';

/// Model Rincian Bahan Baku yang Digunakan pada Batch Produksi
class ProductionBatchMaterialModel {
  final int id;
  final int rawMaterialId;
  final String rawMaterialName;
  final String unitName;
  final double plannedQty;
  final double actualUsedQty;
  final double costPerUnit;
  final double subtotalCost;

  const ProductionBatchMaterialModel({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.unitName,
    required this.plannedQty,
    required this.actualUsedQty,
    required this.costPerUnit,
    required this.subtotalCost,
  });

  factory ProductionBatchMaterialModel.fromJson(Map<String, dynamic> json) {
    return ProductionBatchMaterialModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      rawMaterialId: json['raw_material_id'] is int
          ? json['raw_material_id']
          : int.tryParse(json['raw_material_id'].toString()) ?? 0,
      rawMaterialName: json['raw_material_name']?.toString() ?? 'Bahan Baku',
      unitName: json['unit_name']?.toString() ?? 'gr',
      plannedQty: json['planned_qty'] is num
          ? (json['planned_qty'] as num).toDouble()
          : double.tryParse(json['planned_qty'].toString()) ?? 0.0,
      actualUsedQty: json['actual_used_qty'] is num
          ? (json['actual_used_qty'] as num).toDouble()
          : double.tryParse(json['actual_used_qty'].toString()) ?? 0.0,
      costPerUnit: json['cost_per_unit'] is num
          ? (json['cost_per_unit'] as num).toDouble()
          : double.tryParse(json['cost_per_unit'].toString()) ?? 0.0,
      subtotalCost: json['subtotal_cost'] is num
          ? (json['subtotal_cost'] as num).toDouble()
          : double.tryParse(json['subtotal_cost'].toString()) ?? 0.0,
    );
  }

  String get subtotalCostFormatted {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(subtotalCost);
  }

  String get costPerUnitFormatted {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(costPerUnit);
  }
}

/// Model Statistik Ringkasan KPI Produksi
class ProductionStatsModel {
  final int totalBatches;
  final int totalGood;
  final int totalBad;
  final double totalCost;
  final double successRate;

  const ProductionStatsModel({
    required this.totalBatches,
    required this.totalGood,
    required this.totalBad,
    required this.totalCost,
    required this.successRate,
  });

  factory ProductionStatsModel.fromJson(Map<String, dynamic> json) {
    return ProductionStatsModel(
      totalBatches: json['total_batches'] is int
          ? json['total_batches']
          : int.tryParse(json['total_batches'].toString()) ?? 0,
      totalGood: json['total_good'] is int
          ? json['total_good']
          : int.tryParse(json['total_good'].toString()) ?? 0,
      totalBad: json['total_bad'] is int
          ? json['total_bad']
          : int.tryParse(json['total_bad'].toString()) ?? 0,
      totalCost: json['total_cost'] is num
          ? (json['total_cost'] as num).toDouble()
          : double.tryParse(json['total_cost'].toString()) ?? 0.0,
      successRate: json['success_rate'] is num
          ? (json['success_rate'] as num).toDouble()
          : double.tryParse(json['success_rate'].toString()) ?? 100.0,
    );
  }

  String get totalCostFormatted {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(totalCost);
  }
}

/// Model Batch Masak Produksi
class ProductionBatchModel {
  final int id;
  final String batchCode;
  final int productId;
  final String productName;
  final String productUnit;
  final String? productPhotoUrl;
  final int? userId;
  final String operatorName;
  final int plannedQty;
  final int actualQtyGood;
  final int actualQtyBad;
  final double totalMaterialCost;
  final double unitCostProduced;
  final String status;
  final String statusLabel;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final List<ProductionBatchMaterialModel> materials;

  const ProductionBatchModel({
    required this.id,
    required this.batchCode,
    required this.productId,
    required this.productName,
    required this.productUnit,
    this.productPhotoUrl,
    this.userId,
    required this.operatorName,
    required this.plannedQty,
    required this.actualQtyGood,
    required this.actualQtyBad,
    required this.totalMaterialCost,
    required this.unitCostProduced,
    required this.status,
    required this.statusLabel,
    this.notes,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.materials = const [],
  });

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory ProductionBatchModel.fromJson(Map<String, dynamic> json) {
    return ProductionBatchModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      batchCode: json['batch_code']?.toString() ?? '-',
      productId: json['product_id'] is int
          ? json['product_id']
          : int.tryParse(json['product_id'].toString()) ?? 0,
      productName: json['product_name']?.toString() ?? 'Produk',
      productUnit: json['product_unit']?.toString() ?? 'pcs',
      productPhotoUrl: json['product_photo_url']?.toString(),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      operatorName: json['operator_name']?.toString() ?? 'Sistem',
      plannedQty: json['planned_qty'] is int
          ? json['planned_qty']
          : int.tryParse(json['planned_qty'].toString()) ?? 0,
      actualQtyGood: json['actual_qty_good'] is int
          ? json['actual_qty_good']
          : int.tryParse(json['actual_qty_good'].toString()) ?? 0,
      actualQtyBad: json['actual_qty_bad'] is int
          ? json['actual_qty_bad']
          : int.tryParse(json['actual_qty_bad'].toString()) ?? 0,
      totalMaterialCost: json['total_material_cost'] is num
          ? (json['total_material_cost'] as num).toDouble()
          : double.tryParse(json['total_material_cost'].toString()) ?? 0.0,
      unitCostProduced: json['unit_cost_produced'] is num
          ? (json['unit_cost_produced'] as num).toDouble()
          : double.tryParse(json['unit_cost_produced'].toString()) ?? 0.0,
      status: json['status']?.toString() ?? 'completed',
      statusLabel: json['status_label']?.toString() ?? 'Selesai',
      notes: json['notes']?.toString(),
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      materials: (json['materials'] as List<dynamic>?)
              ?.map((m) => ProductionBatchMaterialModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String get totalMaterialCostFormatted {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(totalMaterialCost);
  }

  String get unitCostProducedFormatted {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(unitCostProduced);
  }

  String get formattedDate {
    final dt = completedAt ?? createdAt;
    if (dt == null) return '-';
    return DateFormat('d MMM y, HH:mm', 'id_ID').format(dt.toLocal());
  }
}
