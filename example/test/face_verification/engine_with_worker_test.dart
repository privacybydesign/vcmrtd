import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_engine.dart';
import 'package:vcmrtdapp/features/face_verification/worker_result_types.dart';

class _FakeWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast();

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    await _frames.close();
  }

  @override
  Future<void> startSession() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> processCameraFrame(CameraImage cameraImage, int rotationDegrees) async {}

  @override
  Future<img.Image?> detectAndCropEncoded(Uint8List encoded) async => null;

  @override
  Future<void> prepareNfcFace(img.Image face) async {}

  @override
  Future<void> storeConsistencySelfie(img.Image selfie) async {}

  @override
  Future<double> checkConsistencySelfie(img.Image selfie) async => 1.0;

  @override
  Future<WorkerMatchResult> matchSelfie(img.Image selfie) async => const WorkerMatchResult(score: 0.0);

  @override
  Future<WorkerPassiveResult> getPassiveResult() async => const WorkerPassiveResult(
    antiSpoofScore: null,
    antiSpoofPassed: false,
    rppgHr: null,
    rppgPassed: false,
    rppgSampleCount: 0,
    rppgDurationMs: 0,
  );
}

void main() {
  test('FaceVerificationEngine.withWorker accepts injected worker and exposes frameChainDrained', () async {
    final fake = _FakeWorker();
    final engine = FaceVerificationEngine.withWorker(fake);

    // initialize should attach to the worker frames stream without error.
    await engine.initialize();

    // frameChainDrained getter should be a Future that completes normally.
    await engine.frameChainDrained;

    await engine.dispose();
  });
}
