import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';

Uint8List _jpeg() {
  return Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));
}

RawDocumentData _rawDocument({String? sessionId}) {
  return RawDocumentData(dataGroups: const {}, efSod: '00', sessionId: sessionId);
}

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
    nameOfHolder: 'ANNA MARIA ERIKSSON',
    dateOfIssue: DateTime(2024, 2, 1),
    issuingAuthority: 'UTO Authority',
  );
}

DrivingLicenceData _drivingLicenceData() {
  return DrivingLicenceData(
    issuingMemberState: 'NLD',
    holderSurname: 'Eriksson',
    holderOtherName: 'Anna Maria',
    dateOfBirth: '12081974',
    placeOfBirth: 'Utopia',
    dateOfIssue: '01022024',
    dateOfExpiry: '01022034',
    issuingAuthority: 'RDW',
    documentNumber: '1234567890',
    photoImageData: _jpeg(),
    bapInputString: 'D1NLD11234567890ABCDEFGHIJKLM5',
    saiType: 'sai',
    aaPublicKey: null,
    categories: [DrivingLicenceCategory(category: 'B', dateOfIssue: '01022024', dateOfExpiry: '01022034')],
    photoImageType: ImageType.jpeg,
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('PassportDataScreen renders document data and starts face verification', (tester) async {
    _setLargeViewport(tester);
    final passport = _passportData();
    Uint8List? faceBytes;
    DateTime? issueDate;
    var backCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PassportDataScreen(
            document: passport,
            passportDataResult: _rawDocument(sessionId: 'session-1'),
            onBackPressed: () => backCount++,
            onFaceVerification: (bytes, date) {
              faceBytes = bytes;
              issueDate = date;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Passport Data'), findsOneWidget);
    expect(find.text('Web Authentication Session'), findsOneWidget);
    expect(find.text('ANNA MARIA ERIKSSON'), findsOneWidget);
    expect(find.text('Available Data Groups'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Start Face Verification'), 300);
    await tester.tap(find.text('Start Face Verification'));
    await tester.pump();

    expect(faceBytes, same(passport.photoImageData));
    expect(issueDate, DateTime(2024, 2, 1));

    await tester.tap(find.byType(IconButton).first);
    expect(backCount, 1);
  });

  testWidgets('DrivingLicenceDataScreen renders licence data and parses issue date for face verification', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final licence = _drivingLicenceData();
    Uint8List? faceBytes;
    DateTime? issueDate;
    var backCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DrivingLicenceDataScreen(
            drivingLicence: licence,
            drivingLicenceDataResult: _rawDocument(sessionId: 'session-2'),
            onBackPressed: () => backCount++,
            onFaceVerification: (bytes, date) {
              faceBytes = bytes;
              issueDate = date;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Driving Licence Data'), findsOneWidget);
    expect(find.text('Web Authentication Session'), findsOneWidget);
    expect(find.text('Eriksson'), findsOneWidget);
    expect(find.text('12/08/1974'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Start Face Verification'), 300);
    await tester.tap(find.text('Start Face Verification'));
    await tester.pump();

    expect(faceBytes, same(licence.photoImageData));
    expect(issueDate, DateTime(2024, 2, 1));

    await tester.tap(find.byType(IconButton).first);
    expect(backCount, 1);
  });
}
