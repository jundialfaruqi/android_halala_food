import 'package:intl/intl.dart';
import '../../../delivery/data/models/delivery_model.dart';

class InvoiceStoreModel {
  final int id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? address;
  final String? route;

  const InvoiceStoreModel({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.address,
    this.route,
  });

  factory InvoiceStoreModel.fromJson(Map<String, dynamic> json) {
    return InvoiceStoreModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      ownerName: json['owner_name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      route: json['route'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'route': route,
      };
}

class InvoiceItemModel {
  final int id;
  final int invoiceId;
  final int productId;
  final String productName;
  final String productUnit;
  final int quantity;
  final int deliveredQuantity;
  final int remainingQuantity;
  final int damagedQuantity;
  final int returnedQuantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  const InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.quantity,
    this.deliveredQuantity = 0,
    this.remainingQuantity = 0,
    this.damagedQuantity = 0,
    this.returnedQuantity = 0,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    final unitModelMap = productMap?['unit_model'] as Map<String, dynamic>?;

    return InvoiceItemModel(
      id: json['id'] as int? ?? 0,
      invoiceId: json['invoice_id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productName: productMap?['name'] as String? ?? json['product_name'] as String? ?? 'Produk',
      productUnit: unitModelMap?['short_name'] as String? ?? productMap?['unit'] as String? ?? 'pcs',
      quantity: json['quantity'] as int? ?? 0,
      deliveredQuantity: json['delivered_quantity'] as int? ?? 0,
      remainingQuantity: json['remaining_quantity'] as int? ?? 0,
      damagedQuantity: json['damaged_quantity'] as int? ?? 0,
      returnedQuantity: json['returned_quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] != null ? double.tryParse(json['unit_price'].toString()) ?? 0.0 : 0.0,
      subtotal: json['subtotal'] != null ? double.tryParse(json['subtotal'].toString()) ?? 0.0 : 0.0,
      notes: json['notes'] as String?,
    );
  }

  String get formattedUnitPrice {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(unitPrice);
  }

  String get formattedSubtotal {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(subtotal);
  }
}

class InvoicePaymentModel {
  final int id;
  final int invoiceId;
  final double amount;
  final String paymentDate;
  final String? paymentDateFormatted;
  final String paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final String? userName;

  const InvoicePaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.paymentDateFormatted,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.userName,
  });

  String get formattedPaymentDate {
    if (paymentDateFormatted != null &&
        paymentDateFormatted!.isNotEmpty &&
        paymentDateFormatted != '-') {
      return paymentDateFormatted!;
    }
    return InvoiceModel.formatIndonesianDate(paymentDate);
  }

  String get formattedAmount {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String get formattedPaymentMethod {
    switch (paymentMethod.toLowerCase()) {
      case 'tunai':
        return 'Tunai (Cash)';
      case 'transfer_bank':
      case 'transfer':
        return 'Transfer Bank';
      case 'qris':
        return 'QRIS';
      case 'giro':
        return 'Giro';
      default:
        return paymentMethod.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory InvoicePaymentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;

    return InvoicePaymentModel(
      id: json['id'] as int? ?? 0,
      invoiceId: json['invoice_id'] as int? ?? 0,
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
      paymentDate: json['payment_date'] as String? ?? '-',
      paymentDateFormatted: json['payment_date_formatted'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'tunai',
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
      userName: userMap?['name'] as String?,
    );
  }
}

class InvoiceModel {
  final int id;
  final String invoiceNumber;
  final int? deliveryId;
  final String? deliveryNumber;
  final int? storeId;
  final int? createdBy;
  final String? invoiceDate;
  final String? dueDate;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final double remainingBalance;
  final String status;
  final String statusLabel;
  final bool isOverdue;
  final String? notes;
  final InvoiceStoreModel? store;
  final List<InvoiceItemModel> items;
  final List<InvoicePaymentModel> payments;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.deliveryId,
    this.deliveryNumber,
    this.storeId,
    this.createdBy,
    this.invoiceDate,
    this.dueDate,
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.remainingBalance = 0.0,
    required this.status,
    required this.statusLabel,
    this.isOverdue = false,
    this.notes,
    this.store,
    this.items = const [],
    this.payments = const [],
  });

  bool get isBelumDibayar => status == 'belum_dibayar';
  bool get isSebagian => status == 'sebagian';
  bool get isLunas => status == 'lunas';
  bool get isDibatalkan => status == 'dibatalkan';

  bool get isReconciled => items.any((it) =>
      it.remainingQuantity > 0 ||
      it.damagedQuantity > 0 ||
      it.returnedQuantity > 0 ||
      (it.deliveredQuantity > 0 && it.deliveredQuantity != it.quantity));

  static String formatIndonesianDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == '-') return '-';
    try {
      final normalized = dateStr.contains('T')
          ? dateStr
          : dateStr.replaceFirst(' ', 'T');
      final parsed = DateTime.parse(normalized);
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
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String get formattedInvoiceDate => formatIndonesianDate(invoiceDate);
  String get formattedDueDate => formatIndonesianDate(dueDate);

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == '-') return null;
    final trimmed = dateStr.trim();
    try {
      final normalized = trimmed.contains('T')
          ? trimmed
          : trimmed.replaceFirst(' ', 'T');
      return DateTime.parse(normalized);
    } catch (_) {
      try {
        final dateOnly = trimmed.split('T')[0].split(' ')[0];
        return DateTime.parse(dateOnly);
      } catch (_) {
        return null;
      }
    }
  }

  DateTime? get parsedInvoiceDate => parseDate(invoiceDate);
  DateTime? get parsedDueDate => parseDate(dueDate);

  String get simpleInvoiceDate {
    final dt = parsedInvoiceDate;
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get simpleDueDate {
    final dt = parsedDueDate;
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get formattedTotalAmount {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(totalAmount);
  }

  String get formattedRemainingBalance {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(remainingBalance);
  }

  String get formattedPaidAmount {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(paidAmount);
  }

  String get formattedDiscount {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(discount);
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    List<InvoiceItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => InvoiceItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    List<InvoicePaymentModel> parsedPayments = [];
    if (json['payments'] is List) {
      parsedPayments = (json['payments'] as List)
          .map((p) => InvoicePaymentModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    final rawStatus = json['status'] as String? ?? 'belum_dibayar';
    final rawStatusLabel = json['status_label'] as String? ??
        (rawStatus == 'belum_dibayar'
            ? 'Belum Dibayar'
            : (rawStatus == 'sebagian'
                ? 'Dibayar Sebagian'
                : (rawStatus == 'lunas'
                    ? 'Lunas'
                    : (rawStatus == 'dibatalkan' ? 'Dibatalkan' : rawStatus))));

    final deliveryMap = json['delivery'] as Map<String, dynamic>?;
    final deliveryNum = json['delivery_number'] as String? ??
        deliveryMap?['delivery_number'] as String?;

    return InvoiceModel(
      id: json['id'] as int? ?? 0,
      invoiceNumber: json['invoice_number'] as String? ?? '-',
      deliveryId: json['delivery_id'] as int?,
      deliveryNumber: deliveryNum,
      storeId: json['store_id'] as int?,
      createdBy: json['created_by'] as int?,
      invoiceDate: json['invoice_date'] as String?,
      dueDate: json['due_date'] as String?,
      subtotal: json['subtotal'] != null ? double.tryParse(json['subtotal'].toString()) ?? 0.0 : 0.0,
      discount: json['discount'] != null ? double.tryParse(json['discount'].toString()) ?? 0.0 : 0.0,
      totalAmount: json['total_amount'] != null ? double.tryParse(json['total_amount'].toString()) ?? 0.0 : 0.0,
      paidAmount: json['paid_amount'] != null ? double.tryParse(json['paid_amount'].toString()) ?? 0.0 : 0.0,
      remainingBalance: json['remaining_balance'] != null ? double.tryParse(json['remaining_balance'].toString()) ?? 0.0 : 0.0,
      status: rawStatus,
      statusLabel: rawStatusLabel,
      isOverdue: json['is_overdue'] as bool? ?? false,
      notes: json['notes'] as String?,
      store: json['store'] != null ? InvoiceStoreModel.fromJson(json['store'] as Map<String, dynamic>) : null,
      items: parsedItems,
      payments: parsedPayments,
    );
  }
}

class InvoiceListResult {
  final List<InvoiceModel> invoices;
  final bool hasMore;
  final int total;
  final int currentPage;
  final int lastPage;
  final Map<String, int> statusCounts;
  final List<InvoiceStoreModel> stores;

  const InvoiceListResult({
    required this.invoices,
    required this.hasMore,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.statusCounts,
    required this.stores,
  });
}

typedef InvoiceProductOptionModel = ProductOptionModel;

class InvoiceDeliveryItemOptionModel {
  final int productId;
  final String productName;
  final String productUnit;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const InvoiceDeliveryItemOptionModel({
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory InvoiceDeliveryItemOptionModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    final unitModelMap = productMap?['unit_model'] as Map<String, dynamic>?;
    final unitName = unitModelMap?['short_name'] as String? ??
        productMap?['unit'] as String? ??
        'pcs';

    return InvoiceDeliveryItemOptionModel(
      productId: json['product_id'] as int? ?? 0,
      productName: productMap?['name'] as String? ?? 'Produk',
      productUnit: unitName,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] != null
          ? double.tryParse(json['unit_price'].toString()) ?? 0.0
          : 0.0,
      subtotal: json['subtotal'] != null
          ? double.tryParse(json['subtotal'].toString()) ?? 0.0
          : 0.0,
    );
  }
}

class InvoiceDeliveryOptionModel {
  final int id;
  final String deliveryNumber;
  final int storeId;
  final String? deliveryDate;
  final String? deliveryDateFormatted;
  final List<InvoiceDeliveryItemOptionModel> items;

  const InvoiceDeliveryOptionModel({
    required this.id,
    required this.deliveryNumber,
    required this.storeId,
    this.deliveryDate,
    this.deliveryDateFormatted,
    this.items = const [],
  });

  factory InvoiceDeliveryOptionModel.fromJson(Map<String, dynamic> json) {
    List<InvoiceDeliveryItemOptionModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) =>
              InvoiceDeliveryItemOptionModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return InvoiceDeliveryOptionModel(
      id: json['id'] as int? ?? 0,
      deliveryNumber: json['delivery_number'] as String? ?? '-',
      storeId: json['store_id'] as int? ?? 0,
      deliveryDate: json['delivery_date'] as String?,
      deliveryDateFormatted: json['delivery_date_formatted'] as String?,
      items: parsedItems,
    );
  }

  String get formattedDeliveryDate {
    if (deliveryDateFormatted != null &&
        deliveryDateFormatted!.trim().isNotEmpty) {
      return deliveryDateFormatted!;
    }
    if (deliveryDate == null || deliveryDate!.trim().isEmpty) {
      return '';
    }

    final str = deliveryDate!.trim();
    try {
      final normalized =
          str.contains('T') ? str : str.replaceFirst(' ', 'T');
      final dt = DateTime.parse(normalized).toLocal();
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

      final hasTime = str.contains(':') && (dt.hour != 0 || dt.minute != 0);
      if (hasTime) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$day $month $year, $hour:$minute';
      }
      return '$day $month $year';
    } catch (_) {
      return str;
    }
  }
}

class InvoiceCreateOptionsModel {
  final List<InvoiceStoreModel> stores;
  final List<InvoiceProductOptionModel> products;
  final List<InvoiceDeliveryOptionModel> deliveries;
  final String nextInvoiceNumber;
  final String defaultInvoiceDate;
  final String defaultDueDate;

  const InvoiceCreateOptionsModel({
    this.stores = const [],
    this.products = const [],
    this.deliveries = const [],
    this.nextInvoiceNumber = '',
    this.defaultInvoiceDate = '',
    this.defaultDueDate = '',
  });

  factory InvoiceCreateOptionsModel.fromJson(Map<String, dynamic> json) {
    final rawStores = json['stores'] as List? ?? [];
    final rawProducts = json['products'] as List? ?? [];
    final rawDeliveries = json['deliveries'] as List? ?? [];

    return InvoiceCreateOptionsModel(
      stores: rawStores
          .map((s) => InvoiceStoreModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      products: rawProducts
          .map((p) =>
              ProductOptionModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      deliveries: rawDeliveries
          .map((d) =>
              InvoiceDeliveryOptionModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      nextInvoiceNumber: json['next_invoice_number'] as String? ?? '',
      defaultInvoiceDate: json['default_invoice_date'] as String? ?? '',
      defaultDueDate: json['default_due_date'] as String? ?? '',
    );
  }
}
