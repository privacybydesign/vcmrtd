import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/widgets/pages/data_screen_widgets/read_only_textbox.dart';

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
}
