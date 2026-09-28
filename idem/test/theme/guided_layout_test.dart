import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/reader_providers.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_brand.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/theme/brands/cm_theme.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/nfc_reading_screen.dart';
import 'package:idem/widgets/pages/passport_data_screen.dart';
import 'package:idem/widgets/pages/proofing_session_consent_screen.dart';
import 'package:idem/widgets/pages/scanner_wrapper.dart';

class _FakeReader extends DocumentReader<PassportData> {
  _FakeReader()
    : super(
        documentParser: PassportParser(),
        dataGroupReader: DataGroupReader(NfcProvider(), DF1.PassportAID),
        nfc: NfcProvider(),
        config: const DocumentReaderConfig(readIfAvailable: {}),
      );

  static DocumentReaderState initialState = DocumentReaderPending();

  @override
  DocumentReaderState build() => initialState;

  @override
  Future<void> checkNfcAvailability() async {}
}

PassportData _passport() => PassportData(
  mrz: PassportMRZ(
    Uint8List.fromList(
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
    ),
  ),
  photoImageData: Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2))),
  photoImageType: ImageType.jpeg,
  photoImageWidth: 2,
  photoImageHeight: 2,
  nameOfHolder: 'ANNA MARIA ERIKSSON',
);

ProofingSessionInfo _session(String relyingParty) => ProofingSessionInfo(
  id: 'session-1',
  relyingParty: relyingParty,
  requestedAttributes: const ['dg1', 'dg2'],
  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
);

Widget _cm(Widget home, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(theme: AppBrand.cm.theme, home: home),
);

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('only brands that opt in get the guided layout', () {
    expect(cmBrandTheme.guided, isNotNull);
    expect(BrandTheme.idem.guided, isNull);
  });

  group('guided home', () {
    testWidgets('shows the three-step hero and routes taps to the callbacks', (tester) async {
      _tallViewport(tester);
      DocumentType? selected;
      var settings = 0;
      await tester.pumpWidget(
        _cm(
          DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (t) => selected = t,
            onSettingsPressed: () => settings++,
            onScanQrPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verify your identity in three steps'), findsOneWidget);
      expect(find.text('Advanced settings'), findsNothing);

      await tester.tap(find.text('Identity card'));
      expect(selected, DocumentType.identityCard);
      await tester.tap(find.byTooltip('Settings'));
      expect(settings, 1);
    });
  });

  testWidgets('guided scan frame sits where the MRZ scanner reads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
    );
    final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));
    for (final size in const [Size(360, 740), Size(390, 844), Size(844, 390)]) {
      expect(guidedScanFrame(size), state.overlayRectForTesting(size), reason: '$size');
    }
  });

  testWidgets('guided NFC reading lists what has been read so far', (tester) async {
    _tallViewport(tester);
    _FakeReader.initialState = DocumentReaderReadingDataGroup(dataGroup: 'DG2', progress: 0.5);
    await tester.pumpWidget(
      _cm(
        NfcReadingScreen(
          params: NfcReadingRouteParams(
            scannedMRZ: ScannedPassportMRZ(
              documentNumber: 'L898902C3',
              countryCode: 'UTO',
              dateOfBirth: DateTime(1974, 8, 12),
              dateOfExpiry: DateTime(2030, 1, 1),
              documentType: DocumentType.passport,
            ),
            documentType: DocumentType.passport,
          ),
          onSuccess: (_, _) {},
        ),
        overrides: [passportReaderProvider.overrideWith2((_) => _FakeReader())],
      ),
    );
    await tester.pump();

    expect(find.text('Personal details read'), findsOneWidget);
    expect(find.text('Reading passport photo'), findsOneWidget);
    expect(find.text('Checking the chip is genuine'), findsOneWidget);
  });

  group('guided result', () {
    Future<void> pump(WidgetTester tester, {FaceVerificationOutcome? face}) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        _cm(
          PassportDataScreen(
            document: _passport(),
            passportDataResult: RawDocumentData(dataGroups: const {}, efSod: '00'),
            onBackPressed: () {},
            faceVerification: face,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('says verified only after a face match, and never claims the chip is genuine', (tester) async {
      await pump(tester, face: const FaceVerificationOutcome(engine: 'on_device', livenessPassed: true));
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Face matched'), findsOneWidget);
      expect(find.text('Anna Maria Eriksson'), findsOneWidget);
      expect(find.textContaining('genuine'), findsNothing);

      await pump(tester);
      expect(find.text('Document read'), findsOneWidget);
      expect(find.text('Face matched'), findsNothing);
      expect(find.text('Chip read'), findsOneWidget);
    });
  });

  group('guided consent', () {
    testWidgets('shows the brand mark only when the brand itself is asking', (tester) async {
      _tallViewport(tester);
      var consented = 0;
      var declined = 0;
      await tester.pumpWidget(
        _cm(
          ProofingSessionConsentScreen(
            info: _session('CM.com'),
            onConsent: () => consented++,
            onDecline: () => declined++,
          ),
        ),
      );
      expect(find.text('CM.com wants to verify your identity'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Decline'));
      expect((consented, declined), (1, 1));

      await tester.pumpWidget(
        _cm(ProofingSessionConsentScreen(info: _session('Acme Bank'), onConsent: () {}, onDecline: () {})),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('the idem brand keeps the classic consent screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppBrand.idem.theme,
          home: ProofingSessionConsentScreen(info: _session('CM.com'), onConsent: () {}, onDecline: () {}),
        ),
      );
      expect(find.text('Identity proofing request'), findsOneWidget);
    });
  });
}
