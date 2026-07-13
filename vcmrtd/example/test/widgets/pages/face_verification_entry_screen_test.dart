import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/services/regula_face_service.dart';
import 'package:vcmrtdapp/widgets/pages/face_method_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/regula_result_screen.dart';

class _FakeWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;
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

/// Fake Regula service returning a canned result without the native SDK.
class _FakeRegula implements RegulaFaceService {
  final RegulaFaceResult result = const RegulaFaceResult(
    isLive: true,
    matchThreshold: 0.75,
    similarity: 0.9,
    transactionId: 'tx-1',
  );
  int verifyCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<RegulaLivenessResult> captureLiveness() async =>
      RegulaLivenessResult(isLive: result.isLive, transactionId: result.transactionId);

  @override
  Future<RegulaFaceResult> verifyAgainstDocument(Uint8List documentPortrait) async {
    verifyCalls++;
    return result;
  }
}

void main() {
  testWidgets('shows the method picker first, not the camera screen', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(engine: engine, nfcImageBytes: Uint8List(1), onBackPressed: () {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FaceMethodSelectionScreen), findsOneWidget);
    expect(find.byType(FlutterFaceVerificationScreen), findsNothing);
    expect(find.text('Passive Liveness'), findsOneWidget);
    expect(find.text('Active Liveness'), findsOneWidget);
    expect(find.text('Regula Liveness'), findsOneWidget);
  });

  testWidgets('selecting Active opens the camera screen in active mode, forwarding props', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(
          engine: engine,
          nfcImageBytes: Uint8List.fromList([1]),
          onBackPressed: () {},
          photoIssueDate: DateTime(2024, 1, 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Active Liveness'));
    await tester.pump();
    await tester.pump();

    final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
    expect(screen.mode, LivenessMode.active);
    expect(screen.photoIssueDate, DateTime(2024, 1, 1));
    expect(screen.nfcImageBytes, Uint8List.fromList([1]));
  });

  testWidgets('selecting Regula runs the service and shows its result screen', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    final regula = _FakeRegula();
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(
          engine: engine,
          nfcImageBytes: Uint8List.fromList([1]),
          onBackPressed: () {},
          regulaService: regula,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Regula Liveness'));
    await tester.pumpAndSettle();

    expect(regula.verifyCalls, 1);
    expect(find.byType(RegulaResultScreen), findsOneWidget);
    expect(find.text('Identity Verified'), findsOneWidget);
    expect(find.text('90.0%'), findsOneWidget);
  });

  testWidgets('back from the Regula result returns to the method picker', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    final regula = _FakeRegula();
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(
          engine: engine,
          nfcImageBytes: Uint8List.fromList([1]),
          onBackPressed: () {},
          regulaService: regula,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Regula Liveness'));
    await tester.pumpAndSettle();
    expect(find.byType(RegulaResultScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(FaceMethodSelectionScreen), findsOneWidget);
  });
}
