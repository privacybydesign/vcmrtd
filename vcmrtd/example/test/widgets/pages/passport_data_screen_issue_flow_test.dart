// Coverage for the PassportDataScreen "return to issuer" flow
// (_returnToIssue, _showReturnSuccessDialog and the error dialog), which is not
// exercised by data_screen_verify_flow_test.dart (that covers verify only).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
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

/// Fake issuer exercising the issuance branch of the data screen.
class _FakeIssuer extends DefaultPassportIssuer {
  final IrmaSessionPointer? pointer;
  final Object? error;

  _FakeIssuer({this.pointer, this.error}) : super(hostName: 'https://test.local');

  @override
  Future<IrmaSessionPointer> startIrmaIssuanceSession(RawDocumentData result, DocumentType docType) async {
    if (error != null) throw error!;
    return pointer!;
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _screen(_FakeIssuer issuer, {VoidCallback? onBack}) {
  return ProviderScope(
    overrides: [passportIssuerProvider.overrideWithValue(issuer)],
    child: MaterialApp(
      home: PassportDataScreen(
        document: _passportData(),
        passportDataResult: _rawDocument(sessionId: 'session-1'),
        onBackPressed: onBack ?? () {},
        onFaceVerification: (_) {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(launcherChannel, (call) async {
      // url_launcher queries canLaunch then launch; return success for both.
      return true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(launcherChannel, null);
  });

  testWidgets('successful issuance launches the universal link and shows the success dialog', (tester) async {
    _setLargeViewport(tester);
    var backCount = 0;
    final issuer = _FakeIssuer(
      pointer: IrmaSessionPointer(u: 'http://issuer/session/abc', irmaqr: 'issuing'),
    );

    await tester.pumpWidget(_screen(issuer, onBack: () => backCount++));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Issue a Credential with Yivi'), 300);
    await tester.tap(find.text('Issue a Credential with Yivi'));
    await tester.pumpAndSettle();

    expect(find.text('Success!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Continue invokes onBackPressed.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(backCount, 1);
  });

  testWidgets('issuance failure shows the return-failed error dialog', (tester) async {
    _setLargeViewport(tester);
    final issuer = _FakeIssuer(error: Exception('issuer unreachable'));

    await tester.pumpWidget(_screen(issuer));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Issue a Credential with Yivi'), 300);
    await tester.tap(find.text('Issue a Credential with Yivi'));
    await tester.pumpAndSettle();

    expect(find.text('Return Failed'), findsOneWidget);
    expect(find.textContaining('issuer unreachable'), findsOneWidget);
  });
}
