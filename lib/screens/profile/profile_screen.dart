import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final complaintState = ref.watch(complaintProvider);
    final isDarkMode = ref.watch(themeProvider);
    final user = authState.currentUser;

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

            // Statistics Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Total Grievances',
                    complaintState.totalCount.toString(),
                  ),
                  Container(height: 36, width: 1, color: AppTheme.borderLight),
                  _buildStatColumn(
                    'Pending',
                    complaintState.pendingCount.toString(),
                  ),
                  Container(height: 36, width: 1, color: AppTheme.borderLight),
                  _buildStatColumn(
                    'Resolved',
                    complaintState.resolvedCount.toString(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account & Settings Options
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
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
                    title: const Text('Local Hive Database'),
                    subtitle: const Text('100% Offline Persistence Active'),
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
