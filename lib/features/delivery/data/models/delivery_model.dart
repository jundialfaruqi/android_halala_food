class DeliveryStoreModel {
  final int id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? address;
  final String? route;
  final double? latitude;
  final double? longitude;

  const DeliveryStoreModel({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.address,
    this.route,
    this.latitude,
    this.longitude,
  });

  factory DeliveryStoreModel.fromJson(Map<String, dynamic> json) {
    return DeliveryStoreModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      ownerName: json['owner_name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      route: json['route'] as String?,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }
}

class DeliveryCourierModel {
  final int id;
  final String name;
  final String? phone;
  final String? username;

  const DeliveryCourierModel({
    required this.id,
    required this.name,
    this.phone,
    this.username,
  });

  factory DeliveryCourierModel.fromJson(Map<String, dynamic> json) {
    return DeliveryCourierModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      phone: json['phone'] as String?,
      username: json['username'] as String? ?? json['email'] as String?,
    );
  }
}

class DeliveryItemModel {
  final int id;
  final int deliveryId;
  final int productId;
  final String productName;
  final String productUnit;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  const DeliveryItemModel({
    required this.id,
    required this.deliveryId,
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory DeliveryItemModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;
    final unitModel = productJson?['unit_model'] as Map<String, dynamic>?;
    final unitName = unitModel?['short_name'] as String? ??
        productJson?['unit'] as String? ??
        'Pcs';

    return DeliveryItemModel(
      id: json['id'] as int? ?? 0,
      deliveryId: json['delivery_id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productName: productJson?['name'] as String? ?? 'Produk Jadi',
      productUnit: unitName,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] != null
          ? double.tryParse(json['unit_price'].toString()) ?? 0.0
          : 0.0,
      subtotal: json['subtotal'] != null
          ? double.tryParse(json['subtotal'].toString()) ?? 0.0
          : 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'notes': notes,
    };
  }
}

class DeliveryInvoiceModel {
  final int id;
  final String invoiceNumber;
  final double totalAmount;
  final String status;

  const DeliveryInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.status,
  });

  factory DeliveryInvoiceModel.fromJson(Map<String, dynamic> json) {
    return DeliveryInvoiceModel(
      id: json['id'] as int? ?? 0,
      invoiceNumber: json['invoice_number'] as String? ?? '-',
      totalAmount: json['total_amount'] != null
          ? double.tryParse(json['total_amount'].toString()) ?? 0.0
          : 0.0,
      status: json['status'] as String? ?? 'belum_dibayar',
    );
  }
}

class DeliveryModel {
  final int id;
  final String deliveryNumber;
  final int storeId;
  final int? courierId;
  final int? createdBy;
  final String? deliveryDate;
  final String? deliveryDateFormatted;
  final String status;
  final String statusLabel;
  final String? notes;
  final String? dispatchedAt;
  final String? dispatchedAtFormatted;
  final String? deliveredAt;
  final String? deliveredAtFormatted;
  final String? recipientName;
  final String? recipientRole;
  final String? recipientPhone;
  final String? proofImage;
  final String? proofImageUrl;
  final String? signatureData;
  final int totalItems;
  final double totalAmount;
  final DeliveryStoreModel? store;
  final DeliveryCourierModel? courier;
  final List<DeliveryItemModel> items;
  final DeliveryInvoiceModel? invoice;
  final bool canEdit;

  const DeliveryModel({
    required this.id,
    required this.deliveryNumber,
    required this.storeId,
    this.courierId,
    this.createdBy,
    this.deliveryDate,
    this.deliveryDateFormatted,
    required this.status,
    required this.statusLabel,
    this.notes,
    this.dispatchedAt,
    this.dispatchedAtFormatted,
    this.deliveredAt,
    this.deliveredAtFormatted,
    this.recipientName,
    this.recipientRole,
    this.recipientPhone,
    this.proofImage,
    this.proofImageUrl,
    this.signatureData,
    this.totalItems = 0,
    this.totalAmount = 0.0,
    this.store,
    this.courier,
    this.items = const [],
    this.invoice,
    this.canEdit = false,
  });

  bool get isDiproses => status == 'diproses';
  bool get isDikirim => status == 'dikirim';
  bool get isSelesai => status == 'selesai';
  bool get isDibatalkan => status == 'dibatalkan';

  static String formatDateTimeString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    final str = dateStr.trim();
    if (!str.contains('-') && !str.contains('T')) {
      return str;
    }
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final day = dt.day;
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year $hour:$minute';
    } catch (_) {
      return str;
    }
  }

  static String formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    final str = dateStr.trim();
    if (!str.contains('-') && !str.contains('T')) {
      return str;
    }
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final day = dt.day;
      final month = months[dt.month - 1];
      final year = dt.year;
      return '$day $month $year';
    } catch (_) {
      return str;
    }
  }

  String get formattedDate =>
      deliveryDateFormatted != null && deliveryDateFormatted!.isNotEmpty
          ? deliveryDateFormatted!
          : formatDateString(deliveryDate);

  String get formattedDispatchedAt =>
      dispatchedAtFormatted != null && dispatchedAtFormatted!.isNotEmpty
          ? dispatchedAtFormatted!
          : formatDateTimeString(dispatchedAt);

  String get formattedDeliveredAt =>
      deliveredAtFormatted != null && deliveredAtFormatted!.isNotEmpty
          ? deliveredAtFormatted!
          : formatDateTimeString(deliveredAt);

  String get itemsSummary {
    if (items.isEmpty) return 'Tidak ada barang';
    return items
        .map((i) => '${i.productName} (${i.quantity} ${i.productUnit})')
        .join(', ');
  }

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'diproses';

    String statusLabel = json['status_label'] as String? ?? '';
    if (statusLabel.isEmpty) {
      switch (status) {
        case 'diproses':
          statusLabel = 'Menunggu Pengambilan';
          break;
        case 'dikirim':
          statusLabel = 'Sedang Dikirim';
          break;
        case 'selesai':
          statusLabel = 'Selesai';
          break;
        case 'dibatalkan':
          statusLabel = 'Dibatalkan';
          break;
        default:
          statusLabel = status;
      }
    }

    final rawItems = json['items'];
    List<DeliveryItemModel> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems
          .map((item) => DeliveryItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return DeliveryModel(
      id: json['id'] as int? ?? 0,
      deliveryNumber: json['delivery_number'] as String? ?? '-',
      storeId: json['store_id'] as int? ?? 0,
      courierId: json['courier_id'] as int?,
      createdBy: json['created_by'] as int?,
      deliveryDate: json['delivery_date']?.toString().split('T').first,
      deliveryDateFormatted: json['delivery_date_formatted']?.toString(),
      status: status,
      statusLabel: statusLabel,
      notes: json['notes'] as String?,
      dispatchedAt: json['dispatched_at']?.toString(),
      dispatchedAtFormatted: json['dispatched_at_formatted']?.toString(),
      deliveredAt: json['delivered_at']?.toString(),
      deliveredAtFormatted: json['delivered_at_formatted']?.toString(),
      recipientName: json['recipient_name'] as String?,
      recipientRole: json['recipient_role'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      proofImage: json['proof_image'] as String?,
      proofImageUrl: json['proof_image_url'] as String?,
      signatureData: json['signature_data'] as String?,
      totalItems: json['total_items'] as int? ?? 0,
      totalAmount: json['total_amount'] != null
          ? double.tryParse(json['total_amount'].toString()) ?? 0.0
          : 0.0,
      store: json['store'] != null
          ? DeliveryStoreModel.fromJson(json['store'] as Map<String, dynamic>)
          : null,
      courier: json['courier'] != null
          ? DeliveryCourierModel.fromJson(json['courier'] as Map<String, dynamic>)
          : null,
      items: itemsList,
      invoice: json['invoice'] != null
          ? DeliveryInvoiceModel.fromJson(json['invoice'] as Map<String, dynamic>)
          : null,
      canEdit: json['can_edit'] as bool? ?? (status == 'diproses'),
    );
  }
}

class ProductOptionModel {
  final int id;
  final String name;
  final String unit;
  final int stockReady;
  final double consignmentPrice;
  final double depositPrice;
  final String? image;

  const ProductOptionModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockReady,
    required this.consignmentPrice,
    required this.depositPrice,
    this.image,
  });

  factory ProductOptionModel.fromJson(Map<String, dynamic> json) {
    final unitModel = json['unit_model'] as Map<String, dynamic>?;
    final unitStr = unitModel?['short_name'] as String? ??
        json['unit'] as String? ??
        'Pcs';

    return ProductOptionModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      unit: unitStr,
      stockReady: json['stock_ready'] as int? ?? 0,
      consignmentPrice: json['consignment_price'] != null
          ? double.tryParse(json['consignment_price'].toString()) ?? 0.0
          : 0.0,
      depositPrice: json['retail_price'] != null
          ? double.tryParse(json['retail_price'].toString()) ?? 0.0
          : (json['deposit_price'] != null
              ? double.tryParse(json['deposit_price'].toString()) ?? 0.0
              : 0.0),
      image: (json['photo'] ?? json['image']) as String?,
    );
  }
}

class DeliveryOptionsModel {
  final List<DeliveryStoreModel> stores;
  final List<ProductOptionModel> products;
  final List<DeliveryCourierModel> couriers;
  final List<String> routes;
  final String nextDeliveryNumber;

  const DeliveryOptionsModel({
    this.stores = const [],
    this.products = const [],
    this.couriers = const [],
    this.routes = const [],
    this.nextDeliveryNumber = '',
  });

  factory DeliveryOptionsModel.fromJson(Map<String, dynamic> json) {
    final rawStores = json['stores'] as List? ?? [];
    final rawProducts = json['products'] as List? ?? [];
    final rawCouriers = json['couriers'] as List? ?? [];
    final rawRoutes = json['routes'] as List? ?? [];

    return DeliveryOptionsModel(
      stores: rawStores
          .map((s) => DeliveryStoreModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      products: rawProducts
          .map((p) => ProductOptionModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      couriers: rawCouriers
          .map((c) => DeliveryCourierModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      routes: rawRoutes.map((r) => r.toString()).toList(),
      nextDeliveryNumber: json['next_delivery_number'] as String? ?? '',
    );
  }
}

class DeliveryListResult {
  final List<DeliveryModel> deliveries;
  final int total;
  final int currentPage;
  final int lastPage;
  final Map<String, int> statusCounts;
  final List<String> routes;
  final bool isCourier;
  final int? currentUserId;

  const DeliveryListResult({
    required this.deliveries,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.statusCounts,
    this.routes = const [],
    this.isCourier = false,
    this.currentUserId,
  });

  bool get hasMore => currentPage < lastPage;
}
