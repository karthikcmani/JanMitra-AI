class UserNotificationModel {
  final String id;
  final String title;
  final String message;
  final String? grievanceId;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  const UserNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.grievanceId,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotificationModel.fromJson(Map<String, dynamic> json) {
    return UserNotificationModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      grievanceId: json['grievance_id']?.toString(),
      notificationType: (json['notification_type'] ?? 'info').toString(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
