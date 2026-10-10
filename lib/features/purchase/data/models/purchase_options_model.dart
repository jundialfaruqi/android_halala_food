double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class PurchaseRawMaterialOption {
  final int id;
  final String name;
  final double stock;
  final String displayUnit;
  final String unitName;
  final double costPerUnit;

  const PurchaseRawMaterialOption({
    required this.id,
    required this.name,
    required this.stock,
    required this.displayUnit,
    required this.unitName,
    required this.costPerUnit,
  });

  factory PurchaseRawMaterialOption.fromJson(Map<String, dynamic> json) {
    return PurchaseRawMaterialOption(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      stock: _parseDouble(json['stock']),
      displayUnit: json['display_unit']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      costPerUnit: _parseDouble(json['cost_per_unit']),
    );
  }
}

class PurchaseAccountOption {
  final int id;
  final String name;
  final String type;
  final double balance;

  const PurchaseAccountOption({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  factory PurchaseAccountOption.fromJson(Map<String, dynamic> json) {
    return PurchaseAccountOption(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'business',
      balance: _parseDouble(json['balance']),
    );
  }
}

class PurchaseOptionsModel {
  final String purchaseNumber;
  final String purchaseDate;
  final List<PurchaseRawMaterialOption> rawMaterials;
  final List<PurchaseAccountOption> accounts;

  const PurchaseOptionsModel({
    required this.purchaseNumber,
    required this.purchaseDate,
    required this.rawMaterials,
    required this.accounts,
  });

  factory PurchaseOptionsModel.fromJson(Map<String, dynamic> json) {
    final materials = (json['raw_materials'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseRawMaterialOption.fromJson)
            .toList() ??
        [];

    final accs = (json['accounts'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseAccountOption.fromJson)
            .toList() ??
        [];

    return PurchaseOptionsModel(
      purchaseNumber: json['purchase_number']?.toString() ?? '',
      purchaseDate: json['purchase_date']?.toString() ?? '',
      rawMaterials: materials,
      accounts: accs,
    );
  }
}
