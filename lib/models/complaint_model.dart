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
      'userEmail': userEmail,
      'title': title,
      'category': category,
      'department': department,
      'district': district,
      'description': description,
      'priority': priority,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String,
      userEmail: json['userEmail'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      department: json['department'] as String,
      district: json['district'] as String,
      description: json['description'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
