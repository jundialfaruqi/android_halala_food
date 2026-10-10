class RawMaterialModel {
  final int id;
  final String name;
  final int? unitId;
  final String? unitName;
  final String unitShort;
  final double stock;
  final double minStock;
  final double costPerUnit;
  final String costFormatted;
  final String stockStatus; // 'safe', 'warning', 'danger'
  final String stockStatusLabel; // 'Aman', 'Menipis', 'Habis'
  final int recipesCount;
  final String? createdAt;
  final String? updatedAt;

  const RawMaterialModel({
    required this.id,
    required this.name,
    this.unitId,
    this.unitName,
    required this.unitShort,
    required this.stock,
    required this.minStock,
    required this.costPerUnit,
    required this.costFormatted,
    required this.stockStatus,
    required this.stockStatusLabel,
    this.recipesCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSafe => stockStatus == 'safe';
  bool get isWarning => stockStatus == 'warning';
  bool get isDanger => stockStatus == 'danger';

  factory RawMaterialModel.fromJson(Map<String, dynamic> json) {
    final stockVal = json['stock'] != null
        ? double.tryParse(json['stock'].toString()) ?? 0.0
        : 0.0;
    final minStockVal = json['min_stock'] != null
        ? double.tryParse(json['min_stock'].toString()) ?? 0.0
        : 0.0;
    final costVal = json['cost_per_unit'] != null
        ? double.tryParse(json['cost_per_unit'].toString()) ?? 0.0
        : 0.0;

    final status = json['stock_status']?.toString() ??
        (stockVal <= 0
            ? 'danger'
            : (stockVal <= minStockVal ? 'warning' : 'safe'));

    return RawMaterialModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      unitId: json['unit_id'] != null
          ? (json['unit_id'] is int
              ? json['unit_id']
              : int.tryParse(json['unit_id']?.toString() ?? ''))
          : null,
      unitName: json['unit_name']?.toString(),
      unitShort: json['unit_short']?.toString() ?? 'gram',
      stock: stockVal,
      minStock: minStockVal,
      costPerUnit: costVal,
      costFormatted: json['cost_formatted']?.toString() ??
          'Rp ${costVal.toStringAsFixed(2)}',
      stockStatus: status,
      stockStatusLabel: json['stock_status_label']?.toString() ??
          (status == 'safe'
              ? 'Aman'
              : (status == 'warning' ? 'Menipis' : 'Habis')),
      recipesCount: json['recipes_count'] != null
          ? (json['recipes_count'] is int
              ? json['recipes_count']
              : int.tryParse(json['recipes_count']?.toString() ?? '0') ?? 0)
          : 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class RawMaterialSummaryModel {
  final int totalMaterials;
  final int safeMaterials;
  final int warningMaterials;
  final int dangerMaterials;
  final double totalInventoryValue;
  final String totalInventoryValueFormatted;

  const RawMaterialSummaryModel({
    required this.totalMaterials,
    required this.safeMaterials,
    required this.warningMaterials,
    required this.dangerMaterials,
    required this.totalInventoryValue,
    required this.totalInventoryValueFormatted,
  });

  factory RawMaterialSummaryModel.fromJson(Map<String, dynamic> json) {
    return RawMaterialSummaryModel(
      totalMaterials: json['total_materials'] is int
          ? json['total_materials']
          : int.tryParse(json['total_materials']?.toString() ?? '0') ?? 0,
      safeMaterials: json['safe_materials'] is int
          ? json['safe_materials']
          : int.tryParse(json['safe_materials']?.toString() ?? '0') ?? 0,
      warningMaterials: json['warning_materials'] is int
          ? json['warning_materials']
          : int.tryParse(json['warning_materials']?.toString() ?? '0') ?? 0,
      dangerMaterials: json['danger_materials'] is int
          ? json['danger_materials']
          : int.tryParse(json['danger_materials']?.toString() ?? '0') ?? 0,
      totalInventoryValue: json['total_inventory_value'] != null
          ? double.tryParse(json['total_inventory_value'].toString()) ?? 0.0
          : 0.0,
      totalInventoryValueFormatted:
          json['total_inventory_value_formatted']?.toString() ?? 'Rp 0',
    );
  }
}

class RawMaterialUnitOptionModel {
  final int id;
  final String name;
  final String shortName;

  const RawMaterialUnitOptionModel({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory RawMaterialUnitOptionModel.fromJson(Map<String, dynamic> json) {
    return RawMaterialUnitOptionModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
    );
  }
}

class ProductRecipeItemModel {
  final int id;
  final int rawMaterialId;
  final String materialName;
  final String unitShort;
  final double costPerUnit;
  final String costFormatted;
  final double quantityNeeded;
  final double subtotalCost;
  final String subtotalFormatted;

  const ProductRecipeItemModel({
    required this.id,
    required this.rawMaterialId,
    required this.materialName,
    required this.unitShort,
    required this.costPerUnit,
    required this.costFormatted,
    required this.quantityNeeded,
    required this.subtotalCost,
    required this.subtotalFormatted,
  });

  factory ProductRecipeItemModel.fromJson(Map<String, dynamic> json) {
    return ProductRecipeItemModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      rawMaterialId: json['raw_material_id'] is int
          ? json['raw_material_id']
          : int.tryParse(json['raw_material_id']?.toString() ?? '0') ?? 0,
      materialName: json['material_name']?.toString() ?? 'Bahan',
      unitShort: json['unit_short']?.toString() ?? '-',
      costPerUnit: json['cost_per_unit'] != null
          ? double.tryParse(json['cost_per_unit'].toString()) ?? 0.0
          : 0.0,
      costFormatted: json['cost_formatted']?.toString() ?? '',
      quantityNeeded: json['quantity_needed'] != null
          ? double.tryParse(json['quantity_needed'].toString()) ?? 0.0
          : 0.0,
      subtotalCost: json['subtotal_cost'] != null
          ? double.tryParse(json['subtotal_cost'].toString()) ?? 0.0
          : 0.0,
      subtotalFormatted: json['subtotal_formatted']?.toString() ?? '',
    );
  }
}

class ProductBOMModel {
  final int id;
  final String name;
  final int? unitId;
  final String? unitName;
  final double consignmentPrice;
  final String consignmentFormatted;
  final double retailPrice;
  final String retailFormatted;
  final double materialCost;
  final String materialCostFormatted;
  final double grossMargin;
  final List<ProductRecipeItemModel> recipes;
  final int recipesCount;

  const ProductBOMModel({
    required this.id,
    required this.name,
    this.unitId,
    this.unitName,
    required this.consignmentPrice,
    required this.consignmentFormatted,
    required this.retailPrice,
    required this.retailFormatted,
    required this.materialCost,
    required this.materialCostFormatted,
    required this.grossMargin,
    required this.recipes,
    required this.recipesCount,
  });

  factory ProductBOMModel.fromJson(Map<String, dynamic> json) {
    final recipeList = <ProductRecipeItemModel>[];
    if (json['recipes'] is List) {
      for (final r in json['recipes'] as List) {
        if (r is Map<String, dynamic>) {
          recipeList.add(ProductRecipeItemModel.fromJson(r));
        }
      }
    }

    return ProductBOMModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      unitId: json['unit_id'] != null
          ? (json['unit_id'] is int
              ? json['unit_id']
              : int.tryParse(json['unit_id']?.toString() ?? ''))
          : null,
      unitName: json['unit_name']?.toString(),
      consignmentPrice: json['consignment_price'] != null
          ? double.tryParse(json['consignment_price'].toString()) ?? 0.0
          : 0.0,
      consignmentFormatted: json['consignment_formatted']?.toString() ?? 'Rp 0',
      retailPrice: json['retail_price'] != null
          ? double.tryParse(json['retail_price'].toString()) ?? 0.0
          : 0.0,
      retailFormatted: json['retail_formatted']?.toString() ?? 'Rp 0',
      materialCost: json['material_cost'] != null
          ? double.tryParse(json['material_cost'].toString()) ?? 0.0
          : 0.0,
      materialCostFormatted:
          json['material_cost_formatted']?.toString() ?? 'Rp 0',
      grossMargin: json['gross_margin'] != null
          ? double.tryParse(json['gross_margin'].toString()) ?? 0.0
          : 0.0,
      recipes: recipeList,
      recipesCount: json['recipes_count'] != null
          ? (json['recipes_count'] is int
              ? json['recipes_count']
              : int.tryParse(json['recipes_count']?.toString() ?? '0') ??
                  recipeList.length)
          : recipeList.length,
    );
  }
}
