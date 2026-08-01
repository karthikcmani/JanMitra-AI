import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:janmitra_ai/main.dart';
import 'package:janmitra_ai/services/session_service.dart';
import 'package:janmitra_ai/providers/theme_provider.dart';

void main() {
  testWidgets('JanMitra AI App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sessionService = SessionService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionServiceProvider.overrideWithValue(sessionService)],
        child: const JanMitraApp(),
      ),
    );

    // Verify that JanMitra AI splash screen appears initially
    expect(find.text('JanMitra AI'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);

    // Advance timer past splash transition (2.5 seconds)
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
