import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import '../main_citizen_shell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to sign out of your session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final myGrievancesAsync = ref.watch(myGrievancesProvider);
    final user = authState.currentUser;

    int totalCount = 0;
    int pendingCount = 0;
    int resolvedCount = 0;

    myGrievancesAsync.whenData((list) {
      totalCount = list.length;
      pendingCount = list.where((g) => g.status.toLowerCase() != 'resolved').length;
      resolvedCount = list.where((g) => g.status.toLowerCase() == 'resolved').length;
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        actions: [
          if (user?.role == 'admin')
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: Colors.amber),
              tooltip: 'Admin Portal',
              onPressed: () => context.go('/admin-dashboard'),
            )
          else if (user?.role == 'official')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.secondaryTeal),
              tooltip: 'Official Workspace',
              onPressed: () => context.go('/official-dashboard'),
            ),

          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () {
                MainCitizenShellController.of(context)?.onSelectTab(3);
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.secondaryTeal,
                child: Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Banner Card
            _buildGreetingCard(user?.fullName ?? 'Citizen'),
            const SizedBox(height: 20),

            // Statistics Grid (Live count)
            const Text(
              'Grievance Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildStatisticsGrid(
              total: totalCount,
              pending: pendingCount,
              resolved: resolvedCount,
            ),

            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildQuickActionsGrid(context),

            const SizedBox(height: 24),

            // Recent Activity Section
            _buildRecentActivityCard(myGrievancesAsync),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F4C81),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Phase 1 Live • Official App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _getFormattedDate(),
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_getGreeting()}, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'File, track, and manage public grievances seamlessly with local database persistence.',
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid({
    required int total,
    required int pending,
    required int resolved,
  }) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Total',
            count: total.toString().padLeft(2, '0'),
            icon: Icons.folder_open_rounded,
            iconColor: AppTheme.primaryBlue,
            iconBgColor: const Color(0xFFE0F2FE),
            subtitle: 'Grievances',
            onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            title: 'Pending',
            count: pending.toString().padLeft(2, '0'),
            icon: Icons.hourglass_top_rounded,
            iconColor: AppTheme.warning,
            iconBgColor: const Color(0xFFFEF3C7),
            subtitle: 'In Progress',
            onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            title: 'Resolved',
            count: resolved.toString().padLeft(2, '0'),
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppTheme.success,
            iconBgColor: const Color(0xD1D1FADF),
            subtitle: 'Completed',
            onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                title: 'New Grievance',
                subtitle: 'File a complaint',
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.primaryBlue,
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => context.push('/complaints/new'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                title: 'My Complaints',
                subtitle: 'View all submitted',
                icon: Icons.assignment_outlined,
                color: AppTheme.secondaryTeal,
                bgColor: const Color(0xFFCCFBF1),
                onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Track Status',
                subtitle: 'Timeline & stages',
                icon: Icons.my_location_rounded,
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
                onTap: () => MainCitizenShellController.of(context)?.onSelectTab(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Citizen Profile',
                subtitle: 'User & settings',
                icon: Icons.person_outline_rounded,
                color: AppTheme.warning,
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => MainCitizenShellController.of(context)?.onSelectTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(AsyncValue<List<GrievanceModel>> grievancesAsync) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Complaints',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () {
                    MainCitizenShellController.of(context)?.onSelectTab(1);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            grievancesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Error: ${err.toString()}', style: const TextStyle(color: AppTheme.danger)),
              ),
              data: (list) {
                final recent = list.take(3).toList();
                if (recent.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No grievances submitted yet. Tap "File Grievance" to start!',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppTheme.borderLight, height: 16),
                  itemBuilder: (context, index) {
                    final item = recent[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.grievanceNumber} • ${item.getDisplayTitle()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${item.departmentId ?? "Auto AI Routing"} • ${item.status.replaceAll("_", " ").toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      onTap: () {
                        context.push('/tracking');
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
