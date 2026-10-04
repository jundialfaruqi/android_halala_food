class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final List<String> roles;
  final List<String> permissions;
  final String? avatar;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.roles = const [],
    this.permissions = const [],
    this.avatar,
  });

  String get role => roles.isNotEmpty ? roles.first : 'User';

  bool hasPermission(String permission) {
    // Role 'dev' memiliki akses super admin ke semua fitur
    if (roles.contains('dev')) return true;
    return permissions.contains(permission);
  }

  bool hasAnyPermission(List<String> requiredPermissions) {
    if (roles.contains('dev')) return true;
    return requiredPermissions.any((p) => permissions.contains(p));
  }

  bool hasRole(String roleName) {
    return roles.contains(roleName);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> extractedRoles = [];
    if (json['roles'] is List) {
      extractedRoles = (json['roles'] as List).map((e) {
        if (e is String) return e;
        if (e is Map && e.containsKey('name')) return e['name'].toString();
        return e.toString();
      }).toList();
    } else if (json['role'] != null) {
      extractedRoles = [json['role'].toString()];
    }

    List<String> extractedPermissions = [];
    if (json['permissions'] is List) {
      extractedPermissions = (json['permissions'] as List).map((e) {
        if (e is String) return e;
        if (e is Map && e.containsKey('name')) return e['name'].toString();
        return e.toString();
      }).toList();
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      roles: extractedRoles,
      permissions: extractedPermissions,
      avatar: json['avatar']?.toString() ?? json['profile_photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles,
      'permissions': permissions,
      'avatar': avatar,
    };
  }
}
