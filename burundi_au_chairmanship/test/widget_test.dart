import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:burundi_au_chairmanship/widgets/verified_badge.dart';

// Smoke test that needs no Firebase/platform channels: the real app can't be
// pumped in a plain widget test (Firebase.initializeApp has no test binding).
void main() {
  testWidgets('VerifiedBadge renders for GOLD and hides for NONE',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [
        VerifiedBadge(badgeType: 'GOLD'),
        VerifiedBadge(badgeType: 'NONE'),
      ]),
    ));

    expect(find.byType(VerifiedBadge), findsNWidgets(2));
    expect(find.byType(Icon), findsOneWidget);
  });
}
