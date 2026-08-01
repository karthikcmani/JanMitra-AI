import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_router.dart';
import 'providers/theme_provider.dart';
import 'services/hive_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Databases & Session Storage
  await HiveService.init();
  final sessionService = await SessionService.init();

  runApp(
    ProviderScope(
      overrides: [sessionServiceProvider.overrideWithValue(sessionService)],
      child: const JanMitraApp(),
    ),
  );
}

class JanMitraApp extends ConsumerWidget {
  const JanMitraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
