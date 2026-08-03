import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_router.dart';
import 'providers/theme_provider.dart';
import 'services/preferences_service.dart';
import 'services/secure_storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences & SecureStorage
  final preferencesService = await PreferencesService.init();
  final secureStorageService = SecureStorageService();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
        secureStorageServiceProvider.overrideWithValue(secureStorageService),
      ],
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
