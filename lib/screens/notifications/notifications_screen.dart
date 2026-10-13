import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/grievance_provider.dart';
import '../../repositories/notification_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatter.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'all'; // 'all', 'alerts', 'tracking', 'unread'

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'clarification_required':
        return Colors.purple;
      case 'forwarded':
        return const Color(0xFF0284C7);
      case 'status_update':
        return const Color(0xFF7C3AED);
      case 'resolution':
        return AppTheme.success;
      case 'alert':
        return AppTheme.danger;
      case 'assignment':
        return const Color(0xFF0D9488);
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'clarification_required':
        return Icons.help_outline_rounded;
      case 'forwarded':
        return Icons.forward_to_inbox_rounded;
      case 'status_update':
        return Icons.update_rounded;
      case 'resolution':
        return Icons.check_circle_outline_rounded;
      case 'alert':
        return Icons.error_outline_rounded;
      case 'assignment':
        return Icons.account_balance_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _getTypeBadgeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'clarification_required':
        return 'ACTION REQUIRED';
      case 'forwarded':
        return 'FORWARDED';
      case 'status_update':
        return 'STATUS UPDATE';
      case 'resolution':
        return 'RESOLVED';
      case 'assignment':
        return 'ASSIGNED';
      default:
        return 'NOTIFICATION';
    }
  }

  @override
  Widget build(BuildContext context) {
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

          final filteredNotifications = notifications.where((n) {
            final t = n.notificationType.toLowerCase();
            if (_selectedFilter == 'alerts') {
              return t == 'clarification_required' || t == 'alert';
            }
            if (_selectedFilter == 'tracking') {
              return t == 'status_update' || t == 'forwarded' || t == 'resolution' || t == 'assignment';
            }
            if (_selectedFilter == 'unread') {
              return !n.isRead;
            }
            return true;
          }).toList();

          final unreadCount = notifications.where((n) => !n.isRead).length;
          final alertCount = notifications.where((n) {
            final t = n.notificationType.toLowerCase();
            return t == 'clarification_required' || t == 'alert';
          }).length;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${notifications.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('alerts', 'Alerts & Actions ($alertCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('tracking', 'Tracking & Updates'),
                      const SizedBox(width: 8),
                      _buildFilterChip('unread', 'Unread ($unreadCount)'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(userNotificationsProvider),
                  child: filteredNotifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No notifications in this filter.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notif = filteredNotifications[index];
                            final color = _getNotificationColor(notif.notificationType);
                            final icon = _getNotificationIcon(notif.notificationType);
                            final dateStr = formatToIST(notif.createdAt);
                            final isActionRequired = notif.notificationType.toLowerCase() == 'clarification_required';

                            return Card(
                              elevation: notif.isRead ? 0 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: notif.isRead ? Colors.grey.shade300 : color.withValues(alpha: 0.5),
                                  width: notif.isRead ? 1 : 1.5,
                                ),
                              ),
                              color: notif.isRead ? Colors.white : color.withValues(alpha: 0.05),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _handleNotificationTap(notif),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: color.withValues(alpha: 0.15),
                                            child: Icon(icon, color: color, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: color.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        _getTypeBadgeLabel(notif.notificationType),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                          color: color,
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
                                                const SizedBox(height: 4),
                                                Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                                    fontSize: 14.5,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 52),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notif.message,
                                              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      dateStr,
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                                if (notif.grievanceId != null && notif.grievanceId!.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Text(
                                                        isActionRequired ? 'Respond Now' : 'Track Status',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: color,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filterKey;
          });
        }
      },
    );
  }

  Future<void> _handleNotificationTap(dynamic notif) async {
    if (!notif.isRead) {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notif.id);
      ref.invalidate(userNotificationsProvider);
    }
    if (mounted && notif.grievanceId != null && notif.grievanceId.isNotEmpty) {
      ref.read(selectedTrackingGrievanceIdProvider.notifier).state = notif.grievanceId;
      context.push('/tracking');
    }
  }
}
