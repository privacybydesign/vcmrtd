// Additional coverage for ManualEntryScreen branches not exercised by
// manual_entry_screen_test.dart: the date-picker flow, the passport success
// submit path, the driving-licence valid/invalid submit paths and the
// rendered error-message container.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_screen.dart';

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({required DocumentType documentType, void Function(ScannedMRZ)? onComplete}) {
  return MaterialApp(
    home: ManualEntryScreen(documentType: documentType, onBack: () {}, onManualEntryComplete: onComplete ?? (_) {}),
  );
}

void main() {
  group('ManualEntryScreen — passport date picker and submit', () {
    testWidgets('selecting DOB via the date picker fills the field', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.passport));
      await tester.pump();

      // Tap the Date of Birth field (field 1, read-only -> opens the date picker).
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();

      // Confirm the default selection.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The DOB controller should now contain a formatted date (contains '/').
      final dobField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(dobField.controller!.text, contains('/'));
    });

    testWidgets('valid passport entry calls onManualEntryComplete with a ScannedPassportMRZ', (tester) async {
      _setLargeViewport(tester);
      ScannedMRZ? completed;
      await tester.pumpWidget(_screen(documentType: DocumentType.passport, onComplete: (mrz) => completed = mrz));
      await tester.pump();

      // Document number (field 0).
      await tester.enterText(find.byType(TextField).at(0), 'AB123456');

      // Pick a date of birth (field 1; default initial date is ~30 years ago).
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Pick an expiry date (field 2; default initial date is ~10 years out).
      await tester.tap(find.byType(TextField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify both date fields were populated before submitting.
      final dobField = tester.widget<TextField>(find.byType(TextField).at(1));
      final expiryField = tester.widget<TextField>(find.byType(TextField).at(2));
      expect(dobField.controller!.text, contains('/'));
      expect(expiryField.controller!.text, contains('/'));

      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(completed, isA<ScannedPassportMRZ>());
      final passport = completed as ScannedPassportMRZ;
      expect(passport.documentNumber, 'AB123456');
      expect(passport.documentType, DocumentType.passport);
    });
  });

  group('ManualEntryScreen — driving licence submit', () {
    testWidgets('valid MRZ calls onManualEntryComplete with a ScannedDriverLicenseMRZ', (tester) async {
      _setLargeViewport(tester);
      ScannedMRZ? completed;
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence, onComplete: (mrz) => completed = mrz));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'D1NLD11234567890ABCDEFGHIJKLM5');
      await tester.pump();

      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(completed, isA<ScannedDriverLicenseMRZ>());
      final licence = completed as ScannedDriverLicenseMRZ;
      expect(licence.documentNumber, '1234567890');
      expect(licence.version, '1');
    });

    testWidgets('30-char MRZ that fails to parse shows the parse error message', (tester) async {
      _setLargeViewport(tester);
      var completed = false;
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence, onComplete: (_) => completed = true));
      await tester.pump();

      // 30 chars, starts with D1, passes form validation but has a bad check
      // digit so the parser throws -> error message container is rendered.
      await tester.enterText(find.byType(TextField).first, 'D1NLD11234567890ABCDEFGHIJKLM0');
      await tester.pump();

      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.textContaining('Failed to parse MRZ:'), findsOneWidget);
      expect(completed, isFalse);
    });
  });
}
