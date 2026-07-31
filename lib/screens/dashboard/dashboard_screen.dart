import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentBottomNavIndex = 0;

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

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      setState(() {
        _currentBottomNavIndex = 0;
      });
      return;
    }

    switch (index) {
      case 1:
        Navigator.pushNamed(context, AppRoutes.complaints);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.ai);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.profile);
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.secondaryTeal,
                child: Text(
                  'C',
                  style: TextStyle(
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
            _buildGreetingCard(),
            const SizedBox(height: 20),

            // Statistics Cards Grid
            const Text(
              'Grievance Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatisticsGrid(),

            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickActionsGrid(),

            const SizedBox(height: 24),

            // Recent Activity Card
            _buildRecentActivityCard(),

            const SizedBox(height: 24),

            // Latest Government Updates Card
            _buildGovernmentUpdatesCard(),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
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
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 100,
              color: Colors.white.withAlpha(25),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'AI Active • Smart Portal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_getGreeting()}, Citizen',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit, track and resolve grievances using AI-driven automated routing.',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth > 360 ? 0.95 : 0.85,
          children: const [
            StatCard(
              title: 'Total',
              count: '24',
              icon: Icons.folder_open_rounded,
              iconColor: AppTheme.primaryBlue,
              iconBgColor: Color(0xFFE0F2FE),
              subtitle: 'Grievances',
            ),
            StatCard(
              title: 'Pending',
              count: '05',
              icon: Icons.hourglass_top_rounded,
              iconColor: AppTheme.warning,
              iconBgColor: Color(0xFFFEF3C7),
              subtitle: 'In Progress',
            ),
            StatCard(
              title: 'Resolved',
              count: '19',
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppTheme.success,
              iconBgColor: Color(0xD1D1FADF),
              subtitle: 'Completed',
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {
        'title': 'File Complaint',
        'subtitle': 'Submit new grievance',
        'icon': Icons.add_circle_outline_rounded,
        'color': AppTheme.primaryBlue,
        'bgColor': const Color(0xFFE0F2FE),
        'route': AppRoutes.complaints,
      },
      {
        'title': 'AI Assistant',
        'subtitle': 'Ask JanMitra AI',
        'icon': Icons.smart_toy_rounded,
        'color': AppTheme.secondaryTeal,
        'bgColor': const Color(0xFFCCFBF1),
        'route': AppRoutes.ai,
      },
      {
        'title': 'Track Complaint',
        'subtitle': 'Check status by ID',
        'icon': Icons.my_location_rounded,
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFEDE9FE),
        'route': AppRoutes.tracking,
      },
      {
        'title': 'Notifications',
        'subtitle': 'Updates & Alerts',
        'icon': Icons.notifications_none_rounded,
        'color': AppTheme.warning,
        'bgColor': const Color(0xFFFEF3C7),
        'route': AppRoutes.notifications,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          onTap: () {
            Navigator.pushNamed(context, item['route'] as String);
          },
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
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
                    color: item['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 22,
                    color: item['color'] as Color,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  item['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
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
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.complaints);
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildActivityTile(
            title: 'Water Supply Disruption #GR-9842',
            department: 'Municipal Water Board',
            status: 'In Progress',
            statusColor: AppTheme.warning,
            date: 'Today, 09:30 AM',
          ),
          const Divider(color: AppTheme.borderLight, height: 20),
          _buildActivityTile(
            title: 'Streetlight Repair Request #GR-9810',
            department: 'Public Works Dept',
            status: 'Resolved',
            statusColor: AppTheme.success,
            date: 'Yesterday, 04:15 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String department,
    required String status,
    required Color statusColor,
    required String date,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$department • $date',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGovernmentUpdatesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.campaign_outlined, color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Latest Government Directives',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'JanMitra AI now automatically routes priority civic issues directly to municipal zonal officers within 15 minutes of submission.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
