import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/main_citizen_shell.dart';
import '../screens/complaints/complaint_form_screen.dart';
import '../screens/official/official_dashboard_screen.dart';
import '../screens/official/official_grievance_detail_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/ai/ai_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainCitizenShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/complaints',
        builder: (context, state) => const MainCitizenShell(initialIndex: 1),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ComplaintFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return ComplaintFormScreen(complaintId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const MainCitizenShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const MainCitizenShell(initialIndex: 3),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => const AiScreen(),
      ),
      GoRoute(
        path: '/official-dashboard',
        builder: (context, state) => const OfficialDashboardScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/official/grievance/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OfficialGrievanceDetailScreen(grievanceId: id);
        },
      ),
    ],
  );
});
