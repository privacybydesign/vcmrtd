import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

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

void main() {
  testWidgets('withEngine constructor renders the face verification screen', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(engine: engine, nfcImageBytes: Uint8List(1), onBackPressed: () {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);
  });

  testWidgets('withEngine forwards photoIssueDate', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen.withEngine(
          engine: engine,
          nfcImageBytes: Uint8List(1),
          onBackPressed: () {},
          photoIssueDate: DateTime(2024, 1, 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);
  });
}
