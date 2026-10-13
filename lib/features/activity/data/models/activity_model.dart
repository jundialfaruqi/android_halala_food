import 'package:intl/intl.dart';

class ActivityModel {
  final int id;
  final String type; // delivery_created, delivery_dispatched, delivery_completed, invoice_created, invoice_paid
  final String title;
  final String? description;
  final int userId;
  final String userName;
  final String userRole;
  final String userInitials;
  final String? userAvatar;
  final int? courierId;
  final String? courierName;
  final String? subjectType;
  final int? subjectId;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final String timeFormatted;
  final String dateFormatted;
  final String dateGroupKey;
  final bool isDeleted;
  final String? deletionMessage;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.userInitials,
    this.userAvatar,
    this.courierId,
    this.courierName,
    this.subjectType,
    this.subjectId,
    this.data = const {},
    this.createdAt,
    required this.timeFormatted,
    required this.dateFormatted,
    required this.dateGroupKey,
    this.isDeleted = false,
    this.deletionMessage,
  });

  bool get isDelivery => type.startsWith('delivery');
  bool get isInvoice => type.startsWith('invoice');
  bool get isDeliveryCreated => type == 'delivery_created';
  bool get isDeliveryDispatched => type == 'delivery_dispatched';
  bool get isDeliveryCompleted => type == 'delivery_completed';
  bool get isInvoiceCreated => type == 'invoice_created';
  bool get isInvoicePaid => type == 'invoice_paid';

  String? get documentNumber =>
      data['delivery_number']?.toString() ?? data['invoice_number']?.toString();

  String? get storeName => data['store_name']?.toString();

  double? get totalAmount => (data['total_amount'] as num?)?.toDouble();

  double? get paymentAmount => (data['payment_amount'] as num?)?.toDouble();

  int? get totalItems => (data['total_items'] as num?)?.toInt();

  String? get recipientName => data['recipient_name']?.toString();

  String? get paymentMethod => data['payment_method']?.toString();

  int? get targetDeliveryId =>
      (data['delivery_id'] as num?)?.toInt() ??
      (subjectType?.contains('Delivery') == true ? subjectId : null);

  int? get targetInvoiceId =>
      (data['invoice_id'] as num?)?.toInt() ??
      (subjectType?.contains('Invoice') == true ? subjectId : null);

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt != null) {
      dt = DateTime.tryParse(rawCreatedAt.toString())?.toLocal();
    }

    String timeStr = json['time_formatted']?.toString() ?? '';
    if (timeStr.isEmpty && dt != null) {
      timeStr = DateFormat('HH:mm').format(dt);
    }

    String dateStr = json['date_formatted']?.toString() ?? '';
    if (dateStr.isEmpty && dt != null) {
      try {
        dateStr = DateFormat('d MMM yyyy', 'id_ID').format(dt);
      } catch (_) {
        dateStr = DateFormat('dd/MM/yyyy').format(dt);
      }
    }

    String dateGroup = dt != null
        ? DateFormat('yyyy-MM-dd').format(dt)
        : (json['date_group_key']?.toString() ?? '');

    // Hitung inisial jika belum ada
    String initials = json['user_initials']?.toString() ?? '';
    if (initials.isEmpty) {
      final name = (json['user_name'] ?? 'User').toString().trim();
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (name.isNotEmpty) {
        initials = name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
      } else {
        initials = 'US';
      }
    }

    return ActivityModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      type: json['type']?.toString() ?? json['action_type']?.toString() ?? 'delivery_created',
      title: json['title']?.toString() ?? 'Aktifitas',
      description: json['description']?.toString(),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString() ?? 'User',
      userRole: json['user_role']?.toString() ?? 'Staf',
      userInitials: initials,
      userAvatar: json['user_avatar']?.toString(),
      courierId: json['courier_id'] is int ? json['courier_id'] : int.tryParse(json['courier_id']?.toString() ?? ''),
      courierName: json['courier_name']?.toString(),
      subjectType: json['subject_type']?.toString(),
      subjectId: json['subject_id'] is int ? json['subject_id'] : int.tryParse(json['subject_id']?.toString() ?? ''),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : {}),
      createdAt: dt,
      timeFormatted: timeStr,
      dateFormatted: dateStr,
      dateGroupKey: dateGroup,
      isDeleted: json['is_deleted'] == true ||
          json['is_deleted'] == 1 ||
          (json['data'] is Map &&
              ((json['data'] as Map)['is_deleted'] == true ||
                  (json['data'] as Map)['is_deleted'] == 1)) ||
          (json['description'] != null &&
              json['description'].toString().contains('telah dihapus oleh')),
      deletionMessage: json['deletion_message']?.toString() ??
          (json['data'] is Map
              ? (json['data'] as Map)['deletion_message']?.toString()
              : null),
    );
  }
}

class ActivityListResult {
  final List<ActivityModel> activities;
  final int total;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
  final bool canViewAll;

  const ActivityListResult({
    required this.activities,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
    this.canViewAll = false,
  });
}
