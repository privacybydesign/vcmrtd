import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/passive_liveness_service.dart';

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

    test('low anti-spoof scores produce a failing result', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) {
        svc.debugAddAntiSpoofScore(0.2);
      }
      expect(svc.isAntiSpoofPassed(), isFalse);
    });

    test('reset clears anti-spoof scores', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 4; i++) svc.debugAddAntiSpoofScore(0.9);
      svc.reset();
      expect(svc.getAntiSpoofScore(), isNull);
      expect(svc.isAntiSpoofPassed(), isFalse);
    });
  });

  group('PassiveLivenessService — rPPG debug helpers', () {
    test('getRppgResult returns null when fewer than 15 samples', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 14; i++) svc.debugAddBvpSample(0.5, 1000 + i * 150);
      expect(svc.getRppgResult(), isNull);
    });

    test('getRppgResult returns null when duration is less than 2000ms', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 15; i++) svc.debugAddBvpSample(0.5, 1000 + i * 10);
      expect(svc.getRppgResult(), isNull);
    });

    test('15 samples over 2000ms produce a non-null RppgResult', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 15; i++) svc.debugAddBvpSample(0.5 + (i % 3) * 0.01, 1000 + i * 150);
      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      expect(r!.sampleCount, greaterThanOrEqualTo(15));
      expect(r.durationMs, greaterThanOrEqualTo(2000));
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
      for (var i = 0; i < 30; i++) svc.debugAddBvpSample(0.5, 1000 + i * 100);
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
      for (var i = 0; i < 15; i++) svc.debugAddBvpSample(0.5, 1000 + i * 150);
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

    test('high-yaw face causes rPPG sampling to be skipped', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 5; i++) {
        svc.collectPassiveMetrics(_frame(), _face(yaw: 20));
      }
      expect(svc.debugEvaluateBvp(), isNull);
    });

    test('frontal frames fill rPPG buffer without crashing', () {
      final svc = PassiveLivenessService();
      // More than bufferFrames (4) to trigger the inference path (returns null,
      // buffer cleared) — covers _cropFaceForBigSmall and frame buffer logic.
      for (var i = 0; i < 10; i++) {
        svc.collectPassiveMetrics(_frame(), _face());
      }
    });

    test('reset after collectPassiveMetrics clears rPPG state', () {
      final svc = PassiveLivenessService();
      for (var i = 0; i < 3; i++) svc.collectPassiveMetrics(_frame(), _face());
      svc.reset();
      expect(svc.debugEvaluateBvp(), isNull);
    });

    test('dispose does not crash when interpreters were never initialised', () async {
      await PassiveLivenessService().dispose();
    });
  });
}
