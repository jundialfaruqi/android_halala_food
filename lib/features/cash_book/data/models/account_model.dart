double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class AccountModel {
  final int id;
  final String name;
  final String type;
  final double balance;
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  bool get isBusiness => type == 'business';
  String get typeLabel => type == 'business' ? 'Kas Usaha' : 'Kas Pribadi';

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '-',
      type: json['type']?.toString() ?? 'business',
      balance: _parseDouble(json['balance']),
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
