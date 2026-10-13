import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../main_citizen_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openEditProfileDialog(BuildContext context) {
    final user = ref.read(authProvider).currentUser;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 26),
                            SizedBox(width: 8),
                            Text(
                              'Edit Citizen Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) {
                          return 'Please enter a valid full name (min 2 characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && val.trim().length < 7) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Read-only email notice
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Email (${user?.email ?? ""}) is verified and locked.',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                final messenger = ScaffoldMessenger.of(this.context);
                                final navigator = Navigator.of(bottomSheetContext);
                                setModalState(() => isSaving = true);
                                final success = await ref
                                    .read(authProvider.notifier)
                                    .updateProfile(
                                      fullName: nameController.text.trim(),
                                      phone: phoneController.text.trim(),
                                    );
                                setModalState(() => isSaving = false);
                                if (success && mounted) {
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        isSaving ? 'Saving...' : 'Save Profile Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _openEditProfileDialog(context),
          ),
        ],
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
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openEditProfileDialog(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryBlue),
              label: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Summary Card (Live count & Filter Clickable)
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
                        'Total',
                        totalCount.toString(),
                        onTap: () {
                          ref.read(complaintFilterProvider.notifier).state = 'All';
                          MainCitizenShellController.of(context)?.onSelectTab(1);
                        },
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppTheme.borderLight),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        'Pending',
                        pendingCount.toString(),
                        onTap: () {
                          ref.read(complaintFilterProvider.notifier).state = 'Pending';
                          MainCitizenShellController.of(context)?.onSelectTab(1);
                        },
                      ),
                    ),
                    Container(height: 36, width: 1, color: AppTheme.borderLight),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        'Resolved',
                        resolvedCount.toString(),
                        onTap: () {
                          ref.read(complaintFilterProvider.notifier).state = 'Resolved';
                          MainCitizenShellController.of(context)?.onSelectTab(1);
                        },
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
