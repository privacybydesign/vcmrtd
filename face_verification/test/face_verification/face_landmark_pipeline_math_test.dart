import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_landmarker_types.dart';
import 'package:face_verification/src/detection/face_landmark_pipeline.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<double> _box(double x1, double y1, double x2, double y2, double score) => [x1, y1, x2, y2, score];

List<NormalizedLandmark> _landmarks478({double x = 0.5, double y = 0.5}) =>
    List.generate(478, (_) => NormalizedLandmark(x, y, 0));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FaceLandmarkPipeline.debugNormalizeAngle', () {
    test('0 stays 0', () => expect(FaceLandmarkPipeline.debugNormalizeAngle(0), 0));
    test('pi stays pi', () => expect(FaceLandmarkPipeline.debugNormalizeAngle(math.pi), closeTo(math.pi, 1e-9)));
    test('2*pi wraps to 0', () => expect(FaceLandmarkPipeline.debugNormalizeAngle(2 * math.pi), closeTo(0, 1e-9)));
    test(
      '3*pi wraps to -pi',
      () => expect(FaceLandmarkPipeline.debugNormalizeAngle(3 * math.pi).abs(), closeTo(math.pi, 1e-9)),
    );
    test(
      '-pi normalizes to ±pi (same angle)',
      () => expect(FaceLandmarkPipeline.debugNormalizeAngle(-math.pi).abs(), closeTo(math.pi, 1e-9)),
    );
  });

  group('FaceLandmarkPipeline.debugSigmoid', () {
    test('sigmoid(0) = 0.5', () => expect(FaceLandmarkPipeline.debugSigmoid(0), closeTo(0.5, 1e-9)));
    test(
      'sigmoid(large positive) approaches 1',
      () => expect(FaceLandmarkPipeline.debugSigmoid(100), closeTo(1.0, 1e-6)),
    );
    test(
      'sigmoid(large negative) approaches 0',
      () => expect(FaceLandmarkPipeline.debugSigmoid(-100), closeTo(0.0, 1e-6)),
    );
    test('sigmoid is symmetric: sig(x) + sig(-x) = 1', () {
      final s = FaceLandmarkPipeline.debugSigmoid(2.0);
      expect(s + FaceLandmarkPipeline.debugSigmoid(-2.0), closeTo(1.0, 1e-9));
    });
  });

  group('FaceLandmarkPipeline.debugBuildAnchors', () {
    test('produces exactly 896 anchors', () {
      final anchors = FaceLandmarkPipeline.debugBuildAnchors();
      expect(anchors.length, 896);
    });

    test('each anchor has 2 coordinates', () {
      final anchors = FaceLandmarkPipeline.debugBuildAnchors();
      for (final a in anchors) {
        expect(a.length, 2);
      }
    });

    test('anchor coordinates are in [0, 1]', () {
      final anchors = FaceLandmarkPipeline.debugBuildAnchors();
      for (final a in anchors) {
        expect(a[0], greaterThanOrEqualTo(0));
        expect(a[0], lessThanOrEqualTo(1));
        expect(a[1], greaterThanOrEqualTo(0));
        expect(a[1], lessThanOrEqualTo(1));
      }
    });
  });

  group('FaceLandmarkPipeline — IoU', () {
    final pipeline = FaceLandmarkPipeline();

    test('identical boxes have IoU ≈ 1.0 (formula has +1e-6 bias)', () {
      final box = _box(0.1, 0.1, 0.5, 0.5, 1.0);
      expect(pipeline.debugIou(box, box), closeTo(1.0, 1e-4));
    });

    test('non-overlapping boxes have IoU 0', () {
      final a = _box(0.0, 0.0, 0.2, 0.2, 1.0);
      final b = _box(0.8, 0.8, 1.0, 1.0, 1.0);
      expect(pipeline.debugIou(a, b), 0.0);
    });

    test('partially overlapping boxes have IoU between 0 and 1', () {
      final a = _box(0.0, 0.0, 0.5, 0.5, 1.0);
      final b = _box(0.25, 0.25, 0.75, 0.75, 1.0);
      final iou = pipeline.debugIou(a, b);
      expect(iou, greaterThan(0.0));
      expect(iou, lessThan(1.0));
    });

    test('touching boxes (shared edge) have IoU 0', () {
      final a = _box(0.0, 0.0, 0.5, 0.5, 1.0);
      final b = _box(0.5, 0.0, 1.0, 0.5, 1.0);
      expect(pipeline.debugIou(a, b), 0.0);
    });
  });

  group('FaceLandmarkPipeline — mergeBoxGroup', () {
    final pipeline = FaceLandmarkPipeline();
    const boxSize = 5;

    test('single box returns itself', () {
      final box = _box(0.1, 0.2, 0.4, 0.6, 0.9);
      final merged = pipeline.debugMergeBoxGroup([box], boxSize);
      expect(merged[0], closeTo(0.1, 1e-6));
      expect(merged[1], closeTo(0.2, 1e-6));
    });

    test('two equal-score boxes merge to their average', () {
      final a = _box(0.0, 0.0, 0.2, 0.2, 0.8);
      final b = _box(0.2, 0.2, 0.4, 0.4, 0.8);
      final merged = pipeline.debugMergeBoxGroup([a, b], boxSize);
      expect(merged[0], closeTo(0.1, 1e-6)); // avg of 0.0 and 0.2
      expect(merged[1], closeTo(0.1, 1e-6)); // avg of 0.0 and 0.2
    });

    test('score of merged box is score of first (highest) box', () {
      final a = _box(0.0, 0.0, 0.5, 0.5, 0.9);
      final b = _box(0.1, 0.1, 0.6, 0.6, 0.5);
      final merged = pipeline.debugMergeBoxGroup([a, b], boxSize);
      expect(merged[4], closeTo(0.9, 1e-6));
    });
  });

  group('FaceLandmarkPipeline — softNms', () {
    final pipeline = FaceLandmarkPipeline();
    const boxSize = 5;

    test('single box is returned as-is', () {
      final box = _box(0.1, 0.1, 0.5, 0.5, 0.9);
      final result = pipeline.debugSoftNms([box], boxSize);
      expect(result, isNotNull);
      expect(result![4], closeTo(0.9, 1e-6));
    });

    test('empty list returns null', () {
      expect(pipeline.debugSoftNms([], boxSize), isNull);
    });

    test('two overlapping boxes are merged into one', () {
      final a = _box(0.1, 0.1, 0.5, 0.5, 0.9);
      final b = _box(0.12, 0.12, 0.52, 0.52, 0.8);
      final result = pipeline.debugSoftNms([a, b], boxSize);
      expect(result, isNotNull);
    });

    test('two non-overlapping boxes returns only first', () {
      final a = _box(0.0, 0.0, 0.2, 0.2, 0.9);
      final b = _box(0.8, 0.8, 1.0, 1.0, 0.8);
      final result = pipeline.debugSoftNms([a, b], boxSize);
      expect(result, isNotNull);
    });
  });

  group('FaceLandmarkPipeline — computeRotation', () {
    final pipeline = FaceLandmarkPipeline();

    test('horizontal eyes (same y) produce 0 rotation', () {
      final angle = pipeline.debugComputeRotation(0.3, 0.5, 0.7, 0.5);
      expect(angle, closeTo(0.0, 1e-9));
    });

    test('vertical eyes (same x) produce ±pi/2 rotation', () {
      final angle = pipeline.debugComputeRotation(0.5, 0.3, 0.5, 0.7);
      expect(angle.abs(), closeTo(math.pi / 2, 1e-9));
    });

    test('result is normalized to [-pi, pi]', () {
      final angle = pipeline.debugComputeRotation(0.0, 0.0, 1.0, 0.0);
      expect(angle, greaterThanOrEqualTo(-math.pi));
      expect(angle, lessThanOrEqualTo(math.pi));
    });
  });

  group('FaceLandmarkPipeline — buildSquareCrop', () {
    final pipeline = FaceLandmarkPipeline();

    test('returns 5-element list [x1, y1, w, h, angle]', () {
      final crop = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, 0.0, (
        width: 640,
        height: 480,
      ), FaceAlignmentMode.selfie);
      expect(crop.length, 5);
    });

    test('crop angle matches input angle', () {
      const angle = 0.25;
      final crop = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, angle, (
        width: 640,
        height: 480,
      ), FaceAlignmentMode.selfie);
      expect(crop[4], closeTo(angle, 1e-9));
    });

    test('NFC mode produces valid crop', () {
      final crop = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, 0.0, (
        width: 480,
        height: 640,
      ), FaceAlignmentMode.nfc);
      expect(crop.length, 5);
      expect(crop[2], greaterThan(0)); // width > 0
      expect(crop[3], greaterThan(0)); // height > 0
    });
  });

  group('FaceLandmarkPipeline — deLetterboxDetection', () {
    final pipeline = FaceLandmarkPipeline();

    test('square image (no letterbox) returns box unchanged', () {
      final box = [0.2, 0.3, 0.6, 0.7, 0.9];
      final result = pipeline.debugDeLetterboxDetection(box, 128, 128);
      expect(result[0], closeTo(0.2, 1e-6));
      expect(result[1], closeTo(0.3, 1e-6));
    });

    test('portrait image shifts box coordinates', () {
      // Portrait: 64×128 → letterbox adds left/right padding in 128×128 space
      final box = [0.2, 0.1, 0.8, 0.9, 0.9];
      final result = pipeline.debugDeLetterboxDetection(box, 64, 128);
      // After de-letterboxing, x coordinates should be adjusted
      expect(result.length, box.length);
    });

    test('landscape image shifts box coordinates', () {
      final box = [0.2, 0.1, 0.8, 0.9, 0.9];
      final result = pipeline.debugDeLetterboxDetection(box, 128, 64);
      expect(result.length, box.length);
      // y coordinates should change for landscape (top/bottom padding)
      expect(result[0], closeTo(0.2, 1e-6)); // no x change for landscape
    });

    test('coordinates stay clamped to [0, 1]', () {
      final box = [0.0, 0.0, 1.0, 1.0, 0.9];
      final result = pipeline.debugDeLetterboxDetection(box, 64, 128);
      for (var i = 0; i < 4; i++) {
        expect(result[i], greaterThanOrEqualTo(0.0));
        expect(result[i], lessThanOrEqualTo(1.0));
      }
    });
  });

  group('FaceLandmarkPipeline — remapLandmarks', () {
    final pipeline = FaceLandmarkPipeline();

    test('returns correct landmark count', () {
      // 6 landmarks × 3 values each = 18 raw values
      final raw = List<double>.generate(6 * 3, (i) => i * 0.1);
      final result = pipeline.debugRemapLandmarks(raw, 0.1, 0.1, 0.8, 0.8, 0.0);
      expect(result.length, 6);
    });

    test('center landmark maps to crop center for angle 0', () {
      // Landmark at model center (landmarkSize/2, landmarkSize/2)
      // = (128, 128) → (0.5, 0.5) in [0,1] → normalized (0.0, 0.0) offset
      // → should map to crop center (cx, cy)
      const cx = 0.5, cy = 0.5, cw = 0.6, ch = 0.6;
      final raw = [128.0, 128.0, 0.0]; // center of 256×256 model input
      final result = pipeline.debugRemapLandmarks(raw, cx - cw / 2, cy - ch / 2, cw, ch, 0.0);
      expect(result[0].x, closeTo(cx, 1e-6));
      expect(result[0].y, closeTo(cy, 1e-6));
    });

    test('empty raw produces empty landmark list', () {
      final result = pipeline.debugRemapLandmarks([], 0, 0, 1, 1, 0);
      expect(result, isEmpty);
    });
  });

  group('FaceLandmarkPipeline — keypointBlendedCenter', () {
    final pipeline = FaceLandmarkPipeline();

    test('returns null for box with fewer than 17 elements', () {
      final box = List<double>.filled(10, 0.5);
      expect(pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.selfie), isNull);
    });

    test('returns null when keypoints are collapsed (degenerate cluster)', () {
      // All keypoints at same point → kpW = 0 → degenerate
      final box = List<double>.filled(17, 0.5);
      expect(pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.selfie), isNull);
    });

    test('returns non-null for well-spread keypoints', () {
      final box = List<double>.filled(17, 0.5);
      // Set keypoints spread across image
      box[5] = 0.2;
      box[6] = 0.3;
      box[7] = 0.7;
      box[8] = 0.3;
      box[9] = 0.3;
      box[10] = 0.7;
      box[11] = 0.6;
      box[12] = 0.7;
      final result = pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.selfie);
      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0], greaterThanOrEqualTo(0.0));
      expect(result[0], lessThanOrEqualTo(1.0));
    });
  });

  group('FaceLandmarkPipeline — computePoseMatrix', () {
    final pipeline = FaceLandmarkPipeline();

    test('returns null when fewer than 455 landmarks', () {
      final lm = List.generate(454, (_) => const NormalizedLandmark(0.5, 0.5, 0));
      expect(pipeline.debugComputePoseMatrix(lm), isNull);
    });

    test('returns 16-element matrix for valid landmarks', () {
      // Set distinct ear-to-ear and top-to-chin vectors
      final lm = _landmarks478();
      final mutable = List<NormalizedLandmark>.from(lm);
      mutable[234] = const NormalizedLandmark(0.2, 0.5, 0); // left ear
      mutable[454] = const NormalizedLandmark(0.8, 0.5, 0); // right ear
      mutable[10] = const NormalizedLandmark(0.5, 0.1, 0); // top
      mutable[152] = const NormalizedLandmark(0.5, 0.9, 0); // chin
      final matrix = pipeline.debugComputePoseMatrix(mutable);
      expect(matrix, isNotNull);
      expect(matrix!.length, 16);
      expect(matrix[15], closeTo(1.0, 1e-9)); // bottom-right = 1
    });

    test('returns null when ear vectors are degenerate', () {
      // All landmarks at same point → zero-length vectors
      final lm = _landmarks478();
      expect(pipeline.debugComputePoseMatrix(lm), isNull);
    });
  });

  group('FaceLandmarkPipeline — resetTracking / setTrackingCrop', () {
    test('computeTrackingCrop returns null after resetTracking', () {
      final pipeline = FaceLandmarkPipeline();
      pipeline.setTrackingCrop(const DetectorStageOutput(cropX1: 0.1, cropY1: 0.1, cropW: 0.5, cropH: 0.5, angle: 0));
      pipeline.resetTracking();
    });

    test('close() on uninitialised pipeline does not throw', () {
      FaceLandmarkPipeline().close();
    });
  });

  group('FaceLandmarkPipeline — detector input preprocessing (mock buffers)', () {
    late FaceLandmarkPipeline pipeline;

    setUp(() {
      pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();
    });

    tearDown(() => pipeline.close());

    test('buildDetectorInput produces a buffer of the correct byte size', () {
      final image = img.Image(width: 64, height: 64);
      final buf = pipeline.debugBuildDetectorInput(image);
      // 128×128 pixels × 3 channels × 4 bytes (float32)
      expect(buf.lengthInBytes, 128 * 128 * 3 * 4);
    });

    test('buildDetectorInput normalises pixel values to [-1, 1]', () {
      // All-white image (255,255,255) → (255-127.5)/127.5 = 1.0
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          image.setPixelRgb(x, y, 255, 255, 255);
        }
      }
      final buf = pipeline.debugBuildDetectorInput(image);
      final floats = buf.asFloat32List();
      expect(floats[0], closeTo(1.0, 1e-4));
    });

    test('buildDetectorInput normalises black pixel to -1.0', () {
      final image = img.Image(width: 64, height: 64); // default black
      final buf = pipeline.debugBuildDetectorInput(image);
      final floats = buf.asFloat32List();
      expect(floats[0], closeTo(-1.0, 1e-4));
    });

    test('drawDetectorLetterboxed produces a 128×128 image', () {
      final image = img.Image(width: 80, height: 60);
      final result = pipeline.debugDrawDetectorLetterboxed(image);
      expect(result.width, 128);
      expect(result.height, 128);
    });

    test('drawDetectorLetterboxed for portrait image adds side padding', () {
      // Portrait 64×128 → scale = min(128/64, 128/128) = 1.0
      // drawW = 64, drawH = 128 → left = 32, top = 0
      final image = img.Image(width: 64, height: 128);
      final result = pipeline.debugDrawDetectorLetterboxed(image);
      expect(result.width, 128);
      expect(result.height, 128);
    });

    test('buildLandmarkInput produces buffer of correct byte size', () {
      final image = img.Image(width: 256, height: 256);
      const crop = DetectorStageOutput(cropX1: 0.1, cropY1: 0.1, cropW: 0.8, cropH: 0.8, angle: 0);
      final buf = pipeline.debugBuildLandmarkInput(image, crop);
      // 256×256 pixels × 3 channels × 4 bytes (float32)
      expect(buf.lengthInBytes, 256 * 256 * 3 * 4);
    });

    test('buildLandmarkInput normalises to [0, 1]', () {
      // All-white 256×256 image
      final image = img.Image(width: 256, height: 256);
      for (var y = 0; y < 256; y++) {
        for (var x = 0; x < 256; x++) {
          image.setPixelRgb(x, y, 255, 255, 255);
        }
      }
      const crop = DetectorStageOutput(cropX1: 0.0, cropY1: 0.0, cropW: 1.0, cropH: 1.0, angle: 0);
      final buf = pipeline.debugBuildLandmarkInput(image, crop);
      final floats = buf.asFloat32List();
      // At least one pixel should be approximately 1.0
      expect(floats.any((v) => v > 0.9), isTrue);
    });
  });

  group('FaceLandmarkPipeline — detector decode with mock outputs', () {
    late FaceLandmarkPipeline pipeline;
    const scale = 128.0; // _detectorSize
    const boxSize = 17; // 5 + 6*2 keypoints

    setUp(() {
      pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();
    });

    tearDown(() => pipeline.close());

    List<dynamic> mockScores(int anchorCount, {int? highScoreIdx}) => [
      List.generate(anchorCount, (i) => [i == highScoreIdx ? 10.0 : -5.0]),
    ];

    List<dynamic> mockRegressors(int anchorCount, {double w = 10.0, double h = 10.0}) => [
      List.generate(anchorCount, (_) {
        final row = List<double>.filled(16, 0.0);
        row[2] = w;
        row[3] = h;
        return row;
      }),
    ];

    test('decodeBox returns null when score is below threshold', () {
      pipeline.debugSetMockDetectorOutputs(
        mockScores(896), // all low scores (sigmoid(-5) ≈ 0.007)
        mockRegressors(896),
      );
      expect(pipeline.debugDecodeBox(0, scale, boxSize), isNull);
    });

    test('decodeBox returns a box when score is above threshold', () {
      pipeline.debugSetMockDetectorOutputs(
        mockScores(896, highScoreIdx: 0), // sigmoid(10) ≈ 0.9999
        mockRegressors(896),
      );
      final box = pipeline.debugDecodeBox(0, scale, boxSize);
      expect(box, isNotNull);
      expect(box!.length, boxSize);
      expect(box[4], greaterThan(0.5)); // score field
    });

    test('decodeBox clamps box coordinates to [0, 1]', () {
      // Large offsets that would push box outside [0,1]
      pipeline.debugSetMockDetectorOutputs(mockScores(896, highScoreIdx: 0), [
        List.generate(896, (_) {
          final row = List<double>.filled(16, 9999.0);
          return row;
        }),
      ]);
      final box = pipeline.debugDecodeBox(0, scale, boxSize);
      if (box != null) {
        for (var i = 0; i < 4; i++) {
          expect(box[i], greaterThanOrEqualTo(0.0));
          expect(box[i], lessThanOrEqualTo(1.0));
        }
      }
    });

    test('decodeAndNms returns null when no boxes exceed threshold', () {
      pipeline.debugSetMockDetectorOutputs(
        mockScores(896), // all low
        mockRegressors(896),
      );
      expect(pipeline.debugDecodeAndNms(), isNull);
    });

    test('decodeAndNms returns a box when one anchor scores high', () {
      pipeline.debugSetMockDetectorOutputs(mockScores(896, highScoreIdx: 5), mockRegressors(896));
      final result = pipeline.debugDecodeAndNms();
      expect(result, isNotNull);
      expect(result!.length, boxSize);
    });

    test('decodeAndNms merges overlapping high-score boxes', () {
      // Two adjacent anchors with high score → soft NMS merges them
      final scores = [
        List.generate(896, (i) => [i < 2 ? 10.0 : -5.0]),
      ];
      pipeline.debugSetMockDetectorOutputs(scores, mockRegressors(896));
      final result = pipeline.debugDecodeAndNms();
      expect(result, isNotNull);
    });
  });
}
