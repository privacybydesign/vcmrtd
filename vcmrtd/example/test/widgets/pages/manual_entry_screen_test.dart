import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_screen.dart';

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen({required DocumentType documentType, VoidCallback? onBack, void Function(ScannedMRZ)? onComplete}) {
  return MaterialApp(
    home: ManualEntryScreen(
      documentType: documentType,
      onBack: onBack ?? () {},
      onManualEntryComplete: onComplete ?? (_) {},
    ),
  );
}

void main() {
  group('ManualEntryRouteParams', () {
    test('round-trips through query params', () {
      final params = ManualEntryRouteParams(documentType: DocumentType.drivingLicence);
      final query = params.toQueryParams();
      final restored = ManualEntryRouteParams.fromQueryParams(query);
      expect(restored.documentType, DocumentType.drivingLicence);
    });
  });

  group('ManualEntryScreen — passport', () {
    testWidgets('renders passport fields and header', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.passport));
      await tester.pump();

      expect(find.text('Enter Passport Details'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Expiry Date'), findsOneWidget);
      expect(find.textContaining('Where to find this information:'), findsOneWidget);
    });

    testWidgets('back button fires onBack', (tester) async {
      _setLargeViewport(tester);
      var backed = false;
      await tester.pumpWidget(_screen(documentType: DocumentType.passport, onBack: () => backed = true));
      await tester.pump();

      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      expect(backed, isTrue);
    });

    testWidgets('submitting empty passport form shows validation errors and does not complete', (tester) async {
      _setLargeViewport(tester);
      var completed = false;
      await tester.pumpWidget(_screen(documentType: DocumentType.passport, onComplete: (_) => completed = true));
      await tester.pump();

      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.text('Passport number is required'), findsOneWidget);
      expect(find.text('Date of birth is required'), findsOneWidget);
      expect(find.text('Expiry date is required'), findsOneWidget);
      expect(completed, isFalse);
    });

    testWidgets('short document number triggers length validation error', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.passport));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'AB12');
      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.text('Passport number must be at least 6 characters'), findsOneWidget);
    });
  });

  group('ManualEntryScreen — driving licence', () {
    testWidgets('renders MRZ field and character counter', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence));
      await tester.pump();

      expect(find.text('Enter MRZ String'), findsWidgets);
      expect(find.text('Character count:'), findsOneWidget);
      expect(find.text('0 / 30'), findsOneWidget);
    });

    testWidgets('typing MRZ updates the character counter', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'D1NLD15094962111659VW87Z78NB84');
      await tester.pump();
      expect(find.text('30 / 30'), findsOneWidget);
    });

    testWidgets('empty MRZ submit shows required validation error', (tester) async {
      _setLargeViewport(tester);
      var completed = false;
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence, onComplete: (_) => completed = true));
      await tester.pump();

      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.text('MRZ string is required'), findsOneWidget);
      expect(completed, isFalse);
    });

    testWidgets('wrong-length MRZ shows length validation error', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'D1NLD123');
      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.text('MRZ must be exactly 30 characters'), findsOneWidget);
    });

    testWidgets('30-char MRZ with bad prefix shows prefix validation error', (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(_screen(documentType: DocumentType.drivingLicence));
      await tester.pump();

      // 30 chars but starts with XX (not D1/D2/DL).
      await tester.enterText(find.byType(TextField).first, 'XXNLD15094962111659VW87Z78NB84');
      await tester.tap(find.text('Continue to NFC Reading'));
      await tester.pump();

      expect(find.text('MRZ must start with D1, D2, or DL'), findsOneWidget);
    });
  });
}
