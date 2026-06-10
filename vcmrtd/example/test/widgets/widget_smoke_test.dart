import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_guidance_screen.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/profile_picture.dart';

void main() {
  group('NfcGuidanceScreen', () {
    testWidgets('renders scaffold for passport document type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NfcGuidanceScreen(onStartReading: () {}, onBack: () {}, documentType: DocumentType.passport),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders scaffold for driving licence document type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NfcGuidanceScreen(onStartReading: () {}, onBack: () {}, documentType: DocumentType.drivingLicence),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('onBack callback fires when back button tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: NfcGuidanceScreen(
            onStartReading: () {},
            onBack: () => called = true,
            documentType: DocumentType.passport,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(IconButton).first);
      expect(called, isTrue);
    });

    testWidgets('onTroubleshooting button not shown when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NfcGuidanceScreen(onStartReading: () {}, onBack: () {}, documentType: DocumentType.passport),
        ),
      );
      await tester.pump();
      expect(find.text('Having trouble?'), findsNothing);
    });

    testWidgets('onTroubleshooting button shown when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NfcGuidanceScreen(
            onStartReading: () {},
            onBack: () {},
            onTroubleshooting: () {},
            documentType: DocumentType.passport,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Having trouble?'), findsOneWidget);
    });
  });

  group('ProfilePictureWidget', () {
    testWidgets('shows placeholder icon when imageData is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfilePictureWidget(imageData: null, imageType: null))),
      );
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('No Photo'), findsOneWidget);
    });

    testWidgets('renders JPEG photo data with Image.memory', (tester) async {
      final image = img.Image(width: 2, height: 2);
      final jpeg = Uint8List.fromList(img.encodeJpg(image));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePictureWidget(imageData: jpeg, imageType: ImageType.jpeg),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.text('No Photo'), findsNothing);
    });
  });

  group('ScannedMRZ', () {
    test('ScannedPassportMRZ.fromManualEntry creates correct instance', () {
      final dob = DateTime(1990, 1, 1);
      final exp = DateTime(2030, 12, 31);
      final mrz = ScannedPassportMRZ.fromManualEntry(
        documentNumber: 'AB123456',
        dateOfBirth: dob,
        dateOfExpiry: exp,
        countryCode: 'NLD',
      );
      expect(mrz.documentNumber, 'AB123456');
      expect(mrz.countryCode, 'NLD');
      expect(mrz.dateOfBirth, dob);
      expect(mrz.dateOfExpiry, exp);
      expect(mrz.documentType, DocumentType.passport);
    });

    test('ScannedPassportMRZ with identityCard documentType', () {
      final mrz = ScannedPassportMRZ.fromManualEntry(
        documentNumber: 'ID123456',
        dateOfBirth: DateTime(1985, 6, 15),
        dateOfExpiry: DateTime(2025, 6, 15),
        documentType: DocumentType.identityCard,
      );
      expect(mrz.documentType, DocumentType.identityCard);
    });

    test('ScannedIdCardMRZ.fromManualEntry defaults to identityCard', () {
      final mrz = ScannedIdCardMRZ.fromManualEntry(
        documentNumber: 'XY987654',
        dateOfBirth: DateTime(2000, 3, 20),
        dateOfExpiry: DateTime(2028, 3, 20),
      );
      expect(mrz.documentType, DocumentType.identityCard);
      expect(mrz.documentNumber, 'XY987654');
    });
  });
}
