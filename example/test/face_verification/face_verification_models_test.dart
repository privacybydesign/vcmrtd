import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/worker_result_types.dart';

void main() {
  test('FaceObservation stores detector outputs used by liveness and matching', () {
    final result = FaceLandmarkerResult(
      landmarks: <List<NormalizedLandmark>>[
        <NormalizedLandmark>[const NormalizedLandmark(0.5, 0.5, 0)],
      ],
      blendshapes: <List<Category>>[
        <Category>[const Category('jawOpen', 0.1)],
      ],
      transformMatrices: <List<double>>[
        <double>[1, 0, 0],
      ],
    );
    final image = img.Image(width: 112, height: 112);
    final observation = FaceObservation(
      result: result,
      boundingBox: const Rect.fromLTWH(1, 2, 3, 4),
      boundingBoxAreaRatio: 0.25,
      boundingBoxCenter: const Offset(0.4, 0.6),
      mouthRatio: 0.02,
      yawDegrees: 3,
      blendshapeScores: const <String, double>{'jawOpen': 0.1},
      alignedFace112: image,
    );

    expect(observation.result, same(result));
    expect(observation.boundingBoxAreaRatio, 0.25);
    expect(observation.boundingBoxCenter, const Offset(0.4, 0.6));
    expect(observation.alignedFace112, same(image));
  });

  test('worker result types expose immutable result values', () {
    const passive = WorkerPassiveResult(
      antiSpoofScore: 0.8,
      antiSpoofPassed: true,
      rppgHr: 72,
      rppgPassed: true,
      rppgSampleCount: 30,
      rppgDurationMs: 3000,
    );
    const match = WorkerMatchResult(score: 0.7);
    const frame = WorkerFrameResult(face: null);

    expect(passive.antiSpoofScore, 0.8);
    expect(passive.rppgSampleCount, 30);
    expect(match.score, 0.7);
    expect(frame.face, isNull);
  });
}
