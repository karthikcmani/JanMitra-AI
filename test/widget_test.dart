import 'package:flutter_test/flutter_test.dart';
import 'package:janmitra_ai/main.dart';

void main() {
  testWidgets('JanMitra AI App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const JanMitraApp());

    // Verify that JanMitra AI title appears
    expect(find.text('JanMitra AI'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
  });
}
