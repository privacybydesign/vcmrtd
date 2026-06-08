import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_engine.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/routing.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';

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
          onPressed: () =>
              context.pushFaceVerificationScreen(Uint8List.fromList(<int>[1, 2, 3]), issueDate: DateTime(2024, 2, 1)),
          child: const Text('push face verification'),
        ),
      ],
    );
  }
}

void main() {
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
      expect(find.text('Scan ${DocumentType.identityCard.displayName}'), findsOneWidget);
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

    testWidgets('MRZ reader callbacks navigate to NFC reading and manual entry', (tester) async {
      final router = createRouter(scannerBuilder: _scannerBuilder());
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
      expect(find.byType(PassportDataScreen), findsOneWidget);

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

    testWidgets('result route callbacks navigate back and to face verification for passport and driving licence', (
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
        extra: {'document': _passportData(), 'result': _rawDocument(), 'document_type': DocumentType.identityCard},
      );
      await tester.pump();
      await tester.pump();
      final issueDate = DateTime(2024, 3, 4);
      tester
          .widgetList<PassportDataScreen>(find.byType(PassportDataScreen))
          .last
          .onFaceVerification(Uint8List.fromList([9]), issueDate);
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);

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

      final drivingIssueDate = DateTime(2024, 4, 5);
      tester
          .widgetList<DrivingLicenceDataScreen>(find.byType(DrivingLicenceDataScreen))
          .last
          .onFaceVerification(Uint8List.fromList([7, 8]), drivingIssueDate);
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);

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
        },
      );
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
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
