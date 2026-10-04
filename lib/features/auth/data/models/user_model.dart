class UserModel {
  final int id;
  final String name;
  final String email;
  final String? role;
  final String? avatar;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ??
          (json['roles'] is List && (json['roles'] as List).isNotEmpty
              ? json['roles'][0]['name']?.toString()
              : null),
      avatar: json['avatar']?.toString() ?? json['profile_photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatar': avatar,
    };
  }
}
