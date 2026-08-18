import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../main_citizen_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final grievancesAsync = ref.watch(myGrievancesProvider);
    final isDarkMode = ref.watch(themeProvider);
    final user = authState.currentUser;

    int totalCount = 0;
    int pendingCount = 0;
    int resolvedCount = 0;

    grievancesAsync.whenData((list) {
      totalCount = list.length;
      resolvedCount = list.where((g) => g.status.toLowerCase() == 'resolved' || g.status.toLowerCase() == 'closed').length;
      pendingCount = list.length - resolvedCount;
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Citizen Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.primaryBlue,
              child: Text(
                user?.fullName.isNotEmpty == true
                    ? user!.fullName[0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user?.fullName ?? 'Citizen User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${user?.email ?? "citizen@gov.in"} • ${user?.phone ?? "+91 9876543210"}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // Statistics Summary Card (Live count & Clickable)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        'Total Grievances',
                        totalCount.toString(),
                        onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppTheme.borderLight),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        'Pending',
                        pendingCount.toString(),
                        onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppTheme.borderLight),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        'Resolved',
                        resolvedCount.toString(),
                        onTap: () => MainCitizenShellController.of(context)?.onSelectTab(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account & Settings Options
            Material(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.dark_mode_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text('Dark Theme'),
                      subtitle: Text(
                        isDarkMode ? 'Dark Mode Enabled' : 'Light Mode Enabled',
                      ),
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: (val) {
                          ref.read(themeProvider.notifier).toggleTheme();
                        },
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    ListTile(
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text('FastAPI Backend Service'),
                      subtitle: const Text('JWT Secure Token Session Active'),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 20,
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    ListTile(
                      leading: const Icon(
                        Icons.security_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text('Security & Privacy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
