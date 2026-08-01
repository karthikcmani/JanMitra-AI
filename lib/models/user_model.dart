class UserModel {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final DateTime createdAt;

  const UserModel({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      password: json['password'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
