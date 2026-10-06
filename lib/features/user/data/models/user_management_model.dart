/// Model data pengguna untuk fitur Manajemen Pengguna (Staf & Hak Akses)
class UserManagementModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? formattedPhone;
  final String? whatsappUrl;
  final String initials;
  final List<String> roles;
  final String primaryRole;
  final String primaryRoleLabel;
  final String? createdAt;
  final String? createdAtHuman;
  final bool isCurrentUser;

  const UserManagementModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.formattedPhone,
    this.whatsappUrl,
    required this.initials,
    required this.roles,
    required this.primaryRole,
    required this.primaryRoleLabel,
    this.createdAt,
    this.createdAtHuman,
    this.isCurrentUser = false,
  });

  factory UserManagementModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    List<String> parsedRoles = [];
    if (rawRoles is List) {
      parsedRoles = rawRoles.map((r) => r.toString()).toList();
    }

    final rawInitials = json['initials']?.toString().trim() ?? '';
    final nameStr = json['name']?.toString().trim() ?? '';

    String safeInitials = '';
    final cleanName = nameStr.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    final nameParts = cleanName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (nameParts.length >= 2) {
      safeInitials = '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      safeInitials = nameParts[0][0].toUpperCase();
    } else if (rawInitials.isNotEmpty) {
      safeInitials = rawInitials.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    }

    return UserManagementModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: nameStr,
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      formattedPhone: json['formatted_phone']?.toString(),
      whatsappUrl: json['whatsapp_url']?.toString(),
      initials: safeInitials.isEmpty ? 'U' : (safeInitials.length > 2 ? safeInitials.substring(0, 2) : safeInitials),
      roles: parsedRoles,
      primaryRole: json['primary_role']?.toString() ?? (parsedRoles.isNotEmpty ? parsedRoles.first : 'Staff'),
      primaryRoleLabel: json['primary_role_label']?.toString() ??
          _formatRoleLabel(json['primary_role']?.toString() ?? (parsedRoles.isNotEmpty ? parsedRoles.first : 'Staff')),
      createdAt: json['created_at']?.toString(),
      createdAtHuman: json['created_at_human']?.toString(),
      isCurrentUser: json['is_current_user'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'formatted_phone': formattedPhone,
      'whatsapp_url': whatsappUrl,
      'initials': initials,
      'roles': roles,
      'primary_role': primaryRole,
      'primary_role_label': primaryRoleLabel,
      'created_at': createdAt,
      'created_at_human': createdAtHuman,
      'is_current_user': isCurrentUser,
    };
  }

  static String _formatRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'dev':
        return 'Developer / Super Admin';
      case 'manager':
        return 'Manager Operasional';
      case 'kurir':
        return 'Kurir Pengantaran';
      default:
        return role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : 'Staff';
    }
  }

  UserManagementModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? formattedPhone,
    String? whatsappUrl,
    String? initials,
    List<String>? roles,
    String? primaryRole,
    String? primaryRoleLabel,
    String? createdAt,
    String? createdAtHuman,
    bool? isCurrentUser,
  }) {
    return UserManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      formattedPhone: formattedPhone ?? this.formattedPhone,
      whatsappUrl: whatsappUrl ?? this.whatsappUrl,
      initials: initials ?? this.initials,
      roles: roles ?? this.roles,
      primaryRole: primaryRole ?? this.primaryRole,
      primaryRoleLabel: primaryRoleLabel ?? this.primaryRoleLabel,
      createdAt: createdAt ?? this.createdAt,
      createdAtHuman: createdAtHuman ?? this.createdAtHuman,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

/// Model Peran (Role) untuk dropdown filter dan form
class RoleModel {
  final int id;
  final String name;
  final String displayName;

  const RoleModel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
    };
  }
}

/// Pembungkus data list pengguna beserta paginasi
class UserListResult {
  final List<UserManagementModel> users;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMore;

  const UserListResult({
    required this.users,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.hasMore,
  });
}
