import 'dart:ui' show Rect, Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/worker_result_types.dart';
import 'package:face_verification/src/detection/face_observation.dart';
import 'package:face_verification/src/detection/face_landmarker_types.dart';

void main() {
  group('Worker result types', () {
    test('WorkerFrameResult holds nullable face', () {
      final wf = WorkerFrameResult(face: null);
      expect(wf.face, isNull);

      final landmarks = List<NormalizedLandmark>.generate(478, (_) => const NormalizedLandmark(0.5, 0.5, 0));
      final result = FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[landmarks]);
      final fo = FaceObservation(
        result: result,
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
        boundingBoxAreaRatio: 0.2,
        boundingBoxCenter: const Offset(0.5, 0.5),
        mouthRatio: 0.01,
        yawDegrees: 0,
        blendshapeScores: const <String, double>{},
        alignedFace112: img.Image(width: 112, height: 112),
      );

      final wf2 = WorkerFrameResult(face: fo);
      expect(wf2.face, isNotNull);
      expect(wf2.face!.boundingBoxAreaRatio, closeTo(0.2, 1e-9));
    });

    test('WorkerPassiveResult fields map to constructor values', () {
      final p = WorkerPassiveResult(
        antiSpoofScore: 0.77,
        antiSpoofPassed: true,
        rppgHr: 65.0,
        rppgPassed: true,
        rppgSampleCount: 30,
        rppgDurationMs: 3000,
      );

      expect(p.antiSpoofScore, closeTo(0.77, 1e-9));
      expect(p.antiSpoofPassed, isTrue);
      expect(p.rppgHr, closeTo(65.0, 1e-9));
      expect(p.rppgPassed, isTrue);
      expect(p.rppgSampleCount, 30);
      expect(p.rppgDurationMs, 3000);
    });

    test('WorkerMatchResult holds score', () {
      final m = WorkerMatchResult(score: 0.42);
      expect(m.score, closeTo(0.42, 1e-9));
    });
  });
}
