import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';

void main() {
  group('DocumentTypeSelectionScreen', () {
    testWidgets('renders three document type options and the advanced settings entry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (_) {},
            onSettingsPressed: () {},
            onWalletPressed: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Identity Card'), findsOneWidget);
      expect(find.text('Driving Licence'), findsOneWidget);
      expect(find.text('Advanced settings'), findsOneWidget);
    });

    testWidgets('tapping passport calls onDocumentTypeSelected with passport', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (t) => selected = t,
            onSettingsPressed: () {},
            onWalletPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Passport'));
      expect(selected, DocumentType.passport);
    });

    testWidgets('tapping identity card calls onDocumentTypeSelected with identityCard', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (t) => selected = t,
            onSettingsPressed: () {},
            onWalletPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Identity Card'), 200);
      await tester.tap(find.text('Identity Card'));
      expect(selected, DocumentType.identityCard);
    });

    testWidgets('tapping driving licence calls onDocumentTypeSelected with drivingLicence', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (t) => selected = t,
            onSettingsPressed: () {},
            onWalletPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Driving Licence'), 200);
      await tester.tap(find.text('Driving Licence'));
      expect(selected, DocumentType.drivingLicence);
    });

    testWidgets('tapping advanced settings calls onSettingsPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (_) {},
            onSettingsPressed: () => pressed = true,
            onWalletPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Advanced settings'), 200);
      await tester.tap(find.text('Advanced settings'));
      expect(pressed, isTrue);
    });
  });
}
