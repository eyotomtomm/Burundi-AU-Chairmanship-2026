import 'package:flutter_test/flutter_test.dart';
import 'package:burundi_au_chairmanship/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BurundiAUApp());
    await tester.pump();

    // Verify that the app starts (splash screen should be visible)
    expect(find.byType(BurundiAUApp), findsOneWidget);
  });
}
