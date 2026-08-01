import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  throw UnimplementedError(
    'sessionServiceProvider must be overridden in ProviderScope',
  );
});

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final sessionService = ref.watch(sessionServiceProvider);
  return ThemeNotifier(sessionService);
});

class ThemeNotifier extends StateNotifier<bool> {
  final SessionService _sessionService;

  ThemeNotifier(this._sessionService) : super(_sessionService.isDarkMode);

  Future<void> toggleTheme() async {
    final next = !state;
    state = next;
    await _sessionService.setDarkMode(next);
  }
}
