import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:face_verification/face_verification.dart';
import 'package:idem/widgets/pages/face_verification_entry_screen.dart';
import 'package:idem/routing.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/widgets/pages/document_capture_only_result_screen.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/driving_licence_data_screen.dart';
import 'package:idem/widgets/pages/passport_data_screen.dart';
import 'package:idem/widgets/pages/qr_scanner_screen.dart';
import 'package:idem/widgets/pages/scanner_wrapper.dart';
import 'package:idem/widgets/pages/manual_entry_route_params.dart';
import 'package:idem/widgets/pages/nfc_reading_screen.dart';
import 'package:idem/widgets/pages/proofing_session_consent_screen.dart';
import 'package:idem/widgets/pages/settings_screen.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_watcher.dart';

class _FakeScanner extends StatelessWidget {
  const _FakeScanner({required this.documentType, required this.onSuccess});

  final DocumentType documentType;
  final ValueChanged<ScannedMRZ> onSuccess;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => onSuccess(_scannedPassport(documentType)),
      child: Text('fake route scanner ${documentType.name}'),
    );
  }
}

class _FakeWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;

  @override
  Stream<WorkerFrameResult> get debugFrames => _frames.stream;

  @override
  int get debugSessionId => 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async => _frames.close();

  @override
  Future<void> startSession() async {}

  @override
  Future<void> stop() async {}

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
  Future<void> debugWaitPipelineIdle() async {}

  @override
  Future<void> debugWaitPassiveIdle() async {}

  @override
  void debugEmitFrameResult(WorkerFrameResult r) {}

  @override
  void debugEmitFrameError(Object e) {}
}

Uint8List _jpeg() {
  return Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));
}

RawDocumentData _rawDocument() {
  return RawDocumentData(dataGroups: const {}, efSod: '00');
}

ScannedPassportMRZ _scannedPassport(DocumentType documentType) {
  return ScannedPassportMRZ(
    documentNumber: 'L898902C3',
    countryCode: 'UTO',
    dateOfBirth: DateTime(1974, 8, 12),
    dateOfExpiry: DateTime(2030, 1, 1),
    documentType: documentType,
  );
}

PassportData _passportData() {
  return PassportData(
    mrz: PassportMRZ(
      Uint8List.fromList(
        'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
      ),
    ),
    photoImageData: _jpeg(),
    photoImageType: ImageType.jpeg,
    photoImageWidth: 2,
    photoImageHeight: 2,
    dateOfIssue: DateTime(2024, 2, 1),
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

ScannerWidgetBuilder _scannerBuilder() {
  return ({required documentType, required onSuccess}) {
    return _FakeScanner(documentType: documentType, onSuccess: onSuccess);
  };
}

Widget _routerApp(GoRouter router) {
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

class _RouteExtensionHarness extends StatelessWidget {
  const _RouteExtensionHarness();

  @override
  Widget build(BuildContext context) {
    final scannedMrz = _scannedPassport(DocumentType.passport);

    return Column(
      children: [
        TextButton(
          onPressed: () => context.pushMrzReaderScreen(MrzReaderRouteParams(documentType: DocumentType.identityCard)),
          child: const Text('push mrz reader'),
        ),
        TextButton(
          onPressed: () =>
              context.pushManualEntryScreen(ManualEntryRouteParams(documentType: DocumentType.drivingLicence)),
          child: const Text('push manual entry'),
        ),
        TextButton(
          onPressed: () => context.pushNfcReadingScreen(
            NfcReadingRouteParams(scannedMRZ: scannedMrz, documentType: DocumentType.passport),
          ),
          child: const Text('push nfc reading'),
        ),
        TextButton(
          onPressed: () => context.pushFaceVerificationScreen(
            Uint8List.fromList(<int>[1, 2, 3]),
            issueDate: DateTime(2024, 2, 1),
            document: _passportData(),
            result: _rawDocument(),
            documentType: DocumentType.passport,
          ),
          child: const Text('push face verification'),
        ),
      ],
    );
  }
}

const _faceSteps = [stepFaceVerification, stepSelfie, stepLiveness, stepFaceMatch];

/// Answers the step endpoints the way identity-proofing-service does for a
/// flow of [steps]: each submission is recorded and the response names the
/// first step still without a result (the server's currentStep), and
/// readyToSubmit once there is none. The session only gets its outcome
/// (COMPLETE) from `POST .../submit` - so the app has something real to
/// follow.
Future<http.Response> Function(http.Request) _flowServer(List<String> steps) {
  final done = <String>{};
  var submitted = false;
  return (request) async {
    final path = request.url.path;
    List<String> remaining() => steps.where((step) => !done.contains(step)).toList();
    if (request.method == 'POST' && path.endsWith('/submit')) {
      if (remaining().isNotEmpty) return http.Response(json.encode({'code': 'steps_incomplete'}), 409);
      final alreadyRecorded = submitted;
      submitted = true;
      return http.Response(
        json.encode({
          'status': 'approved',
          'completedSteps': done.toList(),
          'currentStep': '',
          'lifecycle': 'COMPLETE',
          'readyToSubmit': false,
          'alreadyRecorded': alreadyRecorded,
        }),
        200,
      );
    }
    if (request.method != 'POST' || !path.contains('/steps/') || path.endsWith('/start')) {
      return http.Response('{}', 200);
    }
    if (path.endsWith('/steps/document_capture')) done.add(stepDocumentCapture);
    if (path.endsWith('/steps/nfc')) done.addAll([stepNfcRead, stepDocumentCapture]);
    if (path.endsWith('/steps/selfie')) done.addAll(_faceSteps);
    final left = remaining();
    return http.Response(
      json.encode({
        'status': 'in_progress',
        'completedSteps': done.toList(),
        'currentStep': left.isEmpty ? '' : left.first,
        'lifecycle': 'ACTIVE',
        'readyToSubmit': left.isEmpty,
      }),
      200,
    );
  };
}

/// Lets a step submission (progress dialog, request, dialog closing) run
/// to completion.
Future<void> _pumpStepSubmission(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Idem',
      packageName: 'foundation.privacybydesign.idem',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('routeObserver', () {
    test('is a RouteObserver instance', () {
      expect(routeObserver, isA<RouteObserver<ModalRoute<void>>>());
    });
  });

  group('createRouter', () {
    testWidgets('returns a GoRouter with /select_doc_type as initial route', (tester) async {
      final router = createRouter();
      addTearDown(router.dispose);
      expect(router, isA<GoRouter>());
      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');
    });

    testWidgets('builds the initial document selection route', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      await tester.pump();

      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('Identity Card'), findsOneWidget);
      expect(find.text('Driving Licence'), findsOneWidget);
    });

    testWidgets('builds MRZ reader route with injected scanner', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      final params = MrzReaderRouteParams(documentType: DocumentType.identityCard);
      final uri = Uri(path: '/mrz_reader', queryParameters: params.toQueryParams());

      await tester.pumpWidget(_routerApp(router));
      router.go(uri.toString());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ScannerWrapper), findsOneWidget);
      expect(find.text('1 of 4 · Scan ${DocumentType.identityCard.displayName}'), findsOneWidget);
      expect(find.text('fake route scanner ${DocumentType.identityCard.name}'), findsOneWidget);
    });

    testWidgets('document selection callback navigates to MRZ reader', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      tester
          .widget<DocumentTypeSelectionScreen>(find.byType(DocumentTypeSelectionScreen))
          .onDocumentTypeSelected(DocumentType.identityCard);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ScannerWrapper), findsOneWidget);
    });

    testWidgets('settings callback navigates to the settings screen and back', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      tester.widget<DocumentTypeSelectionScreen>(find.byType(DocumentTypeSelectionScreen)).onSettingsPressed();
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      tester.widget<SettingsScreen>(find.byType(SettingsScreen)).onBackPressed();
      await tester.pumpAndSettle();

      expect(find.byType(DocumentTypeSelectionScreen), findsOneWidget);
    });

    testWidgets('MRZ reader callbacks navigate to NFC reading and manual entry', (tester) async {
      // NFC success now jumps straight into the on-device camera screen (no
      // more method-picker buffer in between), so a fake engine must be
      // injected here to avoid bootstrapping a real camera/native worker.
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      router.go(
        Uri(
          path: '/mrz_reader',
          queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
        ).toString(),
      );
      await tester.pump();
      await tester.pump();

      tester.widget<ScannerWrapper>(find.byType(ScannerWrapper)).onMrzScanned(_scannedPassport(DocumentType.passport));
      await tester.pump();
      await tester.pump();
      expect(find.byType(NfcReadingScreen), findsOneWidget);

      tester
          .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
          .last
          .onSuccess(_passportData(), _rawDocument());
      await tester.pump();
      await tester.pump();
      // NFC success jumps straight into face verification; the document data
      // screen is shown afterwards (see the 'result route callbacks ...' test).
      expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);

      router.go(
        Uri(
          path: '/mrz_reader',
          queryParameters: MrzReaderRouteParams(documentType: DocumentType.drivingLicence).toQueryParams(),
        ).toString(),
      );
      await tester.pump();
      await tester.pump();

      tester.widgetList<ScannerWrapper>(find.byType(ScannerWrapper)).last.onManualEntry();
      await tester.pump();
      await tester.pump();
      expect(find.byType(ManualEntryScreen), findsOneWidget);
    });

    testWidgets('a successful driving licence NFC read jumps into face verification with its own photo', (
      tester,
    ) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      router.go(
        Uri(
          path: '/mrz_reader',
          queryParameters: MrzReaderRouteParams(documentType: DocumentType.drivingLicence).toQueryParams(),
        ).toString(),
      );
      await tester.pump();
      await tester.pump();

      tester
          .widget<ScannerWrapper>(find.byType(ScannerWrapper))
          .onMrzScanned(
            ScannedDriverLicenseMRZ(
              documentNumber: '1234567890',
              countryCode: 'NLD',
              version: '1',
              randomData: 'RANDOM123',
              configuration: 'CONFIG',
            ),
          );
      await tester.pump();
      await tester.pump();
      expect(find.byType(NfcReadingScreen), findsOneWidget);

      tester
          .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
          .last
          .onSuccess(_drivingLicenceData(), _rawDocument());
      await tester.pump();
      await tester.pump();

      expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);
    });

    testWidgets('NFC success skips face verification and submits the session straight away when the '
        "session's steps ask for neither selfie, liveness, nor face_match", (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      var submits = 0;
      // Outside the client factory: runWithClient makes a client per request.
      final server = _flowServer(const [stepDocumentCapture, stepNfcRead]);

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_routerApp(router));
          await tester.pump();

          final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
          container
              .read(activeProofingSessionProvider.notifier)
              .set(
                ActiveProofingSession(
                  ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                  info: ProofingSessionInfo(
                    id: 'sess1',
                    relyingParty: 'acme-tenant',
                    requestedAttributes: const [],
                    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                    steps: const [stepDocumentCapture, stepNfcRead],
                  ),
                  openedAt: DateTime.now(),
                ),
              );

          router.go(
            Uri(
              path: '/mrz_reader',
              queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
            ).toString(),
          );
          await tester.pump();
          await tester.pump();

          tester
              .widget<ScannerWrapper>(find.byType(ScannerWrapper))
              .onMrzScanned(_scannedPassport(DocumentType.passport));
          await tester.pump();
          await tester.pump();
          expect(find.byType(NfcReadingScreen), findsOneWidget);

          final events = <ProofingSessionEvent>[];
          final sub = container.read(proofingSessionCoordinatorProvider).events.listen(events.add);
          addTearDown(sub.cancel);
          tester
              .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
              .last
              .onSuccess(_passportData(), _rawDocument());
          await _pumpStepSubmission(tester);
          await _pumpStepSubmission(tester);

          // The chip read was the last step, so it also submitted the
          // session: no face verification, no Submit button to tap.
          expect(find.byType(FaceVerificationEntryScreen), findsNothing);
          expect(submits, 1);
          expect(events.single, isA<ProofingSessionCompleted>());
        },
        () => MockClient((request) {
          if (request.url.path.endsWith('/submit')) submits++;
          return server(request);
        }),
      );
    });

    testWidgets('NFC success still runs face verification when the session steps ask for just one of '
        'selfie/liveness/face_match', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await http.runWithClient(() async {
        await tester.pumpWidget(_routerApp(router));
        await tester.pump();

        final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
        container
            .read(activeProofingSessionProvider.notifier)
            .set(
              ActiveProofingSession(
                ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                info: ProofingSessionInfo(
                  id: 'sess1',
                  relyingParty: 'acme-tenant',
                  requestedAttributes: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                  steps: const [stepDocumentCapture, stepNfcRead, stepLiveness],
                  selfieLocation: 'native',
                ),
                openedAt: DateTime.now(),
              ),
            );

        router.go(
          Uri(
            path: '/mrz_reader',
            queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
          ).toString(),
        );
        await tester.pump();
        await tester.pump();

        tester
            .widget<ScannerWrapper>(find.byType(ScannerWrapper))
            .onMrzScanned(_scannedPassport(DocumentType.passport));
        await tester.pump();
        await tester.pump();

        tester
            .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
            .last
            .onSuccess(_passportData(), _rawDocument());
        await _pumpStepSubmission(tester);

        expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);
      }, () => MockClient(_flowServer(const [stepDocumentCapture, stepNfcRead, stepLiveness])));
    });

    testWidgets('NFC success also runs face verification when the session steps ask for the aggregate '
        '"face_verification" step (not just the granular selfie/liveness/face_match names)', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await http.runWithClient(() async {
        await tester.pumpWidget(_routerApp(router));
        await tester.pump();

        final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
        container
            .read(activeProofingSessionProvider.notifier)
            .set(
              ActiveProofingSession(
                ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                info: ProofingSessionInfo(
                  id: 'sess1',
                  relyingParty: 'acme-tenant',
                  requestedAttributes: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                  steps: const [stepDocumentCapture, stepNfcRead, stepFaceVerification],
                  selfieLocation: 'native',
                ),
                openedAt: DateTime.now(),
              ),
            );

        router.go(
          Uri(
            path: '/mrz_reader',
            queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
          ).toString(),
        );
        await tester.pump();
        await tester.pump();

        tester
            .widget<ScannerWrapper>(find.byType(ScannerWrapper))
            .onMrzScanned(_scannedPassport(DocumentType.passport));
        await tester.pump();
        await tester.pump();

        tester
            .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
            .last
            .onSuccess(_passportData(), _rawDocument());
        await _pumpStepSubmission(tester);

        expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);
      }, () => MockClient(_flowServer(const [stepDocumentCapture, stepNfcRead, stepFaceVerification])));
    });

    testWidgets('NFC success skips its own face verification and goes straight to the result route when '
        'selfieLocation is "browser", even though the session steps do ask for a face stage', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await http.runWithClient(() async {
        await tester.pumpWidget(_routerApp(router));
        await tester.pump();

        final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
        container
            .read(activeProofingSessionProvider.notifier)
            .set(
              ActiveProofingSession(
                ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                info: ProofingSessionInfo(
                  id: 'sess1',
                  relyingParty: 'acme-tenant',
                  requestedAttributes: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                  steps: const [stepDocumentCapture, stepNfcRead, stepFaceVerification],
                  selfieLocation: 'browser',
                ),
                openedAt: DateTime.now(),
              ),
            );

        router.go(
          Uri(
            path: '/mrz_reader',
            queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
          ).toString(),
        );
        await tester.pump();
        await tester.pump();

        tester
            .widget<ScannerWrapper>(find.byType(ScannerWrapper))
            .onMrzScanned(_scannedPassport(DocumentType.passport));
        await tester.pump();
        await tester.pump();
        expect(find.byType(NfcReadingScreen), findsOneWidget);

        tester
            .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
            .last
            .onSuccess(_passportData(), _rawDocument());
        await _pumpStepSubmission(tester);

        expect(find.byType(FaceVerificationEntryScreen), findsNothing);
        expect(find.byType(PassportDataScreen), findsOneWidget);
        // 2 of 2: face_verification is deferred to the browser, so it never
        // occupies a step slot of THIS APP's own sequence (document capture,
        // nfc read), and the confirmation reuses the last step's number -
        // see FlowStepPlan.fromSteps.
        final resultScreen = tester.widget<PassportDataScreen>(find.byType(PassportDataScreen));
        expect(resultScreen.totalSteps, 2);
        expect(resultScreen.stepNumber, 2);
      }, () => MockClient(_flowServer(const [stepDocumentCapture, stepNfcRead, stepFaceVerification])));
    });

    testWidgets('MRZ scan skips NFC reading entirely and submits the session when steps is just document_capture', (
      tester,
    ) async {
      final documentStepBodies = <Map<String, dynamic>>[];
      var submitRequests = 0;
      final server = _flowServer(const [stepDocumentCapture]);
      await http.runWithClient(
        () async {
          final router = createRouter(scannerBuilder: _scannerBuilder());
          addTearDown(router.dispose);

          await tester.pumpWidget(_routerApp(router));
          await tester.pump();

          final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
          container
              .read(activeProofingSessionProvider.notifier)
              .set(
                ActiveProofingSession(
                  ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                  info: ProofingSessionInfo(
                    id: 'sess1',
                    relyingParty: 'acme-tenant',
                    requestedAttributes: const [],
                    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                    steps: const [stepDocumentCapture],
                  ),
                  openedAt: DateTime.now(),
                ),
              );

          router.go(
            Uri(
              path: '/mrz_reader',
              queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
            ).toString(),
          );
          await tester.pump();
          await tester.pump();

          final events = <ProofingSessionEvent>[];
          final sub = container.read(proofingSessionCoordinatorProvider).events.listen(events.add);
          addTearDown(sub.cancel);
          tester
              .widget<ScannerWrapper>(find.byType(ScannerWrapper))
              .onMrzScanned(_scannedPassport(DocumentType.passport));
          await _pumpStepSubmission(tester);
          await _pumpStepSubmission(tester);

          // The scan itself was the whole flow: sent as its own step, which
          // as the last step also submits the session - ending the
          // verification (main.dart then tells the user it's done).
          expect(documentStepBodies, hasLength(1));
          expect((documentStepBodies.single['document'] as Map)['number'], isNotNull);
          expect(find.byType(NfcReadingScreen), findsNothing);
          expect(find.byType(FaceVerificationEntryScreen), findsNothing);
          expect(submitRequests, 1);
          expect(events.single, isA<ProofingSessionCompleted>());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/steps/document_capture')) {
            documentStepBodies.add(json.decode(request.body) as Map<String, dynamic>);
          }
          if (request.url.path.endsWith('/submit')) submitRequests++;
          return server(request);
        }),
      );
    });

    testWidgets('MRZ scan skips NFC reading but still runs face verification, sourcing the comparison photo from '
        'referencePhoto', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await http.runWithClient(() async {
        final referencePhotoBytes = Uint8List.fromList([1, 2, 3, 4]);

        await tester.pumpWidget(_routerApp(router));
        await tester.pump();

        final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
        container
            .read(activeProofingSessionProvider.notifier)
            .set(
              ActiveProofingSession(
                ref: const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
                info: ProofingSessionInfo(
                  id: 'sess1',
                  relyingParty: 'acme-tenant',
                  requestedAttributes: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                  steps: const [stepDocumentCapture, stepFaceMatch],
                  // The flow puts the face step on this app, so it runs here.
                  selfieLocation: 'native',
                  referencePhoto: ProofingPhotoInfo(
                    imageBase64: base64Encode(referencePhotoBytes),
                    mimeType: 'image/jpeg',
                  ),
                ),
                openedAt: DateTime.now(),
              ),
            );

        router.go(
          Uri(
            path: '/mrz_reader',
            queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
          ).toString(),
        );
        await tester.pump();
        await tester.pump();

        tester
            .widget<ScannerWrapper>(find.byType(ScannerWrapper))
            .onMrzScanned(_scannedPassport(DocumentType.passport));
        await _pumpStepSubmission(tester);

        expect(find.byType(NfcReadingScreen), findsNothing);
        expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);
        expect(
          tester.widget<FaceVerificationEntryScreen>(find.byType(FaceVerificationEntryScreen)).nfcImageBytes,
          referencePhotoBytes,
        );
      }, () => MockClient(_flowServer(const [stepDocumentCapture, stepFaceMatch])));
    });

    testWidgets('builds result route for passport and driving licence documents', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      router.go(
        '/result',
        extra: {'document': _passportData(), 'result': _rawDocument(), 'document_type': DocumentType.passport},
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(PassportDataScreen), findsOneWidget);

      router.go(
        '/result',
        extra: {
          'document': _drivingLicenceData(),
          'result': _rawDocument(),
          'document_type': DocumentType.drivingLicence,
        },
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(DrivingLicenceDataScreen), findsOneWidget);
    });

    testWidgets('result route back callbacks navigate to document selection for passport and driving licence', (
      tester,
    ) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      router.go(
        '/result',
        extra: {'document': _passportData(), 'result': _rawDocument(), 'document_type': DocumentType.passport},
      );
      await tester.pump();
      await tester.pump();

      tester.widgetList<PassportDataScreen>(find.byType(PassportDataScreen)).last.onBackPressed();
      await tester.pump();
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');

      router.go(
        '/result',
        extra: {
          'document': _drivingLicenceData(),
          'result': _rawDocument(),
          'document_type': DocumentType.drivingLicence,
        },
      );
      await tester.pump();
      await tester.pump();
      tester.widgetList<DrivingLicenceDataScreen>(find.byType(DrivingLicenceDataScreen)).last.onBackPressed();
      await tester.pump();
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');
    });

    testWidgets('builds face verification route with injected engine', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);
      final issueDate = DateTime(2024, 2, 1);

      await tester.pumpWidget(_routerApp(router));
      router.go(
        '/face_verification',
        extra: {
          'nfcImageBytes': Uint8List.fromList([1]),
          'issueDate': issueDate,
          'document': _passportData(),
          'result': _rawDocument(),
          'documentType': DocumentType.passport,
        },
      );
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<FaceVerificationEntryScreen>(find.byType(FaceVerificationEntryScreen));
      expect(screen.photoIssueDate, issueDate);
      expect(screen.nfcImageBytes, Uint8List.fromList([1]));
    });

    testWidgets('BuildContext route extensions push expected pages', (tester) async {
      Map<String, dynamic>? faceExtra;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, unused) => const Scaffold(body: _RouteExtensionHarness()),
          ),
          GoRoute(
            path: '/mrz_reader',
            builder: (_, unused) => const Scaffold(body: SizedBox(key: Key('mrz_reader_page'))),
          ),
          GoRoute(
            path: '/manual_entry',
            builder: (_, unused) => const Scaffold(body: SizedBox(key: Key('manual_entry_page'))),
          ),
          GoRoute(
            path: '/nfc_reading',
            builder: (_, unused) => const Scaffold(body: SizedBox(key: Key('nfc_reading_page'))),
          ),
          GoRoute(
            path: '/face_verification',
            builder: (_, state) {
              faceExtra = state.extra as Map<String, dynamic>;
              return const Scaffold(body: SizedBox(key: Key('face_verification_page')));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'push mrz reader'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mrz_reader_page')), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'push manual entry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual_entry_page')), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'push nfc reading'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nfc_reading_page')), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'push face verification'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('face_verification_page')), findsOneWidget);
      expect(faceExtra, isNotNull);
      expect(faceExtra!['nfcImageBytes'], Uint8List.fromList(<int>[1, 2, 3]));
      expect(faceExtra!['issueDate'], DateTime(2024, 2, 1));
    });

    testWidgets('manual entry callback navigates to NFC reading with the selected document type', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      final params = ManualEntryRouteParams(documentType: DocumentType.passport);
      final uri = Uri(path: '/manual_entry', queryParameters: params.toQueryParams());

      await tester.pumpWidget(_routerApp(router));
      router.go(uri.toString());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ManualEntryScreen), findsOneWidget);

      tester
          .widget<ManualEntryScreen>(find.byType(ManualEntryScreen))
          .onManualEntryComplete(_scannedPassport(DocumentType.passport));
      await tester.pump();
      await tester.pump();

      expect(find.byType(NfcReadingScreen), findsOneWidget);
    });

    testWidgets('proofing consent route: Continue pins the session and returns to document selection', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      final sessionRef = const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok');
      final info = ProofingSessionInfo(
        id: 'sess1',
        relyingParty: 'acme-tenant',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(_routerApp(router));
      router.push('/proofing_consent', extra: {'ref': sessionRef, 'info': info});
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProofingSessionConsentScreen), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(ProofingSessionConsentScreen)));
      expect(container.read(activeProofingSessionProvider), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');
      final pinned = container.read(activeProofingSessionProvider);
      expect(pinned, isNotNull);
      expect(pinned!.ref.token, 'tok');
      expect(pinned.info.relyingParty, 'acme-tenant');
    });

    testWidgets('proofing consent route: Continue on a document_capture-less flow skips straight to face '
        'verification with the referencePhoto', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);
      final sessionRef = const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok');
      final referencePhotoBytes = Uint8List.fromList([9, 8, 7, 6]);
      final info = ProofingSessionInfo(
        id: 'sess1',
        relyingParty: 'acme-tenant',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        steps: const ['selfie', 'face_match'],
        referencePhoto: ProofingPhotoInfo(imageBase64: base64Encode(referencePhotoBytes), mimeType: 'image/jpeg'),
      );

      await tester.pumpWidget(_routerApp(router));
      router.push('/proofing_consent', extra: {'ref': sessionRef, 'info': info});
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FaceVerificationEntryScreen), findsOneWidget);
      expect(
        tester.widget<FaceVerificationEntryScreen>(find.byType(FaceVerificationEntryScreen)).nfcImageBytes,
        referencePhotoBytes,
      );
    });

    testWidgets(
      'proofing consent route: Continue on a flow with no capture steps at all auto-submits an empty result',
      (tester) async {
        await http.runWithClient(() async {
          final router = createRouter(scannerBuilder: _scannerBuilder());
          addTearDown(router.dispose);
          final sessionRef = const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok');
          final info = ProofingSessionInfo(
            id: 'sess1',
            relyingParty: 'acme-tenant',
            requestedAttributes: const [],
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            steps: const [],
          );

          await tester.pumpWidget(_routerApp(router));
          router.push('/proofing_consent', extra: {'ref': sessionRef, 'info': info});
          await tester.pump();
          await tester.pump();

          await tester.tap(find.text('Continue'));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(DocumentCaptureOnlyResultScreen), findsOneWidget);
        }, () => MockClient((request) async => http.Response('{}', 200)));
      },
    );

    testWidgets('a device that took the session over at nfc_read opens the chip read directly, with the '
        "server's chip access key, instead of rescanning the MRZ", (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      final info = ProofingSessionInfo(
        id: 'sess1',
        relyingParty: 'acme-tenant',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        steps: const [stepDocumentCapture, stepNfcRead, stepFaceVerification],
        lifecycle: proofingLifecycleActive,
        currentStep: stepNfcRead,
        completedSteps: const [stepDocumentCapture],
        chipAccess: ProofingChipAccess(
          documentType: DocumentType.identityCard,
          documentNumber: 'SPECI2014',
          countryCode: 'NLD',
          dateOfBirth: DateTime(1965, 3, 10),
          dateOfExpiry: DateTime(2034, 3, 9),
        ),
      );

      await tester.pumpWidget(_routerApp(router));
      router.push(
        '/proofing_consent',
        extra: {
          'ref': const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
          'info': info,
        },
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ScannerWrapper), findsNothing);
      final nfc = tester.widget<NfcReadingScreen>(find.byType(NfcReadingScreen));
      expect(nfc.params.documentType, DocumentType.identityCard);
      final mrz = nfc.params.scannedMRZ as ScannedPassportMRZ;
      expect(mrz.documentNumber, 'SPECI2014');
      expect(mrz.dateOfBirth, DateTime(1965, 3, 10));
      expect(mrz.dateOfExpiry, DateTime(2034, 3, 9));
    });

    testWidgets('a device that took the session over at the face step compares against the chip photo the server '
        'holds, so the face check starts by itself', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);
      final chipPhoto = Uint8List.fromList([5, 6, 7, 8]);
      final info = ProofingSessionInfo(
        id: 'sess1',
        relyingParty: 'acme-tenant',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        steps: const [stepDocumentCapture, stepNfcRead, stepFaceVerification],
        selfieLocation: 'native',
        lifecycle: proofingLifecycleActive,
        currentStep: stepFaceVerification,
        completedSteps: const [stepDocumentCapture, stepNfcRead],
        faceReference: ProofingPhotoInfo(imageBase64: base64Encode(chipPhoto), mimeType: 'image/jp2'),
      );

      await tester.pumpWidget(_routerApp(router));
      router.push(
        '/proofing_consent',
        extra: {
          'ref': const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok'),
          'info': info,
        },
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      final face = tester.widget<FaceVerificationEntryScreen>(find.byType(FaceVerificationEntryScreen));
      expect(face.nfcImageBytes, chipPhoto);
    });

    testWidgets('submitting after the session expired is refused and ends with the expired message, not a retry', (
      tester,
    ) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      final steps = _flowServer(const [stepDocumentCapture]);

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_routerApp(router));
          await tester.pump();
          final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
          const sessionRef = ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok', deviceToken: 'dev');
          final info = ProofingSessionInfo(
            id: 'sess1',
            relyingParty: 'acme-tenant',
            requestedAttributes: const [],
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            steps: const [stepDocumentCapture],
          );
          container
              .read(activeProofingSessionProvider.notifier)
              .set(ActiveProofingSession(ref: sessionRef, info: info, openedAt: DateTime.now()));
          final coordinator = container.read(proofingSessionCoordinatorProvider);
          coordinator.track(sessionRef, info);
          final events = <ProofingSessionEvent>[];
          final sub = coordinator.events.listen(events.add);
          addTearDown(sub.cancel);

          router.go(
            Uri(
              path: '/mrz_reader',
              queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
            ).toString(),
          );
          await tester.pump();
          await tester.pump();
          tester
              .widget<ScannerWrapper>(find.byType(ScannerWrapper))
              .onMrzScanned(_scannedPassport(DocumentType.passport));
          await _pumpStepSubmission(tester);
          await _pumpStepSubmission(tester);

          // main.dart turns this into "Verification stopped: This
          // verification session has expired...".
          expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.expired);
          expect(find.text('Could not send'), findsNothing);
          expect(find.text('Retry'), findsNothing);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/submit')) {
            return http.Response(json.encode({'error': 'session expired', 'code': 'session_expired'}), 410);
          }
          return steps(request);
        }),
      );
    });

    testWidgets("the server's COMPLETE after the chip read (the other device already submitted) ends the "
        'verification, even though the flow it was pinned with still lists a native face step', (tester) async {
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final router = createRouter(scannerBuilder: _scannerBuilder(), faceVerificationEngine: engine);
      addTearDown(router.dispose);
      final documentStepBodies = <Map<String, dynamic>>[];

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_routerApp(router));
          await tester.pump();
          final container = ProviderScope.containerOf(tester.element(find.byType(DocumentTypeSelectionScreen)));
          const sessionRef = ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok', deviceToken: 'dev');
          final info = ProofingSessionInfo(
            id: 'sess1',
            relyingParty: 'acme-tenant',
            requestedAttributes: const [],
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            steps: const [stepDocumentCapture, stepNfcRead, stepFaceVerification],
            selfieLocation: 'native',
          );
          container
              .read(activeProofingSessionProvider.notifier)
              .set(ActiveProofingSession(ref: sessionRef, info: info, openedAt: DateTime.now()));
          // main.dart tracks every pinned session.
          final coordinator = container.read(proofingSessionCoordinatorProvider);
          coordinator.track(sessionRef, info);
          final events = <ProofingSessionEvent>[];
          final sub = coordinator.events.listen(events.add);
          addTearDown(sub.cancel);
          router.go(
            Uri(
              path: '/mrz_reader',
              queryParameters: MrzReaderRouteParams(documentType: DocumentType.passport).toQueryParams(),
            ).toString(),
          );
          await tester.pump();
          await tester.pump();

          tester
              .widget<ScannerWrapper>(find.byType(ScannerWrapper))
              .onMrzScanned(_scannedPassport(DocumentType.passport));
          await _pumpStepSubmission(tester);
          expect(find.byType(NfcReadingScreen), findsOneWidget);
          final chipAccess = documentStepBodies.single['chipAccess'] as Map<String, dynamic>;
          expect(chipAccess['documentType'], 'passport');
          expect(chipAccess['documentNumber'], _scannedPassport(DocumentType.passport).documentNumber);
          expect(chipAccess['dateOfBirth'], isNotNull);

          tester
              .widgetList<NfcReadingScreen>(find.byType(NfcReadingScreen))
              .last
              .onSuccess(_passportData(), _rawDocument());
          await _pumpStepSubmission(tester);

          expect(find.byType(FaceVerificationEntryScreen), findsNothing);
          expect(events.single, isA<ProofingSessionCompleted>());
          expect(coordinator.held, isNull);
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/steps/document_capture')) {
            documentStepBodies.add(json.decode(request.body) as Map<String, dynamic>);
            return http.Response(
              json.encode({'status': 'in_progress', 'currentStep': stepNfcRead, 'lifecycle': 'ACTIVE'}),
              200,
            );
          }
          if (path.endsWith('/steps/nfc')) {
            // Another device already did the face step: the server is done.
            return http.Response(json.encode({'status': 'approved', 'currentStep': '', 'lifecycle': 'COMPLETE'}), 200);
          }
          return http.Response('{}', 200);
        }),
      );
    });

    testWidgets('proofing consent route: Decline returns to document selection without pinning a session', (
      tester,
    ) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);
      final sessionRef = const ProofingSessionRef(apiBase: 'http://10.0.0.1:8080', token: 'tok');
      final info = ProofingSessionInfo(
        id: 'sess1',
        relyingParty: 'acme-tenant',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(_routerApp(router));
      router.push('/proofing_consent', extra: {'ref': sessionRef, 'info': info});
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(ProofingSessionConsentScreen)));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');
      expect(container.read(activeProofingSessionProvider), isNull);
    });

    testWidgets('scanning a QR that is not a session handoff pops back and reports the raw value', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));
      router.push('/qr_scanner');
      await tester.pump();
      await tester.pump();

      final qrScreen = tester.widget<QrScannerScreen>(find.byType(QrScannerScreen));
      qrScreen.onScanned('not a proofing session url');
      await tester.pump();
      await tester.pump();

      expect(find.byType(QrScannerScreen), findsNothing);
      expect(find.byType(DocumentTypeSelectionScreen), findsOneWidget);
      expect(find.text('QR code scanned: not a proofing session url'), findsOneWidget);
    });

    testWidgets('scanning a session QR with no requestedAttributes pops back with an explanatory snackbar', (
      tester,
    ) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_routerApp(router));
          router.push('/qr_scanner');
          await tester.pump();
          await tester.pump();

          final qrScreen = tester.widget<QrScannerScreen>(find.byType(QrScannerScreen));
          qrScreen.onScanned('vcmrtd://verify?handover=grant-empty&api=https://proof.example.com');
          await tester.pump();
          await tester.pump();

          expect(find.byType(QrScannerScreen), findsNothing);
          expect(find.byType(DocumentTypeSelectionScreen), findsOneWidget);
          expect(find.text('This session does not specify what to collect'), findsOneWidget);
        },
        () => MockClient((request) async {
          // Only a claim gets the session (flutter_test's expect can't run in here).
          if (request.url.path != '/api/v1/app/handover/grant-empty/claim') return http.Response('{}', 404);
          return http.Response(
            json.encode({
              'token': 'tok-empty',
              'deviceToken': 'dev-1',
              'session': {
                'id': 'sess-empty',
                'relyingParty': 'Acme Corp',
                'requestedAttributes': <String>[],
                'expiresAt': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
              },
            }),
            200,
          );
        }),
      );
    });

    testWidgets('scanning a valid session QR pops back then pushes the consent screen', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_routerApp(router));
          router.push('/qr_scanner');
          await tester.pump();
          await tester.pump();

          final qrScreen = tester.widget<QrScannerScreen>(find.byType(QrScannerScreen));
          qrScreen.onScanned('vcmrtd://verify?handover=grant-1&api=https://proof.example.com');
          await tester.pumpAndSettle();

          expect(find.byType(QrScannerScreen), findsNothing);
          expect(find.byType(ProofingSessionConsentScreen), findsOneWidget);
          expect(find.text('acme-tenant'), findsOneWidget);
        },
        () => MockClient((request) async {
          // Only a claim gets the session (flutter_test's expect can't run in here).
          if (request.url.path != '/api/v1/app/handover/grant-1/claim') return http.Response('{}', 404);
          return http.Response(
            json.encode({
              'token': 'tok-1',
              'deviceToken': 'dev-1',
              'session': {
                'id': 'sess-1',
                'relyingParty': 'acme-tenant',
                'requestedAttributes': ['dg1'],
                'expiresAt': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
              },
            }),
            200,
          );
        }),
      );
    });

    testWidgets('a session fetch failure pops back and reports the error', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await http.runWithClient(() async {
        await tester.pumpWidget(_routerApp(router));
        router.push('/qr_scanner');
        await tester.pump();
        await tester.pump();

        final qrScreen = tester.widget<QrScannerScreen>(find.byType(QrScannerScreen));
        qrScreen.onScanned('vcmrtd://verify?handover=grant-down&api=https://proof.example.com');
        await tester.pump();
        await tester.pump();

        expect(find.byType(QrScannerScreen), findsNothing);
        expect(find.byType(DocumentTypeSelectionScreen), findsOneWidget);
        expect(find.textContaining('Could not connect to the relying party:'), findsOneWidget);
      }, () => MockClient((request) async => http.Response('server error', 500)));
    });

    testWidgets('builds result route for identity card using passport data screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createRouter(scannerBuilder: _scannerBuilder());
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router));

      router.go(
        '/result',
        extra: {'document': _passportData(), 'result': _rawDocument(), 'document_type': DocumentType.identityCard},
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(PassportDataScreen), findsOneWidget);
    });
  });
}
