/// Model Rincian Resep Bahan per Unit Produk
class ProductionRecipeItemModel {
  final int id;
  final int rawMaterialId;
  final String rawMaterialName;
  final double quantityNeeded;
  final String unit;
  final double currentStock;
  final double costPerUnit;

  const ProductionRecipeItemModel({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.quantityNeeded,
    required this.unit,
    required this.currentStock,
    required this.costPerUnit,
  });

  factory ProductionRecipeItemModel.fromJson(Map<String, dynamic> json) {
    return ProductionRecipeItemModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      rawMaterialId: json['raw_material_id'] is int
          ? json['raw_material_id']
          : int.tryParse(json['raw_material_id'].toString()) ?? 0,
      rawMaterialName: json['raw_material_name']?.toString() ?? 'Bahan Baku',
      quantityNeeded: json['quantity_needed'] is num
          ? (json['quantity_needed'] as num).toDouble()
          : double.tryParse(json['quantity_needed'].toString()) ?? 0.0,
      unit: json['unit']?.toString() ?? 'gr',
      currentStock: json['current_stock'] is num
          ? (json['current_stock'] as num).toDouble()
          : double.tryParse(json['current_stock'].toString()) ?? 0.0,
      costPerUnit: json['cost_per_unit'] is num
          ? (json['cost_per_unit'] as num).toDouble()
          : double.tryParse(json['cost_per_unit'].toString()) ?? 0.0,
    );
  }
}

/// Model Pilihan Produk Jadi untuk Batch Masak
class ProductionProductOptionModel {
  final int id;
  final String name;
  final String unit;
  final double price;
  final int stockReady;
  final String? photoUrl;
  final bool hasRecipe;
  final int recipesCount;
  final List<ProductionRecipeItemModel> recipes;

  const ProductionProductOptionModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stockReady,
    this.photoUrl,
    required this.hasRecipe,
    required this.recipesCount,
    this.recipes = const [],
  });

  factory ProductionProductOptionModel.fromJson(Map<String, dynamic> json) {
    return ProductionProductOptionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Produk',
      unit: json['unit']?.toString() ?? 'pcs',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price'].toString()) ?? 0.0,
      stockReady: json['stock_ready'] is int
          ? json['stock_ready']
          : int.tryParse(json['stock_ready'].toString()) ?? 0,
      photoUrl: json['photo_url']?.toString(),
      hasRecipe: json['has_recipe'] == true,
      recipesCount: json['recipes_count'] is int
          ? json['recipes_count']
          : int.tryParse(json['recipes_count']?.toString() ?? '0') ?? 0,
      recipes: (json['recipes'] as List<dynamic>?)
              ?.map((r) => ProductionRecipeItemModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Model Pilihan Bahan Baku
class ProductionRawMaterialOptionModel {
  final int id;
  final String name;
  final double stock;
  final String unit;
  final double costPerUnit;

  const ProductionRawMaterialOptionModel({
    required this.id,
    required this.name,
    required this.stock,
    required this.unit,
    required this.costPerUnit,
  });

  factory ProductionRawMaterialOptionModel.fromJson(Map<String, dynamic> json) {
    return ProductionRawMaterialOptionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Bahan Baku',
      stock: json['stock'] is num
          ? (json['stock'] as num).toDouble()
          : double.tryParse(json['stock'].toString()) ?? 0.0,
      unit: json['unit']?.toString() ?? 'gr',
      costPerUnit: json['cost_per_unit'] is num
          ? (json['cost_per_unit'] as num).toDouble()
          : double.tryParse(json['cost_per_unit'].toString()) ?? 0.0,
    );
  }
}

/// Model Respons Opsi Form Produksi
class ProductionOptionsModel {
  final String nextBatchCode;
  final List<ProductionProductOptionModel> products;
  final List<ProductionRawMaterialOptionModel> rawMaterials;

  const ProductionOptionsModel({
    required this.nextBatchCode,
    required this.products,
    required this.rawMaterials,
  });

  factory ProductionOptionsModel.fromJson(Map<String, dynamic> json) {
    return ProductionOptionsModel(
      nextBatchCode: json['next_batch_code']?.toString() ?? '-',
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => ProductionProductOptionModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      rawMaterials: (json['raw_materials'] as List<dynamic>?)
              ?.map((m) => ProductionRawMaterialOptionModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
