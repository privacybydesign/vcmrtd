import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/src/face_verification/detection/face_landmark_pipeline.dart';
import 'package:vcmrtd/src/face_verification/detection/face_landmarker_types.dart';

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

  group('FaceLandmarkPipeline pure math helpers', () {
    test('debugNormalizeAngle wraps angles into -pi..pi', () {
      expect(FaceLandmarkPipeline.debugNormalizeAngle(0), closeTo(0, 1e-9));
      expect(FaceLandmarkPipeline.debugNormalizeAngle(3 * math.pi), closeTo(math.pi, 1e-9));
      expect(FaceLandmarkPipeline.debugNormalizeAngle(-3 * math.pi), closeTo(math.pi, 1e-9));

      final wrappedPositive = FaceLandmarkPipeline.debugNormalizeAngle(4 * math.pi / 3);
      final wrappedNegative = FaceLandmarkPipeline.debugNormalizeAngle(-4 * math.pi / 3);

      expect(wrappedPositive, closeTo(-2 * math.pi / 3, 1e-9));
      expect(wrappedNegative, closeTo(2 * math.pi / 3, 1e-9));
    });

    test('debugSigmoid maps negative zero and positive values', () {
      expect(FaceLandmarkPipeline.debugSigmoid(0), closeTo(0.5, 1e-9));
      expect(FaceLandmarkPipeline.debugSigmoid(10), greaterThan(0.99));
      expect(FaceLandmarkPipeline.debugSigmoid(-10), lessThan(0.01));
    });

    test('debugBuildAnchors creates expected anchor count', () {
      final anchors = FaceLandmarkPipeline.debugBuildAnchors();

      expect(anchors.length, 896);
      expect(anchors.first.length, 2);
      expect(anchors.first[0], greaterThan(0));
      expect(anchors.first[1], greaterThan(0));
    });

    test('debugComputeRotation returns zero for horizontal eyes', () {
      final pipeline = FaceLandmarkPipeline();

      final angle = pipeline.debugComputeRotation(0.25, 0.5, 0.75, 0.5, imgW: 640, imgH: 480);

      expect(angle, closeTo(0, 1e-9));
    });

    test('debugComputeRotation accounts for image aspect ratio', () {
      final pipeline = FaceLandmarkPipeline();

      final angle = pipeline.debugComputeRotation(0.5, 0.6, 0.5, 0.4, imgW: 640, imgH: 480);

      expect(angle, closeTo(-math.pi / 2, 1e-9));
    });

    test('debugIou returns zero for non-overlapping boxes', () {
      final pipeline = FaceLandmarkPipeline();

      expect(pipeline.debugIou(<double>[0.0, 0.0, 0.2, 0.2], <double>[0.8, 0.8, 1.0, 1.0]), closeTo(0.0, 1e-9));
    });

    test('debugIou returns positive value for overlapping boxes', () {
      final pipeline = FaceLandmarkPipeline();

      final iou = pipeline.debugIou(<double>[0.0, 0.0, 0.6, 0.6], <double>[0.3, 0.3, 0.9, 0.9]);

      expect(iou, greaterThan(0));
      expect(iou, lessThan(1));
    });

    test('debugMergeBoxGroup returns weighted box merge', () {
      final pipeline = FaceLandmarkPipeline();

      final merged = pipeline.debugMergeBoxGroup(<List<double>>[
        <double>[0.0, 0.0, 0.4, 0.4, 0.8],
        <double>[0.2, 0.2, 0.6, 0.6, 0.2],
      ], 5);

      expect(merged[0], closeTo(0.04, 1e-9));
      expect(merged[1], closeTo(0.04, 1e-9));
      expect(merged[2], closeTo(0.44, 1e-9));
      expect(merged[3], closeTo(0.44, 1e-9));
      expect(merged[4], closeTo(0.8, 1e-9));
    });

    test('debugMergeBoxGroup returns first box when total score is zero', () {
      final pipeline = FaceLandmarkPipeline();

      final first = <double>[0.1, 0.2, 0.3, 0.4, 0.0];
      final merged = pipeline.debugMergeBoxGroup(<List<double>>[
        first,
        <double>[0.5, 0.6, 0.7, 0.8, 0.0],
      ], 5);

      expect(merged, first);
    });

    test('debugSoftNms merges overlapping boxes', () {
      final pipeline = FaceLandmarkPipeline();

      final result = pipeline.debugSoftNms(<List<double>>[
        <double>[0.0, 0.0, 0.6, 0.6, 0.9],
        <double>[0.1, 0.1, 0.7, 0.7, 0.8],
      ], 5);

      expect(result, isNotNull);
      expect(result![4], closeTo(0.9, 1e-9));
    });

    test('debugSoftNms returns null for empty list', () {
      final pipeline = FaceLandmarkPipeline();

      expect(pipeline.debugSoftNms(<List<double>>[], 5), isNull);
    });
  });

  group('FaceLandmarkPipeline image input helpers', () {
    img.Image solidImage({required int width, required int height, required int r, required int g, required int b}) {
      final image = img.Image(width: width, height: height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      return image;
    }

    test('debugDrawDetectorLetterboxed outputs detector-size image', () {
      final pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();

      final letterboxed = pipeline.debugDrawDetectorLetterboxed(solidImage(width: 80, height: 160, r: 255, g: 0, b: 0));

      expect(letterboxed.width, 128);
      expect(letterboxed.height, 128);
    });

    test('debugBuildDetectorInput returns normalized detector buffer', () {
      final pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();

      final buffer = pipeline.debugBuildDetectorInput(solidImage(width: 128, height: 128, r: 255, g: 127, b: 0));

      final floats = buffer.asFloat32List();

      expect(floats.length, 128 * 128 * 3);
      expect(floats[0], closeTo(1.0, 1e-3));
      expect(floats[2], closeTo(-1.0, 1e-3));
    });

    test('debugBuildLandmarkInput returns 256x256x3 normalized buffer', () {
      final pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();

      final buffer = pipeline.debugBuildLandmarkInput(
        solidImage(width: 20, height: 20, r: 255, g: 0, b: 0),
        const DetectorStageOutput(cropX1: 0.0, cropY1: 0.0, cropW: 1.0, cropH: 1.0, angle: 0.0),
      );

      final floats = buffer.asFloat32List();

      expect(floats.length, 256 * 256 * 3);
      expect(floats.any((v) => v > 0), isTrue);
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
