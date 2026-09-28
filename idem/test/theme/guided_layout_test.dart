import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/reader_providers.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_brand.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/theme/brands/cm_theme.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/routing.dart';
import 'package:idem/widgets/pages/choose_document_screen.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/face_verification_screen.dart';
import 'package:idem/widgets/pages/qr_scanner_screen.dart';
import 'package:idem/widgets/pages/saved_documents_screen.dart';
import 'package:face_verification/face_verification.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:idem/widgets/pages/driving_licence_data_screen.dart';
import 'package:idem/widgets/pages/guided_manual_entry_screen.dart';
import 'package:idem/widgets/pages/settings_screen.dart';
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

class _SeededWallet extends WalletNotifier {
  _SeededWallet(this.seed);
  final List<WalletCard> seed;
  @override
  List<WalletCard> build() => seed;
}

WalletCard _walletCard(String id, DocumentType type) => WalletCard(
  id: id,
  documentType: type,
  holderName: 'Anna Maria Eriksson',
  documentNumber: 'SPECI2014',
  photoImageData: Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2))),
  photoImageType: ImageType.jpeg,
  addedAt: DateTime(2026, 9, 12),
);

ProofingSessionInfo _session(String relyingParty) => ProofingSessionInfo(
  id: 'session-1',
  relyingParty: relyingParty,
  requestedAttributes: const ['dg1', 'dg2'],
  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
);

Widget _cm(Widget home, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppBrand.cm.theme,
    home: home,
  ),
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

  testWidgets('guided scan frame sits where the MRZ scanner reads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {}),
      ),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppBrand.idem.theme,
          home: ProofingSessionConsentScreen(info: _session('CM.com'), onConsent: () {}, onDecline: () {}),
        ),
      );
      expect(find.text('Identity proofing request'), findsOneWidget);
    });
  });

  group('guided manual entry', () {
    Future<void> pump(WidgetTester tester, DocumentType type, {ValueChanged<ScannedMRZ>? onComplete}) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        _cm(GuidedManualEntryScreen(documentType: type, onBack: () {}, onManualEntryComplete: onComplete ?? (_) {})),
      );
    }

    testWidgets('an ID card asks for number and dates, not the licence code', (tester) async {
      await pump(tester, DocumentType.identityCard);
      expect(find.text('Identity card number'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(find.text('Licence code'), findsNothing);
    });

    testWidgets('an empty form shows the shared validation errors', (tester) async {
      await pump(tester, DocumentType.passport);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Passport number is required'), findsOneWidget);
      expect(find.text('Date of birth is required'), findsOneWidget);
      expect(find.text('Expiry date is required'), findsOneWidget);
    });

    testWidgets('a valid licence code completes the entry', (tester) async {
      ScannedMRZ? scanned;
      await pump(tester, DocumentType.drivingLicence, onComplete: (m) => scanned = m);
      await tester.enterText(find.byType(TextFormField), 'D1NLD15094962111659VW87Z78NB84');
      await tester.pump();
      expect(find.text('30 / 30'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(scanned, isA<ScannedDriverLicenseMRZ>());
    });
  });

  testWidgets('guided settings switch turns the chip check on and off', (tester) async {
    _tallViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppBrand.cm.theme,
          home: SettingsScreen(onBackPressed: () {}, showOcrEngineForTesting: false),
        ),
      ),
    );
    final before = container.read(activeAuthenticationProvider);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(container.read(activeAuthenticationProvider), !before);
    expect(find.text('Text recognition'), findsNothing);
  });

  testWidgets('guided licence result shows the categories with readable dates', (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(
      _cm(
        DrivingLicenceDataScreen(
          drivingLicence: DrivingLicenceData(
            issuingMemberState: 'NLD',
            holderSurname: 'Eriksson',
            holderOtherName: 'Anna Maria',
            dateOfBirth: '12081974',
            placeOfBirth: 'Utopia',
            dateOfIssue: '01022024',
            dateOfExpiry: '01022034',
            issuingAuthority: 'RDW',
            documentNumber: '1234567890',
            photoImageData: Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2))),
            bapInputString: 'D1NLD11234567890ABCDEFGHIJKLM5',
            saiType: 'sai',
            aaPublicKey: null,
            categories: [DrivingLicenceCategory(category: 'B', dateOfIssue: '01022024', dateOfExpiry: '01022034')],
            photoImageType: ImageType.jpeg,
          ),
          drivingLicenceDataResult: RawDocumentData(dataGroups: const {}, efSod: '00'),
          onBackPressed: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Driving licence read'), findsOneWidget);
    expect(find.text('Anna Maria Eriksson'), findsOneWidget);
    expect(find.text('until 01/02/2034'), findsOneWidget);
    expect(find.textContaining('genuine'), findsNothing);
  });

  group('guided home', () {
    testWidgets('leads with scanning a QR code, not a document choice', (tester) async {
      _tallViewport(tester);
      var scans = 0;
      await tester.pumpWidget(
        _cm(
          DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (_) {},
            onSettingsPressed: () {},
            onScanQrPressed: () => scans++,
          ),
          overrides: [
            walletProvider.overrideWith(() => _SeededWallet([_walletCard('1', DocumentType.passport)])),
          ],
        ),
      );
      expect(find.text('Verify your identity with a QR code'), findsOneWidget);
      expect(find.text('Passport'), findsNothing);
      await tester.tap(find.text('Scan QR code'));
      expect(scans, 1);
    });

    testWidgets('offers to continue an accepted request instead of a new scan', (tester) async {
      _tallViewport(tester);
      var continued = 0;
      await tester.pumpWidget(
        _cm(
          DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (_) {},
            onSettingsPressed: () {},
            onScanQrPressed: () {},
            onContinueProofingSession: () => continued++,
          ),
          overrides: [activeProofingSessionProvider.overrideWith(_PinnedSession.new)],
        ),
      );
      expect(find.text('Scan QR code'), findsNothing);
      await tester.tap(find.text('Continue with CM.com'));
      expect(continued, 1);
    });
  });

  group('choose document', () {
    Future<void> pump(
      WidgetTester tester,
      List<WalletCard> saved, {
      ValueChanged<WalletCard>? onUseSaved,
      ValueChanged<DocumentType>? onAddNew,
    }) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        _cm(
          ChooseDocumentScreen(
            relyingParty: 'CM.com',
            savedDocuments: saved,
            onUseSaved: onUseSaved ?? (_) {},
            onAddNew: onAddNew ?? (_) {},
            onBack: () {},
          ),
        ),
      );
    }

    testWidgets('continues with the picked saved document', (tester) async {
      WalletCard? used;
      await pump(tester, [
        _walletCard('1', DocumentType.identityCard),
        _walletCard('2', DocumentType.drivingLicence),
      ], onUseSaved: (c) => used = c);
      expect(find.text('Continue with identity card'), findsOneWidget);
      await tester.tap(find.text('Driving licence').first);
      await tester.pump();
      await tester.tap(find.text('Continue with driving licence'));
      expect(used?.id, '2');
    });

    testWidgets('without saved documents only offers adding one', (tester) async {
      DocumentType? added;
      await pump(tester, const [], onAddNew: (t) => added = t);
      expect(find.text('SAVED ON THIS PHONE'), findsNothing);
      expect(find.textContaining('Continue with'), findsNothing);
      await tester.tap(find.text('Passport'));
      expect(added, DocumentType.passport);
    });
  });

  testWidgets('saved documents can be removed', (tester) async {
    _tallViewport(tester);
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(() => _SeededWallet([_walletCard('1', DocumentType.passport)])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppBrand.cm.theme,
          home: SavedDocumentsScreen(onBack: () {}, onScanQr: () {}),
        ),
      ),
    );
    expect(find.text('1 document on this phone'), findsOneWidget);
    await tester.tap(find.text('Remove from this phone'));
    await tester.pump();
    expect(container.read(walletProvider), isEmpty);
    expect(find.text('No documents on this phone'), findsOneWidget);
  });

  testWidgets('guided selfie check explains itself before the camera opens', (tester) async {
    _tallViewport(tester);
    final key = GlobalKey<FlutterFaceVerificationScreenState>();
    await tester.pumpWidget(
      _cm(
        FlutterFaceVerificationScreen.withEngine(
          key: key,
          engine: FaceVerificationEngine.withWorker(_IdleWorker()),
          nfcImageBytes: Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
          onBackPressed: () {},
          onVerified: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Take a quick selfie'), findsOneWidget);
    key.currentState!.debugSetActiveLiveness();
    await tester.pump();
    expect(find.text('Take a quick selfie'), findsNothing);
    expect(find.textContaining('No video is stored'), findsNothing);
  });

  testWidgets('guided result offers to save the document when sharing', (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(
      _cm(
        PassportDataScreen(
          document: _passport(),
          passportDataResult: RawDocumentData(dataGroups: const {}, efSod: '00'),
          onBackPressed: () {},
        ),
        overrides: [activeProofingSessionProvider.overrideWith(_PinnedSession.new)],
      ),
    );
    await tester.pump();
    expect(find.text('Share with CM.com'), findsOneWidget);
    expect(find.text('Save for next time'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  test('wallet cards made from a read document can be shared again', () {
    final raw = RawDocumentData(dataGroups: const {}, efSod: '00');
    final card = WalletCard.fromDocument(_passport(), DocumentType.passport, rawData: raw);
    expect(card.canBeReused, isTrue);
    expect(card.validUntil, _passport().mrz.dateOfExpiry);
    expect(WalletCard.fromDocument(_passport(), DocumentType.passport).canBeReused, isFalse);
  });

  test('the QR frame stays below the instructions on short screens', () {
    expect(guidedQrFrame(const Size(360, 640), minTop: 244).top, 244);
    expect(guidedQrFrame(const Size(390, 1200), minTop: 244).top, greaterThan(244));
  });

  testWidgets('accepting a request in the guided flow goes on to choosing a document', (tester) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppBrand.cm.theme,
          routerConfig: router,
        ),
      ),
    );
    router.push(
      proofingConsentPath,
      extra: {
        'ref': const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok'),
        'info': _session('CM.com'),
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/choose_document');
    expect(find.byType(ChooseDocumentScreen), findsOneWidget);
  });
  testWidgets('a saved document in a flow session is sent as the chip-read step', (tester) async {
    _tallViewport(tester);
    PackageInfo.setMockInitialValues(
      appName: 'idem',
      packageName: 'nl.idem',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final client = _RecordingProofingClient();
    final card = WalletCard.fromDocument(
      _passport(),
      DocumentType.passport,
      rawData: RawDocumentData(dataGroups: const {}, efSod: '00'),
    );
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith(() => _SeededWallet([card])),
          activeProofingSessionProvider.overrideWith(_PinnedFlowSession.new),
          proofingSessionClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppBrand.cm.theme,
          routerConfig: router,
        ),
      ),
    );
    router.go('/choose_document');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with passport'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(client.nfcSteps, hasLength(1));
    expect(client.nfcSteps.single.token, 'tok');
  });
}

/// Records chip-read step submissions and answers that the session is done.
class _RecordingProofingClient extends ProofingSessionClient {
  final nfcSteps = <ProofingSessionRef>[];

  @override
  Future<ProofingStepResponse> submitNfcStep(
    ProofingSessionRef ref, {
    required List<String> requestedAttributes,
    ProofingDocumentInfo? document,
    ProofingPhotoInfo? photo,
    required ProofingMrtdEvidence mrtdEvidence,
    ProofingDeviceInfo? device,
    bool faceStepFollows = false,
  }) async {
    nfcSteps.add(ref);
    return const ProofingStepResponse(status: 'ok', lifecycle: proofingLifecycleComplete);
  }
}

class _PinnedFlowSession extends ActiveProofingSessionNotifier {
  @override
  ActiveProofingSession? build() => ActiveProofingSession(
    ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok', deviceToken: 'dev'),
    info: ProofingSessionInfo(
      id: 'session-1',
      relyingParty: 'CM.com',
      requestedAttributes: const ['dg1', 'dg2'],
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      steps: const [stepDocumentCapture, stepNfcRead],
    ),
    openedAt: DateTime.now(),
  );
}

class _PinnedSession extends ActiveProofingSessionNotifier {
  @override
  ActiveProofingSession? build() => ActiveProofingSession(
    ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok'),
    info: _session('CM.com'),
    openedAt: DateTime.now(),
  );
}

/// A face engine worker that never reports anything.
class _IdleWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _frames.close();
  }

  @override
  Future<void> startSession() async {}
  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> processCameraFrame(CameraImage c, int r) async {}
  @override
  Future<img.Image?> detectAndCropEncoded(Uint8List e) async => null;
  @override
  Future<void> prepareNfcFace(img.Image f) async {}
  @override
  Future<void> storeConsistencySelfie(img.Image s) async {}
  @override
  Future<double> checkConsistencySelfie(img.Image s) async => 1.0;
  @override
  Future<WorkerMatchResult> matchSelfie(img.Image s) async => const WorkerMatchResult(score: 0.9);
  @override
  Future<WorkerPassiveResult> getPassiveResult() async => const WorkerPassiveResult(
    antiSpoofScore: 0.9,
    antiSpoofPassed: true,
    rppgHr: 70.0,
    rppgPassed: true,
    rppgSampleCount: 30,
    rppgDurationMs: 3000,
  );
  @override
  Stream<WorkerFrameResult> get debugFrames => _frames.stream;
  @override
  int get debugSessionId => 0;
  @override
  Future<void> debugWaitPipelineIdle() async {}
  @override
  Future<void> debugWaitPassiveIdle() async {}
  @override
  void debugEmitFrameResult(WorkerFrameResult r) {}
  @override
  void debugEmitFrameError(Object e) {}
}
