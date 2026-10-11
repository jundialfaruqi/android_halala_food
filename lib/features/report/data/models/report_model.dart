class ReportDataModel {
  final String period;
  final String startDate;
  final String endDate;
  final ReportOverviewModel overview;
  final ReportStoresSectionModel stores;
  final ReportStockWasteSectionModel stockWaste;
  final ReportSettingsModel settings;

  const ReportDataModel({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.overview,
    required this.stores,
    required this.stockWaste,
    required this.settings,
  });

  factory ReportDataModel.fromJson(Map<String, dynamic> json) {
    return ReportDataModel(
      period: json['period']?.toString() ?? 'this_month',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      overview: ReportOverviewModel.fromJson(
        json['overview'] as Map<String, dynamic>? ?? {},
      ),
      stores: ReportStoresSectionModel.fromJson(
        json['stores'] as Map<String, dynamic>? ?? {},
      ),
      stockWaste: ReportStockWasteSectionModel.fromJson(
        json['stock_waste'] as Map<String, dynamic>? ?? {},
      ),
      settings: ReportSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class ReportOverviewModel {
  final double totalInvoiced;
  final double totalPaidOnInvoices;
  final double totalReceivables;
  final double cashIn;
  final double purchasesCost;
  final double productionHpp;
  final double grossProfit;

  const ReportOverviewModel({
    required this.totalInvoiced,
    required this.totalPaidOnInvoices,
    required this.totalReceivables,
    required this.cashIn,
    required this.purchasesCost,
    required this.productionHpp,
    required this.grossProfit,
  });

  factory ReportOverviewModel.fromJson(Map<String, dynamic> json) {
    return ReportOverviewModel(
      totalInvoiced: _toDouble(json['total_invoiced']),
      totalPaidOnInvoices: _toDouble(json['total_paid_on_invoices']),
      totalReceivables: _toDouble(json['total_receivables']),
      cashIn: _toDouble(json['cash_in']),
      purchasesCost: _toDouble(json['purchases_cost']),
      productionHpp: _toDouble(json['production_hpp']),
      grossProfit: _toDouble(json['gross_profit']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportStoresSectionModel {
  final ReportStoresSummaryModel summary;
  final List<ReportStoreItemModel> items;

  const ReportStoresSectionModel({
    required this.summary,
    required this.items,
  });

  factory ReportStoresSectionModel.fromJson(Map<String, dynamic> json) {
    return ReportStoresSectionModel(
      summary: ReportStoresSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ReportStoreItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReportStoresSummaryModel {
  final int totalStores;
  final int totalDeliveries;
  final double totalBill;
  final double totalPaid;
  final double totalBalance;

  const ReportStoresSummaryModel({
    required this.totalStores,
    required this.totalDeliveries,
    required this.totalBill,
    required this.totalPaid,
    required this.totalBalance,
  });

  factory ReportStoresSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportStoresSummaryModel(
      totalStores: json['total_stores'] is num
          ? (json['total_stores'] as num).toInt()
          : int.tryParse(json['total_stores']?.toString() ?? '0') ?? 0,
      totalDeliveries: json['total_deliveries'] is num
          ? (json['total_deliveries'] as num).toInt()
          : int.tryParse(json['total_deliveries']?.toString() ?? '0') ?? 0,
      totalBill: _toDouble(json['total_bill']),
      totalPaid: _toDouble(json['total_paid']),
      totalBalance: _toDouble(json['total_balance']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportStoreItemModel {
  final int id;
  final String name;
  final String? owner;
  final String? phone;
  final String? route;
  final int deliveriesCount;
  final double totalBill;
  final double totalPaid;
  final double balance;
  final String status;

  const ReportStoreItemModel({
    required this.id,
    required this.name,
    this.owner,
    this.phone,
    this.route,
    required this.deliveriesCount,
    required this.totalBill,
    required this.totalPaid,
    required this.balance,
    required this.status,
  });

  factory ReportStoreItemModel.fromJson(Map<String, dynamic> json) {
    return ReportStoreItemModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '-',
      owner: json['owner']?.toString(),
      phone: json['phone']?.toString(),
      route: json['route']?.toString(),
      deliveriesCount: json['deliveries_count'] is num
          ? (json['deliveries_count'] as num).toInt()
          : int.tryParse(json['deliveries_count']?.toString() ?? '0') ?? 0,
      totalBill: _toDouble(json['total_bill']),
      totalPaid: _toDouble(json['total_paid']),
      balance: _toDouble(json['balance']),
      status: json['status']?.toString() ?? 'belum_ada_transaksi',
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportStockWasteSectionModel {
  final double totalRawMaterialValue;
  final double totalProductStockValue;
  final double totalInventoryValue;
  final List<ReportRawMaterialItemModel> rawMaterials;
  final List<ReportProductItemModel> products;

  const ReportStockWasteSectionModel({
    required this.totalRawMaterialValue,
    required this.totalProductStockValue,
    required this.totalInventoryValue,
    required this.rawMaterials,
    required this.products,
  });

  factory ReportStockWasteSectionModel.fromJson(Map<String, dynamic> json) {
    return ReportStockWasteSectionModel(
      totalRawMaterialValue: _toDouble(json['total_raw_material_value']),
      totalProductStockValue: _toDouble(json['total_product_stock_value']),
      totalInventoryValue: _toDouble(json['total_inventory_value']),
      rawMaterials: (json['raw_materials'] as List<dynamic>? ?? [])
          .map((e) =>
              ReportRawMaterialItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => ReportProductItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportRawMaterialItemModel {
  final int id;
  final String name;
  final String? code;
  final double stock;
  final String displayUnit;
  final double costPerUnit;
  final double valuation;

  const ReportRawMaterialItemModel({
    required this.id,
    required this.name,
    this.code,
    required this.stock,
    required this.displayUnit,
    required this.costPerUnit,
    required this.valuation,
  });

  factory ReportRawMaterialItemModel.fromJson(Map<String, dynamic> json) {
    return ReportRawMaterialItemModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '-',
      code: json['code']?.toString(),
      stock: _toDouble(json['stock']),
      displayUnit: json['display_unit']?.toString() ?? 'satuan',
      costPerUnit: _toDouble(json['cost_per_unit']),
      valuation: _toDouble(json['valuation']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportProductItemModel {
  final int id;
  final String name;
  final String? code;
  final int stockReady;
  final String unit;
  final double consignmentPrice;
  final double valuation;

  const ReportProductItemModel({
    required this.id,
    required this.name,
    this.code,
    required this.stockReady,
    required this.unit,
    required this.consignmentPrice,
    required this.valuation,
  });

  factory ReportProductItemModel.fromJson(Map<String, dynamic> json) {
    return ReportProductItemModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '-',
      code: json['code']?.toString(),
      stockReady: json['stock_ready'] is num
          ? (json['stock_ready'] as num).toInt()
          : int.tryParse(json['stock_ready']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? 'pcs',
      consignmentPrice: _toDouble(json['consignment_price']),
      valuation: _toDouble(json['valuation']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ReportSettingsModel {
  final String companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyEmail;

  const ReportSettingsModel({
    required this.companyName,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
  });

  factory ReportSettingsModel.fromJson(Map<String, dynamic> json) {
    return ReportSettingsModel(
      companyName: json['company_name']?.toString() ?? 'Halala Food',
      companyAddress: json['company_address']?.toString(),
      companyPhone: json['company_phone']?.toString(),
      companyEmail: json['company_email']?.toString(),
    );
  }
}
