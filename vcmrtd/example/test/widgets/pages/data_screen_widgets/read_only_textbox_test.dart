import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/read_only_textbox.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/verify_result.dart';

void main() {
  group('ReadOnlyTextBox', () {
    testWidgets('renders label, value and info icon when not an error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadOnlyTextBox(label: 'Status', value: 'Yes', isError: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isTrue);
    });

    testWidgets('renders error icon when isError is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadOnlyTextBox(label: 'Problem', value: 'No', isError: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  });

  group('VerifyResultSection', () {
    testWidgets('renders the three verification rows mapping booleans to Yes/No', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VerifyResultSection(isExpired: false, authenticChip: true, authenticContent: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verification Result'), findsOneWidget);
      expect(find.text('Expired Document'), findsOneWidget);
      expect(find.text('Authentic Chip'), findsOneWidget);
      expect(find.text('Authentic Content'), findsOneWidget);

      // isExpired false -> No, authenticChip true -> Yes, authenticContent false -> No
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsNWidgets(2));
    });
  });
}
