class StoreModel {
  final int id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? route;
  final bool isActive;
  final String? notes;
  final String? photo;
  final String? photoUrl;
  final String? createdAt;

  const StoreModel({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.route,
    this.isActive = true,
    this.notes,
    this.photo,
    this.photoUrl,
    this.createdAt,
  });

  /// Mengembalikan nomor telepon dengan prefix '+' jika belum ada
  String? get formattedPhone {
    if (phone == null || phone!.trim().isEmpty) return null;
    final trimmed = phone!.trim();
    return trimmed.startsWith('+') ? trimmed : '+$trimmed';
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      ownerName: json['owner_name']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      route: json['route']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      notes: json['notes']?.toString(),
      photo: json['photo']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_name': ownerName,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'route': route,
      'is_active': isActive,
      'notes': notes,
      'photo': photo,
      'photo_url': photoUrl,
      'created_at': createdAt,
    };
  }
}

class StorePaginationModel {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMore;

  const StorePaginationModel({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });

  factory StorePaginationModel.fromJson(Map<String, dynamic> json) {
    return StorePaginationModel(
      currentPage: json['current_page'] is int
          ? json['current_page']
          : int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      lastPage: json['last_page'] is int
          ? json['last_page']
          : int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int
          ? json['per_page']
          : int.tryParse(json['per_page']?.toString() ?? '15') ?? 15,
      total: json['total'] is int
          ? json['total']
          : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      hasMore: json['has_more'] == true || json['has_more'] == 1,
    );
  }
}

class StoreListResult {
  final List<StoreModel> stores;
  final StorePaginationModel pagination;

  const StoreListResult({
    required this.stores,
    required this.pagination,
  });
}
