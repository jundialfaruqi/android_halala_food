double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class PurchaseItemModel {
  final int id;
  final int purchaseId;
  final int rawMaterialId;
  final String rawMaterialName;
  final String unitName;
  final double quantity;
  final double costPerUnit;
  final double subtotal;
  final String? notes;

  const PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.unitName,
    required this.quantity,
    required this.costPerUnit,
    required this.subtotal,
    this.notes,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    final rawMat = json['raw_material'] is Map<String, dynamic>
        ? json['raw_material'] as Map<String, dynamic>
        : null;

    final unitModel = rawMat != null && rawMat['unit_model'] is Map<String, dynamic>
        ? rawMat['unit_model'] as Map<String, dynamic>
        : null;

    final rawName = rawMat?['name']?.toString() ?? 'Bahan Baku #${json['raw_material_id']}';
    final unit = unitModel?['name']?.toString() ??
        unitModel?['short_name']?.toString() ??
        rawMat?['display_unit']?.toString() ??
        '';

    return PurchaseItemModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      purchaseId: json['purchase_id'] is int
          ? json['purchase_id'] as int
          : (int.tryParse(json['purchase_id']?.toString() ?? '') ?? 0),
      rawMaterialId: json['raw_material_id'] is int
          ? json['raw_material_id'] as int
          : (int.tryParse(json['raw_material_id']?.toString() ?? '') ?? 0),
      rawMaterialName: rawName,
      unitName: unit,
      quantity: _parseDouble(json['quantity']),
      costPerUnit: _parseDouble(json['cost_per_unit']),
      subtotal: _parseDouble(json['subtotal']),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'raw_material_id': rawMaterialId,
      'quantity': quantity,
      'cost_per_unit': costPerUnit,
      'subtotal': subtotal,
      'notes': notes,
    };
  }
}
