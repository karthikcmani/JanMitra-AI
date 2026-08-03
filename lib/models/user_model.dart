class UserModel {
  final String? id;
  final String fullName;
  final String email;
  final String phone;
  final String? role;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.role = 'citizen',
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'citizen') as String,
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString())
                : null),
    );
  }
}
