import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmark_pipeline.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';

void main() {
  group('DetectorStageOutput', () {
    test('stores detector crop values', () {
      const output = DetectorStageOutput(cropX1: 0.1, cropY1: 0.2, cropW: 0.3, cropH: 0.4, angle: 0.5);

      expect(output.cropX1, 0.1);
      expect(output.cropY1, 0.2);
      expect(output.cropW, 0.3);
      expect(output.cropH, 0.4);
      expect(output.angle, 0.5);
    });
  });

  group('FaceLandmarkPipeline.computeTrackingCrop', () {
    test('returns null when no landmarks are present', () {
      final pipeline = FaceLandmarkPipeline();

      expect(
        pipeline.computeTrackingCrop(FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[]), 640, 480),
        isNull,
      );
    });

    test('returns null when landmark count is too short', () {
      final pipeline = FaceLandmarkPipeline();
      final result = FaceLandmarkerResult(
        landmarks: <List<NormalizedLandmark>>[
          List<NormalizedLandmark>.filled(10, const NormalizedLandmark(0.5, 0.5, 0)),
        ],
      );

      expect(pipeline.computeTrackingCrop(result, 640, 480), isNull);
    });

    test('computes a finite centered crop from a valid landmark set', () {
      final pipeline = FaceLandmarkPipeline();
      final crop = pipeline.computeTrackingCrop(
        FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[_landmarks()]),
        640,
        480,
      );

      expect(crop, isNotNull);
      expect(crop!.cropX1.isFinite, isTrue);
      expect(crop.cropY1.isFinite, isTrue);
      expect(crop.cropW, greaterThan(0));
      expect(crop.cropH, greaterThan(0));
      expect(crop.angle, closeTo(0, 1e-9));
    });

    test('clamps out-of-frame landmarks before computing the crop', () {
      final pipeline = FaceLandmarkPipeline();
      final landmarks = _landmarks()
        ..[0] = const NormalizedLandmark(-1.5, -2, 0)
        ..[1] = const NormalizedLandmark(2.0, 1.8, 0);

      final crop = pipeline.computeTrackingCrop(
        FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[landmarks]),
        640,
        480,
      );

      expect(crop, isNotNull);
      expect(crop!.cropW, lessThanOrEqualTo(2.0));
      expect(crop.cropH, lessThanOrEqualTo(640 / 480 * 2.0));
      expect(crop.cropX1.isFinite, isTrue);
      expect(crop.cropY1.isFinite, isTrue);
    });

    test('uses eye landmarks to compute crop rotation', () {
      final pipeline = FaceLandmarkPipeline();
      final landmarks = _landmarks()
        ..[33] = const NormalizedLandmark(0.5, 0.6, 0)
        ..[263] = const NormalizedLandmark(0.5, 0.4, 0);

      final crop = pipeline.computeTrackingCrop(
        FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[landmarks]),
        640,
        640,
      );

      expect(crop, isNotNull);
      expect(crop!.angle, closeTo(-math.pi / 2, 1e-9));
    });
  });
}

List<NormalizedLandmark> _landmarks() {
  final landmarks = List<NormalizedLandmark>.generate(478, (i) {
    final x = 0.44 + (i % 10) * 0.012;
    final y = 0.42 + (i % 12) * 0.012;
    return NormalizedLandmark(x, y, 0);
  }, growable: false);

  landmarks[33] = const NormalizedLandmark(0.45, 0.5, 0);
  landmarks[263] = const NormalizedLandmark(0.55, 0.5, 0);
  return landmarks;
}
