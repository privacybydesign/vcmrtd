import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/services/regula_face_service.dart';
import 'package:vcmrtdapp/widgets/pages/regula_result_screen.dart';

Future<void> _pump(WidgetTester tester, RegulaFaceResult result) {
  return tester.pumpWidget(
    MaterialApp(
      home: RegulaResultScreen(result: result, onBackPressed: () {}, onRetry: () {}),
    ),
  );
}

void main() {
  testWidgets('shortens a long transaction id', (tester) async {
    await _pump(
      tester,
      const RegulaFaceResult(isLive: true, matchThreshold: 0.75, similarity: 0.9, transactionId: 'abcdefghijklmnop'),
    );

    expect(find.text('Identity Verified'), findsOneWidget);
    expect(find.text('abcdef…mnop'), findsOneWidget);
  });

  testWidgets('renders a failed verification when not live and unmatched', (tester) async {
    await _pump(tester, const RegulaFaceResult(isLive: false, matchThreshold: 0.75, transactionId: null));

    expect(find.text('Verification Failed'), findsOneWidget);
    expect(find.text('not live'), findsOneWidget);
    // No similarity available and no transaction id -> both shown as n/a.
    expect(find.text('n/a'), findsNWidgets(2));
  });
}
