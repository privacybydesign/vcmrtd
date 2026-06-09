import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/src/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtd/src/face_verification/detection/face_observation.dart';
import 'package:vcmrtd/src/face_verification/liveness/passive_liveness_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FaceObservation _face({double yaw = 0}) {
  final lm = List<NormalizedLandmark>.generate(478, (_) => const NormalizedLandmark(0.5, 0.5, 0));

  void set(int i, double x, double y) => lm[i] = NormalizedLandmark(x, y, 0);

  // Face-width landmarks used by _extractRois.
  set(109, 0.35, 0.5);
  set(338, 0.65, 0.5);
  // Feature points.
  set(10, 0.5, 0.22);
  set(205, 0.38, 0.60);
  set(425, 0.62, 0.60);
  set(4, 0.5, 0.50);
  set(0, 0.5, 0.70);
  set(17, 0.5, 0.76);

  final result = FaceLandmarkerResult(landmarks: [lm], blendshapes: [[]]);
  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(100, 100, 200, 200),
    boundingBoxAreaRatio: 0.20,
    boundingBoxCenter: const Offset(0.5, 0.5),
    mouthRatio: 0.02,
    yawDegrees: yaw,
    blendshapeScores: const {},
    alignedFace112: img.Image(width: 112, height: 112),
  );
}

img.Image _frame() => img.Image(width: 100, height: 100);

class _FixedRandom implements math.Random {
  const _FixedRandom(this.value);

  final double value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1).toInt();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PassiveLivenessService — anti-spoof debug helpers', () {
    test('getAntiSpoofScore returns null when no scores added', () {
      expect(PassiveLivenessService().getAntiSpoofScore(), isNull);
    });

    test('isAntiSpoofPassed returns false with insufficient samples', () {
      final svc = PassiveLivenessService();
      svc.debugAddAntiSpoofScore(0.9); // only 1 sample, need 4
      expect(svc.isAntiSpoofPassed(), isFalse);
    });

    test('passing scores produce isAntiSpoofPassed true', () {
      final svc = PassiveLivenessService();
      svc.debugAddAntiSpoofScore(0.8);
      svc.debugAddAntiSpoofScore(0.9);
      svc.debugAddAntiSpoofScore(0.85);
      svc.debugAddAntiSpoofScore(0.9);
      expect(svc.getAntiSpoofScore()!, greaterThan(0.7));
      expect(svc.isAntiSpoofPassed(), isTrue);
    });

    test('anti-spoof score at threshold passes with enough samples', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(PassiveLivenessService.antiSpoofMinScore);
      }

      expect(svc.getAntiSpoofScore(), closeTo(PassiveLivenessService.antiSpoofMinScore, 1e-9));
      expect(svc.isAntiSpoofPassed(), isTrue);
    });

    test('anti-spoof average just below threshold fails with enough samples', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(PassiveLivenessService.antiSpoofMinScore - 0.01);
      }

      expect(svc.getAntiSpoofScore(), lessThan(PassiveLivenessService.antiSpoofMinScore));
      expect(svc.isAntiSpoofPassed(), isFalse);
    });

    test('low anti-spoof scores produce a failing result', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(0.2);
      }
      expect(svc.isAntiSpoofPassed(), isFalse);
    });

    test('reset clears anti-spoof scores', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(0.9);
      }
      svc.reset();
      expect(svc.getAntiSpoofScore(), isNull);
      expect(svc.isAntiSpoofPassed(), isFalse);
    });

    test('reset is idempotent and clears anti-spoof plus rPPG state', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(0.9);
      }
      for (var i = 0; i < 20; i++) {
        svc.debugAddBvpSample(0.5, 1000 + i * 120);
      }

      svc.reset();
      svc.reset();

      expect(svc.getAntiSpoofScore(), isNull);
      expect(svc.isAntiSpoofPassed(), isFalse);
      expect(svc.debugEvaluateBvp(), isNull);
    });
  });

  group('PassiveLivenessService — rPPG debug helpers', () {
    test('getRppgResult returns null when fewer than 15 samples', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 14; i++) {
        svc.debugAddBvpSample(0.5, 1000 + i * 150);
      }
      expect(svc.getRppgResult(), isNull);
    });

    test('getRppgResult returns null when duration is less than 2000ms', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 15; i++) {
        svc.debugAddBvpSample(0.5, 1000 + i * 10);
      }
      expect(svc.getRppgResult(), isNull);
    });

    test('15 samples over 2000ms produce a non-null RppgResult', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 15; i++) {
        svc.debugAddBvpSample(0.5 + (i % 3) * 0.01, 1000 + i * 150);
      }
      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      expect(r!.sampleCount, greaterThanOrEqualTo(15));
      expect(r.durationMs, greaterThanOrEqualTo(2000));
    });

    test('samples at exact minimum duration can produce an rPPG result', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 21; i++) {
        svc.debugAddBvpSample(math.sin(i * 2 * math.pi / 10.0), 1000 + i * 100);
      }

      final r = svc.debugEvaluateBvp();

      expect(r, isNotNull);
      expect(r!.sampleCount, 21);
      expect(r.durationMs, 2000);
    });

    test('debugEvaluateBvpSamples reports sample count and duration', () {
      final svc = PassiveLivenessService();

      final result = svc.debugEvaluateBvpSamples(
        List<double>.generate(31, (i) => math.sin(i * 2 * math.pi / 10.0)),
        10,
      );

      expect(result.sampleCount, 31);
      expect(result.durationMs, 3000);
    });

    test('debugEvaluateBvpSamples passes heart rate inside threshold range', () {
      final svc = PassiveLivenessService();
      final samples = List<double>.filled(30, 0.0)
        ..[1] = 1.0
        ..[13] = 1.0
        ..[25] = 1.0;

      final result = svc.debugEvaluateBvpSamples(samples, 10);

      expect(result.hr, closeTo(50.0, 1e-6));
      expect(result.passed, isTrue);
    });

    test('debugEvaluateBvpSamples fails heart rate below threshold range', () {
      final svc = PassiveLivenessService();
      final samples = List<double>.filled(35, 0.0)
        ..[1] = 1.0
        ..[16] = 1.0
        ..[31] = 1.0;

      final result = svc.debugEvaluateBvpSamples(samples, 10);

      expect(result.hr, closeTo(40.0, 1e-6));
      expect(result.passed, isFalse);
    });

    test('debugEvaluateBvpSamples fails heart rate above threshold range', () {
      final svc = PassiveLivenessService();
      final samples = List<double>.filled(20, 0.0)
        ..[1] = 1.0
        ..[5] = 1.0
        ..[9] = 1.0
        ..[13] = 1.0;

      final result = svc.debugEvaluateBvpSamples(samples, 10);

      expect(result.hr, closeTo(150.0, 1e-6));
      expect(result.passed, isFalse);
    });

    test('sinusoidal BVP at ~70 BPM produces a valid passing heart rate', () {
      final svc = PassiveLivenessService();
      // 62 samples at 33ms → 61*33=2013ms; period 26 samples ≈ 69 BPM.
      for (var i = 0; i < 62; i++) {
        svc.debugAddBvpSample(math.sin(i * 2 * math.pi / 26.0), 1000 + i * 33);
      }
      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      if (r!.hr != null) {
        expect(r.hr!, greaterThanOrEqualTo(45.0));
        expect(r.hr!, lessThanOrEqualTo(110.0));
        expect(r.passed, isTrue);
      }
    });

    test('flat BVP signal produces no detectable heart rate', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 30; i++) {
        svc.debugAddBvpSample(0.5, 1000 + i * 100);
      }
      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      expect(r!.hr, isNull);
      expect(r.passed, isFalse);
    });

    test('heart rate above 110 BPM does not pass rPPG check', () {
      final svc = PassiveLivenessService();
      // Period 13 at 30fps ≈ 138 BPM — above 110 limit. 62 samples → 2013ms.
      for (var i = 0; i < 62; i++) {
        svc.debugAddBvpSample(math.sin(i * 2 * math.pi / 13.0), 1000 + i * 33);
      }
      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      if (r!.hr != null) expect(r.passed, isFalse);
    });

    test('reset clears BVP buffer so getRppgResult returns null', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 15; i++) {
        svc.debugAddBvpSample(0.5, 1000 + i * 150);
      }
      expect(svc.debugEvaluateBvp(), isNotNull);
      svc.reset();
      expect(svc.debugEvaluateBvp(), isNull);
    });
  });

  group('PassiveLivenessService — private math helpers', () {
    test('_softmax of equal logits produces uniform distribution', () {
      final svc = PassiveLivenessService();
      final result = svc.debugSoftmax([1.0, 1.0, 1.0]);
      expect(result.length, 3);
      for (final v in result) {
        expect(v, closeTo(1 / 3, 1e-6));
      }
    });

    test('_softmax of [0,1,2] peaks at last element', () {
      final svc = PassiveLivenessService();
      final result = svc.debugSoftmax([0.0, 1.0, 2.0]);
      expect(result[2], greaterThan(result[1]));
      expect(result[1], greaterThan(result[0]));
      expect(result.reduce((a, b) => a + b), closeTo(1.0, 1e-6));
    });

    test('_softmax sum is always 1.0', () {
      final svc = PassiveLivenessService();
      final result = svc.debugSoftmax([10.0, -5.0, 0.0]);
      expect(result.reduce((a, b) => a + b), closeTo(1.0, 1e-6));
    });

    test('_softmax with single large value approaches 1.0 for that element', () {
      final svc = PassiveLivenessService();
      final result = svc.debugSoftmax([100.0, 0.0, 0.0]);
      expect(result[0], closeTo(1.0, 1e-6));
      expect(result[1], closeTo(0.0, 1e-6));
    });

    test('_faceBoxPixels returns valid pixel rect from ROI map', () {
      final svc = PassiveLivenessService();
      final rois = <String, List<double>>{
        'forehead': [0.5, 0.2, 0.05],
        'right_cheek': [0.35, 0.6, 0.05],
        'left_cheek': [0.65, 0.6, 0.05],
        'nose': [0.5, 0.5, 0.04],
        'lips': [0.5, 0.75, 0.05],
      };
      final box = svc.debugFaceBoxPixels(rois, 100, 100);
      expect(box, isNotNull);
      expect(box!.length, 4);
      expect(box[2], greaterThan(0)); // width > 0
      expect(box[3], greaterThan(0)); // height > 0
    });

    test('_faceBoxPixels returns null when required ROI keys are missing', () {
      final svc = PassiveLivenessService();
      expect(svc.debugFaceBoxPixels({}, 100, 100), isNull);
    });

    test('_faceBoxPixels returns null when face width is degenerate (w <= 1)', () {
      final svc = PassiveLivenessService();
      // Both cheeks at same x → width = 0 → should return null.
      final rois = <String, List<double>>{
        'forehead': [0.5, 0.1, 0.05],
        'right_cheek': [0.5, 0.6, 0.05],
        'left_cheek': [0.5, 0.6, 0.05], // same x as right_cheek
        'nose': [0.5, 0.5, 0.04],
        'lips': [0.5, 0.9, 0.05],
      };
      expect(svc.debugFaceBoxPixels(rois, 100, 100), isNull);
    });

    test('_faceBoxPixels clamps coordinates to image bounds', () {
      final svc = PassiveLivenessService();
      final rois = <String, List<double>>{
        'forehead': [0.5, -0.5, 0.05],
        'right_cheek': [-0.1, 0.6, 0.05],
        'left_cheek': [1.1, 0.6, 0.05],
        'nose': [0.5, 0.5, 0.04],
        'lips': [0.5, 1.5, 0.05],
      };
      final box = svc.debugFaceBoxPixels(rois, 100, 100);
      if (box != null) {
        expect(box[0], greaterThanOrEqualTo(0));
        expect(box[1], greaterThanOrEqualTo(0));
      }
    });

    test('_scaledCrop returns valid crop from a real image', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 100, height: 100);
      final box = [20, 20, 40, 40]; // x, y, w, h
      final cropped = svc.debugScaledCrop(image, box, 1.5);
      expect(cropped, isNotNull);
      expect(cropped!.width, greaterThan(0));
      expect(cropped.height, greaterThan(0));
    });

    test('_scaledCrop returns null when bbox is degenerate', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 10, height: 10);
      // bbox [0, 0, 1, 1] with scale 0 → degenerate crop
      final cropped = svc.debugScaledCrop(image, [5, 5, 0, 0], 1.0);
      expect(cropped, isNull);
    });

    test('_scaledCrop repositions crops that extend past the top-left edge', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 100, height: 100);

      final cropped = svc.debugScaledCrop(image, [0, 0, 20, 20], 2.7);

      expect(cropped, isNotNull);
      expect(cropped!.width, greaterThan(0));
      expect(cropped.height, greaterThan(0));
    });

    test('_scaledCrop repositions crops that extend past the bottom-right edge', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 100, height: 100);

      final cropped = svc.debugScaledCrop(image, [80, 80, 20, 20], 2.7);

      expect(cropped, isNotNull);
      expect(cropped!.width, greaterThan(0));
      expect(cropped.height, greaterThan(0));
    });

    test('_preprocess NHWC produces buffer of correct size', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 80, height: 80);
      final buf = svc.debugPreprocess(image, nchw: false);
      // NHWC: 80*80*3 float32 = 80*80*3*4 bytes
      expect(buf.lengthInBytes, 80 * 80 * 3 * 4);
    });

    test('_preprocess NCHW produces buffer of correct size', () {
      final svc = PassiveLivenessService();
      final image = img.Image(width: 80, height: 80);
      final buf = svc.debugPreprocess(image, nchw: true);
      expect(buf.lengthInBytes, 80 * 80 * 3 * 4);
    });

    test('_preprocess NCHW lays out channels as planes', () {
      final svc = PassiveLivenessService();
      // All-blue image: R=0, G=0, B=255.
      final image = img.Image(width: 80, height: 80);
      image.setPixelRgb(0, 0, 0, 0, 255);
      final buf = svc.debugPreprocess(image, nchw: true);
      final floats = buf.asFloat32List();
      // NCHW: plane 0 = B (index 0), plane 1 = G (index 80*80), plane 2 = R (index 2*80*80).
      expect(floats[0], closeTo(255.0, 1e-6)); // B plane first pixel
      expect(floats[80 * 80], closeTo(0.0, 1e-6)); // G plane first pixel
      expect(floats[2 * 80 * 80], closeTo(0.0, 1e-6)); // R plane first pixel
    });

    test('_preprocess swaps R and B channels (BGR order)', () {
      final svc = PassiveLivenessService();
      // 80×80 red image (R=255, G=0, B=0) — _preprocess expects _inputSize×_inputSize.
      final image = img.Image(width: 80, height: 80);
      image.setPixelRgb(0, 0, 255, 0, 0);
      final buf = svc.debugPreprocess(image, nchw: false);
      final floats = buf.asFloat32List();
      // NHWC: [B, G, R] → B=0, G=0, R=255
      expect(floats[0], closeTo(0.0, 1e-6)); // B channel
      expect(floats[1], closeTo(0.0, 1e-6)); // G channel
      expect(floats[2], closeTo(255.0, 1e-6)); // R channel
    });
  });

  group('PassiveLivenessService — ROI and crop helpers', () {
    test('debugExtractRois returns null when landmarks are empty', () {
      final svc = PassiveLivenessService();

      final result = FaceLandmarkerResult(
        landmarks: const <List<NormalizedLandmark>>[],
        blendshapes: const <List<Category>>[],
      );

      expect(svc.debugExtractRois(result), isNull);
    });

    test('debugExtractRois returns all expected ROI keys', () {
      final svc = PassiveLivenessService();

      final rois = svc.debugExtractRois(_face().result);

      expect(rois, isNotNull);
      expect(rois!.keys, containsAll(<String>['forehead', 'right_cheek', 'left_cheek', 'nose', 'lips']));
    });

    test('debugCropFaceForBigSmall returns appearance and motion crops', () {
      final svc = PassiveLivenessService();
      final rois = <String, List<double>>{
        'forehead': <double>[0.5, 0.2, 0.05],
        'right_cheek': <double>[0.35, 0.6, 0.05],
        'left_cheek': <double>[0.65, 0.6, 0.05],
        'nose': <double>[0.5, 0.5, 0.04],
        'lips': <double>[0.5, 0.75, 0.05],
      };

      final crops = svc.debugCropFaceForBigSmall(img.Image(width: 100, height: 100), rois);

      expect(crops, isNotNull);
      expect(crops!.$1.width, 144);
      expect(crops.$1.height, 144);
      expect(crops.$2.width, 9);
      expect(crops.$2.height, 9);
    });

    test('debugCropFaceForBigSmall returns null when required ROI keys are missing', () {
      final svc = PassiveLivenessService();

      expect(svc.debugCropFaceForBigSmall(img.Image(width: 100, height: 100), <String, List<double>>{}), isNull);
    });

    test('debugCropFaceForBigSmall returns null for degenerate crop', () {
      final svc = PassiveLivenessService();
      final rois = <String, List<double>>{
        'forehead': <double>[0.5, 0.5, 0.0],
        'right_cheek': <double>[0.5, 0.5, 0.0],
        'left_cheek': <double>[0.5, 0.5, 0.0],
        'nose': <double>[0.5, 0.5, 0.0],
        'lips': <double>[0.5, 0.5, 0.0],
      };

      expect(svc.debugCropFaceForBigSmall(img.Image(width: 100, height: 100), rois), isNull);
    });
  });

  group('PassiveLivenessService — direct BVP helpers', () {
    test('debugEvaluateBvpSamples returns empty failing result for empty samples', () {
      final svc = PassiveLivenessService();

      final result = svc.debugEvaluateBvpSamples(const <double>[], 30);

      expect(result.hr, isNull);
      expect(result.passed, isFalse);
      expect(result.sampleCount, 0);
      expect(result.durationMs, 0);
    });

    test('debugEvaluateBvpSamples returns empty failing result when fps is zero', () {
      final svc = PassiveLivenessService();

      final result = svc.debugEvaluateBvpSamples(<double>[1.0, 0.0, 1.0], 0);

      expect(result.hr, isNull);
      expect(result.passed, isFalse);
      expect(result.sampleCount, 0);
      expect(result.durationMs, 0);
    });

    test('debugEstimateHeartRate returns null for fewer than three samples', () {
      final svc = PassiveLivenessService();

      expect(svc.debugEstimateHeartRate(<double>[1.0, 0.0], 30), isNull);
    });

    test('debugEstimateHeartRate returns null when there are not enough peaks', () {
      final svc = PassiveLivenessService();

      expect(svc.debugEstimateHeartRate(<double>[0.0, 1.0, 0.0, 0.0, 0.0], 30), isNull);
    });

    test('debugEstimateHeartRate returns null when peak intervals are outside valid range', () {
      final svc = PassiveLivenessService();
      final signal = List<double>.filled(70, 0.0)
        ..[1] = 1.0
        ..[60] = 1.0;

      expect(svc.debugEstimateHeartRate(signal, 30), isNull);
    });

    test('debugFindPeaks finds local maxima respecting min distance', () {
      final svc = PassiveLivenessService();

      final peaks = svc.debugFindPeaks(<double>[0.0, 1.0, 0.0, 0.5, 0.0, 1.2, 0.0], 3);

      expect(peaks, <int>[1, 5]);
    });

    test('debugFindPeaks replaces nearby lower peak with stronger peak', () {
      final svc = PassiveLivenessService();

      final peaks = svc.debugFindPeaks(<double>[0.0, 0.8, 0.0, 1.2, 0.0], 3);

      expect(peaks, <int>[3]);
    });
  });

  group('PassiveLivenessService — collectPassiveMetrics (no TFLite)', () {
    // Without initialize(), TFLite interpreters are null.
    // _scoreFrame() hits the null guard and returns immediately.
    // _sampleRppg() still runs _extractRois() and _cropFaceForBigSmall().

    test('does not crash when service is not initialised', () {
      final svc = PassiveLivenessService();
      // Call many times to cover both branches of the anti-spoof sampling rate.
      for (var i = 0; i < 20; i++) {
        svc.collectPassiveMetrics(_frame(), _face());
      }
    });

    test('does not crash for empty landmark data', () {
      final svc = PassiveLivenessService();
      final face = FaceObservation(
        result: FaceLandmarkerResult(
          landmarks: const <List<NormalizedLandmark>>[],
          blendshapes: const <List<Category>>[],
        ),
        boundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        boundingBoxAreaRatio: 0.0,
        boundingBoxCenter: const Offset(0.5, 0.5),
        mouthRatio: 0.0,
        yawDegrees: 0.0,
        blendshapeScores: const <String, double>{},
        alignedFace112: img.Image(width: 112, height: 112),
      );

      svc.collectPassiveMetrics(_frame(), face);

      expect(svc.getAntiSpoofScore(), isNull);
      expect(svc.debugEvaluateBvp(), isNull);
    });

    test('high-yaw face causes rPPG sampling to be skipped', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 5; i++) {
        svc.collectPassiveMetrics(_frame(), _face(yaw: 20));
      }
      expect(svc.debugEvaluateBvp(), isNull);
    });

    test('injected anti-spoof score is collected for sampled frontal faces', () {
      final svc = PassiveLivenessService(random: const _FixedRandom(0.0), antiSpoofScoreOverride: (_, _) => 0.82);

      svc.collectPassiveMetrics(_frame(), _face());

      expect(svc.getAntiSpoofScore(), closeTo(0.82, 1e-9));
    });

    test('high-yaw faces skip the injected anti-spoof scorer', () {
      var calls = 0;
      final svc = PassiveLivenessService(
        random: const _FixedRandom(0.0),
        antiSpoofScoreOverride: (_, _) {
          calls++;
          return 0.9;
        },
      );

      svc.collectPassiveMetrics(_frame(), _face(yaw: 30));

      expect(calls, 0);
      expect(svc.getAntiSpoofScore(), isNull);
    });

    test('frontal frames fill rPPG buffer without crashing', () {
      final svc = PassiveLivenessService();
      // More than bufferFrames (4) to trigger the inference path (returns null,
      // buffer cleared) — covers _cropFaceForBigSmall and frame buffer logic.
      for (var i = 0; i < 10; i++) {
        svc.collectPassiveMetrics(_frame(), _face());
      }
    });

    test('injected BigSmall BVP samples are added after a four-frame batch', () {
      var now = 1000;
      final svc = PassiveLivenessService(
        nowMs: () => now,
        bigSmallBvpOverride: (batchLength) => List<double>.generate(batchLength - 1, (i) => math.sin(i * math.pi / 2)),
      );

      for (var i = 0; i < 20; i++) {
        now = 1000 + i * 150;
        svc.collectPassiveMetrics(_frame(), _face());
      }

      final result = svc.debugEvaluateBvp();
      expect(result, isNotNull);
      expect(result!.sampleCount, greaterThanOrEqualTo(15));
    });

    test('rPPG frame buffer is cleared after a long frame gap', () {
      var now = 1000;
      var inferenceCalls = 0;
      final svc = PassiveLivenessService(
        nowMs: () => now,
        bigSmallBvpOverride: (batchLength) {
          inferenceCalls++;
          return List<double>.filled(batchLength - 1, 0.0);
        },
      );

      svc.collectPassiveMetrics(_frame(), _face());
      now = 1100;
      svc.collectPassiveMetrics(_frame(), _face());
      now = 2500;
      svc.collectPassiveMetrics(_frame(), _face());

      expect(inferenceCalls, 0);

      for (var i = 0; i < 3; i++) {
        now += 100;
        svc.collectPassiveMetrics(_frame(), _face());
      }

      expect(inferenceCalls, 1);
    });

    test('reset after collectPassiveMetrics clears rPPG state', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 3; i++) {
        svc.collectPassiveMetrics(_frame(), _face());
      }
      svc.reset();
      expect(svc.debugEvaluateBvp(), isNull);
    });

    test('dispose does not crash when interpreters were never initialised', () async {
      await PassiveLivenessService().dispose();
    });

    test('dispose is idempotent when interpreters were never initialised', () async {
      final svc = PassiveLivenessService();

      await svc.dispose();
      await svc.dispose();
    });

    group('PassiveLivenessService — BigSmall preprocessing helpers', () {
      img.Image solidImage({required int width, required int height, required int r, required int g, required int b}) {
        final image = img.Image(width: width, height: height);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            image.setPixelRgb(x, y, r, g, b);
          }
        }
        return image;
      }

      test('debugBuildBigSmallAppearanceBuffer has expected length', () {
        final svc = PassiveLivenessService();

        final frames = List<img.Image>.generate(4, (_) => solidImage(width: 144, height: 144, r: 255, g: 128, b: 0));

        final buf = svc.debugBuildBigSmallAppearanceBuffer(frames);

        expect(buf.length, 3 * 3 * 144 * 144);
      });

      test('debugBuildBigSmallAppearanceBuffer packs frames 1..3 as planar RGB normalized values', () {
        final svc = PassiveLivenessService();

        final frames = <img.Image>[
          solidImage(width: 144, height: 144, r: 0, g: 0, b: 0),
          solidImage(width: 144, height: 144, r: 255, g: 0, b: 0),
          solidImage(width: 144, height: 144, r: 0, g: 255, b: 0),
          solidImage(width: 144, height: 144, r: 0, g: 0, b: 255),
        ];

        final buf = svc.debugBuildBigSmallAppearanceBuffer(frames);
        const planeSize = 144 * 144;

        // Frame 1, R plane starts at 0.
        expect(buf[0], closeTo(1.0, 1e-6));
        expect(buf[planeSize], closeTo(0.0, 1e-6));
        expect(buf[2 * planeSize], closeTo(0.0, 1e-6));

        // Frame 2 starts after 3 planes.
        final frame2Offset = 3 * planeSize;
        expect(buf[frame2Offset], closeTo(0.0, 1e-6));
        expect(buf[frame2Offset + planeSize], closeTo(1.0, 1e-6));
        expect(buf[frame2Offset + 2 * planeSize], closeTo(0.0, 1e-6));
      });

      test('debugBuildBigSmallMotionBuffer has expected length', () {
        final svc = PassiveLivenessService();

        final frames = List<img.Image>.generate(4, (_) => solidImage(width: 9, height: 9, r: 10, g: 20, b: 30));

        final buf = svc.debugBuildBigSmallMotionBuffer(frames);

        expect(buf.length, 3 * 3 * 9 * 9);
      });

      test('debugBuildBigSmallMotionBuffer is zero for identical consecutive frames', () {
        final svc = PassiveLivenessService();

        final frames = List<img.Image>.generate(4, (_) => solidImage(width: 9, height: 9, r: 50, g: 50, b: 50));

        final buf = svc.debugBuildBigSmallMotionBuffer(frames);

        expect(buf.every((v) => v.abs() < 1e-6), isTrue);
      });

      test('debugBuildBigSmallMotionBuffer computes normalized frame difference', () {
        final svc = PassiveLivenessService();

        final frames = <img.Image>[
          solidImage(width: 9, height: 9, r: 10, g: 10, b: 10),
          solidImage(width: 9, height: 9, r: 30, g: 30, b: 30),
          solidImage(width: 9, height: 9, r: 30, g: 30, b: 30),
          solidImage(width: 9, height: 9, r: 30, g: 30, b: 30),
        ];

        final buf = svc.debugBuildBigSmallMotionBuffer(frames);

        // (30 - 10) / (30 + 10 + eps) ~= 0.5
        expect(buf.first, closeTo(0.5, 1e-5));
      });

      test('debugBigSmallRunInferenceWithImages returns null for wrong batch length', () {
        final svc = PassiveLivenessService();

        final result = svc.debugBigSmallRunInferenceWithImages(
          appearances: <img.Image>[solidImage(width: 144, height: 144, r: 0, g: 0, b: 0)],
          motions: <img.Image>[solidImage(width: 9, height: 9, r: 0, g: 0, b: 0)],
          timestampsMs: const <int>[0],
        );

        expect(result, isNull);
      });

      test('debugBigSmallRunInferenceWithImages returns null when no interpreters are loaded', () {
        final svc = PassiveLivenessService();

        final result = svc.debugBigSmallRunInferenceWithImages(
          appearances: List<img.Image>.generate(4, (_) => solidImage(width: 144, height: 144, r: 0, g: 0, b: 0)),
          motions: List<img.Image>.generate(4, (_) => solidImage(width: 9, height: 9, r: 0, g: 0, b: 0)),
          timestampsMs: const <int>[0, 1, 2, 3],
        );

        expect(result, isNull);
      });

      test('debugBigSmallRunInferenceWithImages averages non-empty debug model outputs', () {
        final svc = PassiveLivenessService(
          bigSmallModelOutputOverride: (modelIndex, appearanceBuf, motionBuf, outputShape) {
            expect(outputShape, <int>[1, 3]);
            expect(appearanceBuf.length, 3 * 3 * 144 * 144);
            expect(motionBuf.length, 3 * 3 * 9 * 9);

            return switch (modelIndex) {
              0 => <double>[1.0, 2.0, 3.0],
              1 => <double>[4.0, 5.0, 6.0],
              _ => <double>[],
            };
          },
        );
        svc.debugSetBigSmallOutputShapes(<List<int>?>[
          <int>[1, 3],
          <int>[1, 3],
          <int>[1, 3],
        ]);

        final result = svc.debugBigSmallRunInferenceWithImages(
          appearances: List<img.Image>.generate(4, (_) => solidImage(width: 144, height: 144, r: 0, g: 0, b: 0)),
          motions: List<img.Image>.generate(4, (_) => solidImage(width: 9, height: 9, r: 0, g: 0, b: 0)),
          timestampsMs: const <int>[0, 1, 2, 3],
        );

        expect(result, <double>[2.5, 3.5, 4.5]);
      });

      test('debugBigSmallRunInferenceWithImages returns null when every debug model output is empty', () {
        final svc = PassiveLivenessService(bigSmallModelOutputOverride: (_, __, ___, ____) => <double>[]);
        svc.debugSetBigSmallOutputShapes(<List<int>?>[
          <int>[1, 3],
          <int>[1, 3],
          <int>[1, 3],
        ]);

        final result = svc.debugBigSmallRunInferenceWithImages(
          appearances: List<img.Image>.generate(4, (_) => solidImage(width: 144, height: 144, r: 0, g: 0, b: 0)),
          motions: List<img.Image>.generate(4, (_) => solidImage(width: 9, height: 9, r: 0, g: 0, b: 0)),
          timestampsMs: const <int>[0, 1, 2, 3],
        );

        expect(result, isNull);
      });

      test('collectPassiveMetrics trims retained BVP samples to 900', () {
        var now = 1000;
        final svc = PassiveLivenessService(
          nowMs: () => now,
          bigSmallBvpOverride: (batchLength) => List<double>.filled(batchLength - 1, 0.25),
        );

        for (var i = 0; i < 1400; i++) {
          now = 1000 + i * 150;
          svc.collectPassiveMetrics(_frame(), _face());
        }

        final result = svc.debugEvaluateBvp();
        expect(result, isNotNull);
        expect(result!.sampleCount, 900);
      });
    });
  });
}
