class ComplaintModel {
  final String id;
  final String userEmail;
  final String title;
  final String category;
  final String department;
  final String district;
  final String description;
  final String priority; // Low, Medium, High, Urgent
  final String status; // Submitted, Verification, Forwarded, Resolved
  final DateTime createdAt;
  final DateTime updatedAt;

  const ComplaintModel({
    required this.id,
    required this.userEmail,
    required this.title,
    required this.category,
    required this.department,
    required this.district,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  ComplaintModel copyWith({
    String? id,
    String? userEmail,
    String? title,
    String? category,
    String? department,
    String? district,
    String? description,
    String? priority,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      title: title ?? this.title,
      category: category ?? this.category,
      department: department ?? this.department,
      district: district ?? this.district,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_email': userEmail,
      'title': title,
      'category': category,
      'department': department,
      'district': district,
      'description': description,
      'priority': priority,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: (json['id'] ?? '').toString(),
      userEmail: (json['user_email'] ?? json['userEmail'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.tryParse((json['created_at'] ?? json['createdAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null || json['updatedAt'] != null
          ? DateTime.tryParse((json['updated_at'] ?? json['updatedAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
