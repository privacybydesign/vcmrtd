import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/face_verification_engine.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';

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

void main() {
  group('FaceVerificationEntryScreen', () {
    testWidgets('wraps FlutterFaceVerificationScreen with injected engine', (tester) async {
      var backCount = 0;
      final engine = FaceVerificationEngine.withWorker(_FakeWorker());
      final issueDate = DateTime(2022, 1, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: FaceVerificationEntryScreen.withEngine(
            engine: engine,
            nfcImageBytes: Uint8List.fromList([1, 2, 3]),
            onBackPressed: () => backCount++,
            photoIssueDate: issueDate,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
      expect(screen.nfcImageBytes, Uint8List.fromList([1, 2, 3]));
      expect(screen.photoIssueDate, issueDate);
      expect(
        tester.state<FlutterFaceVerificationScreenState>(find.byType(FlutterFaceVerificationScreen)).debugEngineReady,
        isTrue,
      );

      screen.onBackPressed();
      expect(backCount, 1);
    });

    testWidgets('default build branch returns a face verification screen without mounting it', (tester) async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final issueDate = DateTime(2024, 2, 1);
      Widget? built;

      final screen = FaceVerificationEntryScreen(nfcImageBytes: bytes, onBackPressed: () {}, photoIssueDate: issueDate);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = screen.build(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final faceScreen = built as FlutterFaceVerificationScreen;
      expect(faceScreen.nfcImageBytes, bytes);
      expect(faceScreen.photoIssueDate, issueDate);
    });
  });
}
