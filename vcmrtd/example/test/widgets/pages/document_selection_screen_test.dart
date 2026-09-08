import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

PassportData _passportData() {
  final mrz = PassportMRZ(
    Uint8List.fromList(
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
    ),
  );
  return PassportData(
    mrz: mrz,
    photoImageData: _jpeg(),
    photoImageType: ImageType.jpeg,
    photoImageWidth: 2,
    photoImageHeight: 2,
  );
}

Widget _app({required Function(DocumentType) onDocumentTypeSelected, required VoidCallback onSettingsPressed}) {
  return ProviderScope(
    child: MaterialApp(
      home: DocumentTypeSelectionScreen(
        onDocumentTypeSelected: onDocumentTypeSelected,
        onSettingsPressed: onSettingsPressed,
      ),
    ),
  );
}

void main() {
  group('DocumentTypeSelectionScreen with an empty wallet', () {
    testWidgets('renders three document type options and the advanced settings entry', (tester) async {
      await tester.pumpWidget(_app(onDocumentTypeSelected: (_) {}, onSettingsPressed: () {}));
      await tester.pump();
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Identity Card'), findsOneWidget);
      expect(find.text('Driving Licence'), findsOneWidget);
      expect(find.text('Advanced settings'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('tapping passport calls onDocumentTypeSelected with passport', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(_app(onDocumentTypeSelected: (t) => selected = t, onSettingsPressed: () {}));
      await tester.pump();
      await tester.tap(find.text('Passport'));
      expect(selected, DocumentType.passport);
    });

    testWidgets('tapping identity card calls onDocumentTypeSelected with identityCard', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(_app(onDocumentTypeSelected: (t) => selected = t, onSettingsPressed: () {}));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Identity Card'), 200);
      await tester.tap(find.text('Identity Card'));
      expect(selected, DocumentType.identityCard);
    });

    testWidgets('tapping driving licence calls onDocumentTypeSelected with drivingLicence', (tester) async {
      DocumentType? selected;
      await tester.pumpWidget(_app(onDocumentTypeSelected: (t) => selected = t, onSettingsPressed: () {}));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Driving Licence'), 200);
      await tester.tap(find.text('Driving Licence'));
      expect(selected, DocumentType.drivingLicence);
    });

    testWidgets('tapping advanced settings calls onSettingsPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_app(onDocumentTypeSelected: (_) {}, onSettingsPressed: () => pressed = true));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Advanced settings'), 200);
      await tester.tap(find.text('Advanced settings'));
      expect(pressed, isTrue);
    });
  });

  group('DocumentTypeSelectionScreen with cards in the wallet', () {
    testWidgets('shows only the wallet and the advanced settings entry, not the scan options', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(walletProvider.notifier).add(WalletCard.fromDocument(_passportData(), DocumentType.passport));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (_) {}, onSettingsPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ANNA MARIA ERIKSSON'), findsOneWidget);
      expect(find.text('Passport'), findsNothing);
      expect(find.text('Identity Card'), findsNothing);
      expect(find.text('Driving Licence'), findsNothing);
      expect(find.text('Advanced settings'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping the + button offers the scan options and starts a scan', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(walletProvider.notifier).add(WalletCard.fromDocument(_passportData(), DocumentType.passport));

      DocumentType? selected;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (t) => selected = t, onSettingsPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Passport'), findsOneWidget);
      await tester.tap(find.text('Passport'));
      await tester.pumpAndSettle();

      expect(selected, DocumentType.passport);
    });

    testWidgets('tapping a wallet card shows its details', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(walletProvider.notifier).add(WalletCard.fromDocument(_passportData(), DocumentType.passport));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DocumentTypeSelectionScreen(onDocumentTypeSelected: (_) {}, onSettingsPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('ANNA MARIA ERIKSSON'));
      await tester.pumpAndSettle();

      expect(find.text('Document number'), findsOneWidget);
      expect(find.text('Remove from wallet'), findsOneWidget);
    });
  });
}
