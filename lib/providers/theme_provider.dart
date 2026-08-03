import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';
import '../services/secure_storage_service.dart';
import '../services/api_service.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError(
    'preferencesServiceProvider must be overridden in ProviderScope',
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return ApiService(secureStorage: secureStorage);
});

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return ThemeNotifier(preferencesService);
});

class ThemeNotifier extends StateNotifier<bool> {
  final PreferencesService _preferencesService;

  ThemeNotifier(this._preferencesService)
    : super(_preferencesService.isDarkMode);

  Future<void> toggleTheme() async {
    final next = !state;
    state = next;
    await _preferencesService.setDarkMode(next);
  }
}
