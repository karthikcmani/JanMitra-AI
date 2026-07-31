import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'citizen_views.dart';
import 'admin_views.dart';
import 'janmitra_chat_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = appState.isDarkMode;
    final userRole = appState.userRole;

    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'JanMitra',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: AppTheme.aiGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Text(
                  userRole == UserRole.citizen ? 'Citizen Public Portal' : 'Admin Decision Support',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: userRole == UserRole.admin ? AppTheme.aiPurple : AppTheme.accentTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Role Toggle Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                _roleChip(
                  context: context,
                  label: 'Citizen',
                  icon: Icons.person_outline,
                  isSelected: userRole == UserRole.citizen,
                  onTap: () {
                    appState.switchUserRole(UserRole.citizen);
                    setState(() => _currentTabIndex = 0);
                  },
                ),
                _roleChip(
                  context: context,
                  label: 'Admin',
                  icon: Icons.admin_panel_settings_outlined,
                  isSelected: userRole == UserRole.admin,
                  onTap: () {
                    appState.switchUserRole(UserRole.admin);
                    setState(() => _currentTabIndex = 0);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Theme Switcher
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () => appState.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppStateProvider(
        state: appState,
        child: userRole == UserRole.citizen
            ? IndexedStack(
                index: _currentTabIndex,
                children: [
                  CitizenHomeView(
                    onNavigateToFileGrievance: () => setState(() => _currentTabIndex = 1),
                    onNavigateToGrievancesList: () => setState(() => _currentTabIndex = 2),
                  ),
                  FileGrievanceView(
                    onSuccessSubmitted: () => setState(() => _currentTabIndex = 2),
                  ),
                  const GrievanceListView(),
                  JanMitraChatView(
                    onNavigateTab: (idx) => setState(() => _currentTabIndex = idx),
                  ),
                ],
              )
            : IndexedStack(
                index: _currentTabIndex,
                children: [
                  AdminDashboardView(
                    onNavigateToTriage: () => setState(() => _currentTabIndex = 1),
                    onNavigateToHeatmap: () => setState(() => _currentTabIndex = 2),
                    onNavigateToAnalytics: () => setState(() => _currentTabIndex = 3),
                  ),
                  const AiTriageQueueView(),
                  const RegionalHeatmapView(),
                  const DepartmentAnalyticsView(),
                ],
              ),
      ),
      bottomNavigationBar: userRole == UserRole.citizen
          ? BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (idx) => setState(() => _currentTabIndex = idx),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primaryBlue,
              unselectedItemColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle_rounded),
                  label: 'File Issue',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.format_list_bulleted_rounded),
                  activeIcon: Icon(Icons.fact_check_rounded),
                  label: 'Track',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.psychology_outlined),
                  activeIcon: Icon(Icons.psychology_rounded),
                  label: 'AI Chat',
                ),
              ],
            )
          : BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (idx) => setState(() => _currentTabIndex = idx),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.aiPurple,
              unselectedItemColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.playlist_add_check_outlined),
                  activeIcon: Icon(Icons.playlist_add_check_circle_rounded),
                  label: 'AI Triage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map_rounded),
                  label: 'Heatmap',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Analytics',
                ),
              ],
            ),
    );
  }

  Widget _roleChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
