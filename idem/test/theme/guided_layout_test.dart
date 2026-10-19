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
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/routing.dart';
import 'package:idem/widgets/pages/choose_document_screen.dart';
import 'package:idem/widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/face_verification_screen.dart';
import 'package:idem/widgets/pages/qr_scanner_screen.dart';
import 'package:idem/widgets/pages/saved_documents_screen.dart';
import 'package:face_verification/face_verification.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:idem/widgets/pages/driving_licence_data_screen.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
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

Widget _app(Widget home, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, theme: appTheme(), home: home),
);

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('the app theme uses the guided layout; a theme without a brand the classic one', () {
    expect(appTheme().extension<BrandTheme>()!.guided, isNotNull);
    expect(BrandTheme.idem.guided, isNull);
  });

  testWidgets('the guided manual entry counts the flow\'s steps, not a fixed three', (tester) async {
    await tester.pumpWidget(
      _app(
        GuidedManualEntryScreen(
          documentType: DocumentType.passport,
          onBack: () {},
          onManualEntryComplete: (_) {},
          stepNumber: 1,
          totalSteps: 2,
        ),
      ),
    );
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.descendant(of: find.byType(GuidedStepBar), matching: find.byType(Expanded)), findsNWidgets(2));
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

  testWidgets('guided scan card opens to the tip and manual entry, and closes again', (tester) async {
    var manualEntries = 0;
    await tester.pumpWidget(
      _app(
        ScannerWrapper(
          documentType: DocumentType.passport,
          onMrzScanned: (_, [_]) {},
          onManualEntry: () => manualEntries++,
          onBack: () {},
          scannerBuilder: ({required documentType, required scanPicture, required onSuccess}) => const SizedBox(),
        ),
      ),
    );
    const title = 'Place the photo page in the frame';
    expect(find.text(title), findsOneWidget);
    expect(find.text('Enter details manually'), findsNothing);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter details manually'));
    expect(manualEntries, 1);

    await tester.fling(find.text(title), const Offset(0, 200), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Enter details manually'), findsNothing);

    await tester.fling(find.text(title), const Offset(0, -200), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Enter details manually'), findsOneWidget);
  });

  testWidgets('guided NFC reading lists what has been read so far', (tester) async {
    _tallViewport(tester);
    _FakeReader.initialState = DocumentReaderReadingDataGroup(dataGroup: 'DG2', progress: 0.5);
    await tester.pumpWidget(
      _app(
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
    expect(find.text('Reading the chip securely'), findsOneWidget);
  });

  group('guided result', () {
    Future<void> pump(
      WidgetTester tester, {
      String? submittedTo,
      PendingStep pendingStep = PendingStep.none,
      Future<bool> Function()? onShare,
    }) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        _app(
          PassportDataScreen(
            document: _passport(),
            passportDataResult: RawDocumentData(dataGroups: const {}, efSod: '00'),
            onBackPressed: () {},
            submittedTo: submittedTo,
            pendingStep: pendingStep,
            onShare: onShare,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('confirms what was read, and never claims the chip is genuine', (tester) async {
      await pump(tester);
      expect(find.text('Document read'), findsOneWidget);
      expect(find.text('Anna Maria Eriksson'), findsOneWidget);
      expect(find.text('Add to wallet'), findsOneWidget);
      expect(find.textContaining('genuine'), findsNothing);
    });

    testWidgets('a session that already got every step offers to keep the document', (tester) async {
      await pump(tester, submittedTo: 'Acme Bank');
      expect(find.text('Sent to Acme Bank'), findsOneWidget);
      expect(find.text('Save for next time'), findsOneWidget);
      expect(find.text('Add to wallet'), findsNothing);
    });

    for (final shared in [true, false]) {
      testWidgets('a read document finishes the session from here, and saved for next time only once shared: $shared', (
        tester,
      ) async {
        var shares = 0;
        await pump(
          tester,
          submittedTo: 'Acme Bank',
          pendingStep: PendingStep.share,
          onShare: () async {
            shares++;
            return shared;
          },
        );
        expect(find.text('Document read'), findsOneWidget);
        expect(find.text('Done'), findsNothing);

        await tester.tap(find.text('Save for next time'));
        await tester.pump();
        await tester.tap(find.text('Finish with Acme Bank'));
        await tester.pump();

        expect(shares, 1);
        final container = ProviderScope.containerOf(tester.element(find.byType(PassportDataScreen)));
        expect(container.read(walletProvider), hasLength(shared ? 1 : 0));
      });
    }
  });

  group('guided consent', () {
    testWidgets('shows the requester\'s initial and name', (tester) async {
      _tallViewport(tester);
      var consented = 0;
      var declined = 0;
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _session('Acme Bank'),
            onConsent: () => consented++,
            onDecline: () => declined++,
          ),
        ),
      );
      expect(find.text('Acme Bank wants to verify your identity'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Decline'));
      expect((consented, declined), (1, 1));
    });

    testWidgets('a theme without a brand keeps the classic consent screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(),
          home: ProofingSessionConsentScreen(info: _session('Acme Bank'), onConsent: () {}, onDecline: () {}),
        ),
      );
      expect(find.text('Identity proofing request'), findsOneWidget);
    });
  });

  group('guided manual entry', () {
    Future<void> pump(WidgetTester tester, DocumentType type, {ValueChanged<ScannedMRZ>? onComplete}) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        _app(GuidedManualEntryScreen(documentType: type, onBack: () {}, onManualEntryComplete: onComplete ?? (_) {})),
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
          theme: appTheme(),
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
      _app(
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
        _app(
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
        _app(
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
      await tester.tap(find.text('Continue with Acme Bank'));
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
        _app(
          ChooseDocumentScreen(
            relyingParty: 'Acme Bank',
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
          theme: appTheme(),
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
      _app(
        FlutterFaceVerificationScreen(
          key: key,
          testEngine: FaceVerificationEngine.withWorker(_IdleWorker()),
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

  testWidgets('guided selfie check waits for Start instead of starting once ready', (tester) async {
    _tallViewport(tester);
    Widget screen(GlobalKey<FlutterFaceVerificationScreenState> key) => FlutterFaceVerificationScreen(
      key: key,
      testEngine: FaceVerificationEngine.withWorker(_IdleWorker()),
      nfcImageBytes: Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
      onBackPressed: () {},
      onVerified: (_) {},
    );
    final guided = GlobalKey<FlutterFaceVerificationScreenState>();
    await tester.pumpWidget(_app(screen(guided)));
    await tester.pump();
    expect(guided.currentState!.debugAutoStarts, isFalse);

    // The classic layout has no intro, so it still starts by itself.
    final classic = GlobalKey<FlutterFaceVerificationScreenState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen(classic),
      ),
    );
    await tester.pump();
    expect(classic.currentState!.debugAutoStarts, isTrue);
  });

  test('wallet cards made from a read document can be shared again', () {
    final raw = RawDocumentData(dataGroups: const {}, efSod: '00');
    final card = WalletCard.fromDocument(_passport(), DocumentType.passport, rawData: raw);
    expect(card.canBeReused, isTrue);
    expect(card.validUntil, _passport().mrz.dateOfExpiry);
    expect(WalletCard.fromDocument(_passport(), DocumentType.passport).canBeReused, isFalse);
  });

  test('the QR frame always fits in the area left between the instructions and the bottom line', () {
    for (final area in const [Size(360, 420), Size(390, 500), Size(360, 200)]) {
      final frame = guidedQrFrame(area);
      expect(frame.top, greaterThanOrEqualTo(24), reason: '$area');
      expect(frame.bottom, lessThanOrEqualTo(area.height - 24), reason: '$area');
      expect(frame.width, frame.height);
    }
  });

  for (final screen in const [Size(360, 640), Size(390, 1600)]) {
    testWidgets(
      'the QR scrim covers the whole ${screen.width.toInt()}×${screen.height.toInt()} screen without the text touching the frame',
      (tester) async {
        // The test font is far wider than Nunito, so on the short screen the
        // instructions wrap onto many lines: the same squeeze as a large system
        // font size. On the tall one they need less than their share of the height.
        tester.view.physicalSize = screen;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(QrScannerScreen(onScanned: (_) {}, onBack: () {})));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final instructions = tester.getRect(find.byKey(guidedQrInstructionsKey));
        final frameArea = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_GuidedQrFramePainter',
          ),
        );
        final bottomBand = tester.getRect(
          find.ancestor(of: find.textContaining('Nothing is shared'), matching: find.byType(ColoredBox)).first,
        );
        expect(frameArea.top, instructions.bottom);
        expect(frameArea.bottom, bottomBand.top);
        expect(bottomBand.bottom, screen.height, reason: 'the scrim must reach the bottom edge');
        expect(frameArea.height, greaterThan(200));
      },
    );
  }

  testWidgets('accepting a request in the guided flow goes on to choosing a document', (tester) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: appTheme(),
          routerConfig: router,
        ),
      ),
    );
    router.push(
      proofingConsentPath,
      extra: {
        'ref': const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok'),
        'info': _session('Acme Bank'),
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
          theme: appTheme(),
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
    PhotoInclusion photoInclusion = PhotoInclusion.whenRequested,
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
      relyingParty: 'Acme Bank',
      requestedAttributes: const ['dg1', 'dg2'],
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      steps: const [stepDocumentCapture, stepNfcRead],
    ),
  );
}

class _PinnedSession extends ActiveProofingSessionNotifier {
  @override
  ActiveProofingSession? build() => ActiveProofingSession(
    ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok'),
    info: _session('Acme Bank'),
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
