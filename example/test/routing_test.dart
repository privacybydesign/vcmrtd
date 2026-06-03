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
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

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
  });
}
