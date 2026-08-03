import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:janmitra_ai/main.dart';
import 'package:janmitra_ai/services/preferences_service.dart';
import 'package:janmitra_ai/services/secure_storage_service.dart';
import 'package:janmitra_ai/providers/theme_provider.dart';

void main() {
  testWidgets('JanMitra AI App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = PreferencesService(prefs);
    final secureStorageService = SecureStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(preferencesService),
          secureStorageServiceProvider.overrideWithValue(secureStorageService),
        ],
        child: const JanMitraApp(),
      ),
    );

    // Verify that JanMitra AI splash screen appears initially
    expect(find.text('JanMitra AI'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);

    // Advance timer past splash transition (1.5 seconds)
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
