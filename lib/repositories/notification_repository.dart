import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class NotificationRepository {
  final ApiService apiService;

  NotificationRepository(this.apiService);

  /// Retrieves in-app notifications for authenticated user
  Future<List<UserNotificationModel>> getMyNotifications({bool unreadOnly = false}) async {
    final response = await apiService.get(
      '/notifications/my',
      queryParameters: {'unread_only': unreadOnly},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((json) => UserNotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Marks a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    await apiService.post('/notifications/$notificationId/read');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return NotificationRepository(apiService);
});

final userNotificationsProvider = FutureProvider.autoDispose<List<UserNotificationModel>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getMyNotifications();
});
