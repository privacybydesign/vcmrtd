import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

RawDocumentData _rawDocument({String? sessionId}) =>
    RawDocumentData(dataGroups: const {}, efSod: '00', sessionId: sessionId);

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
    categories: const [],
    photoImageType: ImageType.jpeg,
  );
}

/// Fake issuer that returns a canned response or throws, to exercise the
/// verify success / error branches of the data screens.
class _FakeIssuer extends DefaultPassportIssuer {
  final VerificationResponse? response;
  final Object? error;

  _FakeIssuer({this.response, this.error}) : super(hostName: 'https://test.local');

  @override
  Future<VerificationResponse> verifyPassport(RawDocumentData passportDataResult) async {
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<VerificationResponse> verifyDrivingLicence(RawDocumentData drivingLicenceDataResult) async {
    if (error != null) throw error!;
    return response!;
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _passportScreen(_FakeIssuer issuer) {
  return ProviderScope(
    overrides: [passportIssuerProvider.overrideWithValue(issuer)],
    child: MaterialApp(
      home: PassportDataScreen(
        document: _passportData(),
        passportDataResult: _rawDocument(sessionId: 'session-1'),
        onBackPressed: () {},
        onFaceVerification: (_) {},
      ),
    ),
  );
}

Widget _licenceScreen(_FakeIssuer issuer) {
  return ProviderScope(
    overrides: [passportIssuerProvider.overrideWithValue(issuer)],
    child: MaterialApp(
      home: DrivingLicenceDataScreen(
        drivingLicence: _drivingLicenceData(),
        drivingLicenceDataResult: _rawDocument(sessionId: 'session-2'),
        onBackPressed: () {},
        onFaceVerification: (_) {},
      ),
    ),
  );
}

void main() {
  group('PassportDataScreen verify flow', () {
    testWidgets('successful verify renders VerifyResultSection', (tester) async {
      _setLargeViewport(tester);
      final issuer = _FakeIssuer(
        response: VerificationResponse(isExpired: false, authenticChip: true, authenticContent: true),
      );
      await tester.pumpWidget(_passportScreen(issuer));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Verify via our API'), 300);
      await tester.tap(find.text('Verify via our API'));
      await tester.pumpAndSettle();

      expect(find.text('Verification Result'), findsOneWidget);
      expect(find.text('Authentic Chip'), findsOneWidget);
    });

    testWidgets('verify failure shows error dialog', (tester) async {
      _setLargeViewport(tester);
      final issuer = _FakeIssuer(error: Exception('network down'));
      await tester.pumpWidget(_passportScreen(issuer));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Verify via our API'), 300);
      await tester.tap(find.text('Verify via our API'));
      await tester.pumpAndSettle();

      expect(find.text('Return Failed'), findsOneWidget);
      expect(find.textContaining('network down'), findsOneWidget);
    });
  });

  group('DrivingLicenceDataScreen verify flow', () {
    testWidgets('successful verify renders VerifyResultSection', (tester) async {
      _setLargeViewport(tester);
      final issuer = _FakeIssuer(
        response: VerificationResponse(isExpired: true, authenticChip: false, authenticContent: true),
      );
      await tester.pumpWidget(_licenceScreen(issuer));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Verify via our API'), 300);
      await tester.tap(find.text('Verify via our API'));
      await tester.pumpAndSettle();

      expect(find.text('Verification Result'), findsOneWidget);
    });

    testWidgets('verify failure shows error dialog', (tester) async {
      _setLargeViewport(tester);
      final issuer = _FakeIssuer(error: Exception('boom'));
      await tester.pumpWidget(_licenceScreen(issuer));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Verify via our API'), 300);
      await tester.tap(find.text('Verify via our API'));
      await tester.pumpAndSettle();

      expect(find.text('Verification Failed'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });
}
