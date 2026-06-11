import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/ocr_engine_provider.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';

void main() {
  group('DocumentTypeSelectionScreen', () {
    testWidgets('renders three document type options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (_) {})),
        ),
      );
      await tester.pump();
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Identity Card'), findsOneWidget);
      expect(find.text('Driving Licence'), findsOneWidget);
    });

    testWidgets('tapping passport calls onDocumentTypeSelected with passport', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (t) => selected = t)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Passport'));
      expect(selected, DocumentType.passport);
    });

    testWidgets('tapping identity card calls onDocumentTypeSelected with identityCard', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (t) => selected = t)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Identity Card'));
      expect(selected, DocumentType.identityCard);
    });

    testWidgets('tapping driving licence calls onDocumentTypeSelected with drivingLicence', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (t) => selected = t)),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Driving Licence'), 200);
      await tester.tap(find.text('Driving Licence'));
      expect(selected, DocumentType.drivingLicence);
    });

    testWidgets('active authentication switch updates provider state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (_) {})),
        ),
      );
      await tester.pump();

      expect(container.read(activeAuthenticationProvider), isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(container.read(activeAuthenticationProvider), isFalse);
    });

    testWidgets('OCR engine dropdown can be shown and updates provider state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (_) {}, showOcrEngineForTesting: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('OCR engine'), findsOneWidget);

      final dropdown = tester.widget<DropdownButton<OcrEngine>>(find.byType(DropdownButton<OcrEngine>));
      dropdown.onChanged!(OcrEngine.tesseract4android);
      await tester.pump();

      expect(container.read(ocrEngineProvider), OcrEngine.tesseract4android);
    });
  });
}
