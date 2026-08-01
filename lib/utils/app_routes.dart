import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/complaints/complaints_screen.dart';
import '../screens/ai/ai_screen.dart';
import '../screens/tracking/tracking_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String complaints = '/complaints';
  static const String ai = '/ai';
  static const String tracking = '/tracking';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    dashboard: (context) => const DashboardScreen(),
    complaints: (context) => const ComplaintsScreen(),
    ai: (context) => const AiScreen(),
    tracking: (context) => const TrackingScreen(),
    notifications: (context) => const NotificationsScreen(),
    profile: (context) => const ProfileScreen(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(builder: (context) => const SplashScreen());
  }
}
