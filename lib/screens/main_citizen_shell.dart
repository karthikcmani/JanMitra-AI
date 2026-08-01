import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'complaints/complaint_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';
import 'tracking/tracking_screen.dart';

class MainCitizenShellController extends InheritedWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  const MainCitizenShellController({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required super.child,
  });

  static MainCitizenShellController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MainCitizenShellController>();
  }

  @override
  bool updateShouldNotify(MainCitizenShellController oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}

class MainCitizenShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainCitizenShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainCitizenShell> createState() => _MainCitizenShellState();
}

class _MainCitizenShellState extends ConsumerState<MainCitizenShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(MainCitizenShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  void _onTabSelected(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainCitizenShellController(
      currentIndex: _currentIndex,
      onSelectTab: _onTabSelected,
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _currentIndex,
            children: const [
              DashboardScreen(),
              ComplaintListScreen(),
              TrackingScreen(),
              ProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: isDark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          indicatorColor: AppTheme.primaryBlue.withAlpha(isDark ? 80 : 35),
          elevation: 8,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: AppTheme.primaryBlue,
              ),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(
                Icons.assignment_rounded,
                color: AppTheme.primaryBlue,
              ),
              label: 'Complaints',
            ),
            NavigationDestination(
              icon: Icon(Icons.my_location_outlined),
              selectedIcon: Icon(
                Icons.my_location_rounded,
                color: AppTheme.primaryBlue,
              ),
              label: 'Tracking',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: AppTheme.primaryBlue,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
