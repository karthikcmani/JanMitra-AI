import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/notification_repository.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'clarification_required':
        return Colors.purple;
      case 'status_update':
      case 'resolution':
        return AppTheme.success;
      case 'alert':
        return AppTheme.warning;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'clarification_required':
        return Icons.help_outline_rounded;
      case 'status_update':
        return Icons.update_rounded;
      case 'resolution':
        return Icons.check_circle_outline_rounded;
      case 'alert':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(userNotificationsProvider),
            tooltip: 'Refresh Notifications',
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                const SizedBox(height: 12),
                Text('Error loading notifications: ${err.toString()}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userNotificationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Department updates, official clarification requests, and resolution alerts will appear here when issued.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userNotificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final color = _getNotificationColor(notif.notificationType);
                final icon = _getNotificationIcon(notif.notificationType);
                final dateStr = notif.createdAt.toString().split('.').first;

                return Card(
                  elevation: notif.isRead ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: notif.isRead ? Colors.grey.shade300 : color.withValues(alpha: 0.4),
                      width: notif.isRead ? 1 : 1.5,
                    ),
                  ),
                  color: notif.isRead ? Colors.white : color.withValues(alpha: 0.05),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif.message,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (!notif.isRead) {
                        final repo = ref.read(notificationRepositoryProvider);
                        await repo.markAsRead(notif.id);
                        ref.invalidate(userNotificationsProvider);
                      }
                      if (context.mounted && notif.grievanceId != null && notif.grievanceId!.isNotEmpty) {
                        context.push('/tracking');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
