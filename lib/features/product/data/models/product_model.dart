class ProductModel {
  final int id;
  final String name;
  final int? unitId;
  final String? unitName;
  final String? unitShort;
  final double consignmentPrice;
  final String consignmentPriceFormatted;
  final double retailPrice;
  final String retailPriceFormatted;
  final int stockReady;
  final String? description;
  final bool isActive;
  final String? photoUrl;

  const ProductModel({
    required this.id,
    required this.name,
    this.unitId,
    this.unitName,
    this.unitShort,
    required this.consignmentPrice,
    required this.consignmentPriceFormatted,
    required this.retailPrice,
    required this.retailPriceFormatted,
    required this.stockReady,
    this.description,
    this.isActive = true,
    this.photoUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
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
      unitShort: json['unit_short']?.toString(),
      consignmentPrice: json['consignment_price'] != null
          ? double.tryParse(json['consignment_price'].toString()) ?? 0.0
          : 0.0,
      consignmentPriceFormatted:
          json['consignment_price_formatted']?.toString() ??
              'Rp ${json['consignment_price'] ?? 0}',
      retailPrice: json['retail_price'] != null
          ? double.tryParse(json['retail_price'].toString()) ?? 0.0
          : 0.0,
      retailPriceFormatted:
          json['retail_price_formatted']?.toString() ??
              'Rp ${json['retail_price'] ?? 0}',
      stockReady: json['stock_ready'] != null
          ? (json['stock_ready'] is int
              ? json['stock_ready']
              : int.tryParse(json['stock_ready']?.toString() ?? '0') ?? 0)
          : 0,
      description: json['description']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
      photoUrl: json['photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit_id': unitId,
      'unit_name': unitName,
      'unit_short': unitShort,
      'consignment_price': consignmentPrice,
      'consignment_price_formatted': consignmentPriceFormatted,
      'retail_price': retailPrice,
      'retail_price_formatted': retailPriceFormatted,
      'stock_ready': stockReady,
      'description': description,
      'is_active': isActive,
      'photo_url': photoUrl,
    };
  }
}

class ProductUnitModel {
  final int id;
  final String name;
  final String shortName;

  const ProductUnitModel({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory ProductUnitModel.fromJson(Map<String, dynamic> json) {
    return ProductUnitModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
    );
  }

  String get displayName => '$name ($shortName)';
}

class ProductPaginationModel {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMore;

  const ProductPaginationModel({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });

  factory ProductPaginationModel.fromJson(Map<String, dynamic> json) {
    return ProductPaginationModel(
      currentPage: json['current_page'] is int
          ? json['current_page']
          : int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      lastPage: json['last_page'] is int
          ? json['last_page']
          : int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int
          ? json['per_page']
          : int.tryParse(json['per_page']?.toString() ?? '20') ?? 20,
      total: json['total'] is int
          ? json['total']
          : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      hasMore: json['has_more'] == true || json['has_more'] == 1,
    );
  }
}

class ProductListResult {
  final List<ProductModel> products;
  final ProductPaginationModel pagination;

  const ProductListResult({
    required this.products,
    required this.pagination,
  });
}
