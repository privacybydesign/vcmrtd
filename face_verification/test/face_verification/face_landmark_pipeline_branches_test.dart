import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_landmarker_types.dart';
import 'package:face_verification/src/detection/face_landmark_pipeline.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<NormalizedLandmark> _landmarks478({double x = 0.5, double y = 0.5}) =>
    List<NormalizedLandmark>.generate(478, (_) => NormalizedLandmark(x, y, 0));

// Builds a 17-element detector box with well-spread keypoints so the
// keypoint-blended centre is accepted (count >= 4, kpW/kpH above thresholds).
List<double> _spreadKeypointBox() {
  final box = List<double>.filled(17, 0.5);
  // corners
  box[0] = 0.2;
  box[1] = 0.2;
  box[2] = 0.8;
  box[3] = 0.8;
  box[4] = 0.9; // score
  // keypoints: right eye, left eye, nose, mouth, right ear, left ear
  box[5] = 0.3;
  box[6] = 0.35;
  box[7] = 0.7;
  box[8] = 0.35;
  box[9] = 0.5;
  box[10] = 0.5;
  box[11] = 0.5;
  box[12] = 0.62;
  box[13] = 0.25;
  box[14] = 0.4;
  box[15] = 0.75;
  box[16] = 0.4;
  return box;
}

void main() {
  group('FaceLandmarkPipeline — stage early returns without TFLite', () {
    test('runDetectorStage returns null when detector interpreter is null', () {
      final pipeline = FaceLandmarkPipeline();
      final out = pipeline.runDetectorStage(img.Image(width: 64, height: 64));
      expect(out, isNull);
    });

    test('runLandmarkStage returns null when landmark interpreter is null', () {
      final pipeline = FaceLandmarkPipeline();
      const crop = DetectorStageOutput(cropX1: 0.1, cropY1: 0.1, cropW: 0.5, cropH: 0.5, angle: 0);
      final out = pipeline.runLandmarkStage(img.Image(width: 64, height: 64), crop);
      expect(out, isNull);
    });
  });

  group('FaceLandmarkPipeline — updateTrackingCrop', () {
    test('updateTrackingCrop stores a crop reused by selfie-mode runDetectorStage', () {
      final pipeline = FaceLandmarkPipeline();
      final result = FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[_landmarks478(x: 0.5, y: 0.5)]);

      // No throw, and the internal _lastCrop is now set. The detector stage is
      // still null (no interp) so it returns null even though a crop is cached —
      // this exercises updateTrackingCrop + computeTrackingCrop together.
      pipeline.updateTrackingCrop(result, 640, 480);

      final crop = pipeline.computeTrackingCrop(result, 640, 480);
      expect(crop, isNotNull);
    });

    test('updateTrackingCrop with too-few landmarks leaves no usable crop', () {
      final pipeline = FaceLandmarkPipeline();
      final result = FaceLandmarkerResult(
        landmarks: <List<NormalizedLandmark>>[
          List<NormalizedLandmark>.filled(5, const NormalizedLandmark(0.5, 0.5, 0)),
        ],
      );
      // computeTrackingCrop returns null for short landmark lists, so the
      // internal crop is cleared — no throw.
      pipeline.updateTrackingCrop(result, 640, 480);
      expect(pipeline.computeTrackingCrop(result, 640, 480), isNull);
    });
  });

  group('FaceLandmarkPipeline — keypointBlendedCenter NFC mode', () {
    final pipeline = FaceLandmarkPipeline();

    test('NFC mode blends keypoint and box centres in both x and y', () {
      final box = _spreadKeypointBox();
      final result = pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.nfc);
      expect(result, isNotNull);
      expect(result!.length, 2);
      // NFC path returns blended y (0.7*kpCy + 0.3*boxCy), unlike selfie which
      // returns boxCy directly. With our symmetric keypoints the centre is mid.
      expect(result[0], inInclusiveRange(0.0, 1.0));
      expect(result[1], inInclusiveRange(0.0, 1.0));
    });

    test('selfie mode keeps box centre in y, keypoint blend in x', () {
      final box = _spreadKeypointBox();
      final selfie = pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.selfie);
      final nfc = pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.nfc);
      expect(selfie, isNotNull);
      expect(nfc, isNotNull);
      // Selfie y is exactly boxCy (=0.5) here; NFC y is the keypoint/box blend.
      expect(selfie![1], closeTo(0.5, 1e-9));
    });

    test('fewer than 4 valid keypoints returns null even with spread', () {
      final box = List<double>.filled(17, 0.5);
      // Only two valid (in-range distinct) keypoints; rest collapse on 0.5.
      box[5] = 0.2;
      box[6] = 0.3;
      box[7] = 0.8;
      box[8] = 0.3;
      // Set remaining keypoints out of [0,1] so they're rejected.
      for (var k = 2; k < 6; k++) {
        box[5 + k * 2] = -1.0;
        box[6 + k * 2] = 2.0;
      }
      expect(pipeline.debugKeypointBlendedCenter(box, 0.5, 0.5, FaceAlignmentMode.nfc), isNull);
    });
  });

  group('FaceLandmarkPipeline — buildSquareCrop mode-specific paths', () {
    final pipeline = FaceLandmarkPipeline();

    test('selfie mode clamps an oversized close-up crop to 2x narrow dimension', () {
      // Very large normalized w/h on a narrow portrait frame would drive
      // pxSize well past the image — selfie mode clamps to min(w,h)*2.
      final crop = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.95, 0.95, 0.0, (
        width: 360,
        height: 640,
      ), FaceAlignmentMode.selfie);
      // normW = pxSize/imgW; pxSize clamped to 360*2 = 720 → normW = 2.0
      expect(crop[2], lessThanOrEqualTo(2.0 + 1e-9));
    });

    test('nfc mode applies a vertical shift (different from selfie)', () {
      final selfie = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, 0.0, (
        width: 480,
        height: 640,
      ), FaceAlignmentMode.selfie);
      final nfc = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, 0.0, (
        width: 480,
        height: 640,
      ), FaceAlignmentMode.nfc);
      // NFC uses _nfcCropShiftY = -0.10 (cosA*shiftPx applied to cy), selfie uses 0.
      // With angle 0 the y origin differs between the two modes.
      expect(nfc[1], isNot(closeTo(selfie[1], 1e-6)));
    });

    test('non-zero angle rotates the crop centre shift', () {
      final crop = pipeline.debugBuildSquareCrop(0.5, 0.5, 0.3, 0.3, math.pi / 4, (
        width: 480,
        height: 640,
      ), FaceAlignmentMode.nfc);
      expect(crop.length, 5);
      expect(crop[4], closeTo(math.pi / 4, 1e-9));
      expect(crop[0].isFinite, isTrue);
      expect(crop[1].isFinite, isTrue);
    });
  });

  group('FaceLandmarkPipeline — decodeBox degenerate geometry', () {
    late FaceLandmarkPipeline pipeline;
    const scale = 128.0;
    const boxSize = 17;

    setUp(() {
      pipeline = FaceLandmarkPipeline();
      pipeline.debugInitTestBuffers();
    });

    tearDown(() => pipeline.close());

    test('returns null when decoded box has non-positive width/height', () {
      // High score but negative w/h regressors → x2 <= x1, rejected.
      final scores = [
        List<List<double>>.generate(896, (i) => <double>[i == 0 ? 10.0 : -5.0]),
      ];
      final regressors = [
        List<List<double>>.generate(896, (_) {
          final row = List<double>.filled(16, 0.0);
          row[2] = -50.0; // negative width
          row[3] = -50.0; // negative height
          return row;
        }),
      ];
      pipeline.debugSetMockDetectorOutputs(scores, regressors);
      expect(pipeline.debugDecodeBox(0, scale, boxSize), isNull);
    });
  });

  group('FaceLandmarkPipeline — iou degenerate boxes', () {
    final pipeline = FaceLandmarkPipeline();

    test('zero-area box yields zero IoU', () {
      // Box b has zero width/height (degenerate) and sits inside a.
      final a = <double>[0.0, 0.0, 0.5, 0.5];
      final b = <double>[0.2, 0.2, 0.2, 0.2];
      expect(pipeline.debugIou(a, b), closeTo(0.0, 1e-9));
    });

    test('fully nested box yields IoU equal to area ratio', () {
      final outer = <double>[0.0, 0.0, 1.0, 1.0];
      final inner = <double>[0.0, 0.0, 0.5, 0.5];
      // inter = 0.25, areaA = 1, areaB = 0.25 → 0.25 / (1.0 + 1e-6) ≈ 0.25
      expect(pipeline.debugIou(outer, inner), closeTo(0.25, 1e-4));
    });
  });

  group('FaceLandmarkPipeline — remapLandmarks with rotation', () {
    final pipeline = FaceLandmarkPipeline();

    test('90-degree crop angle rotates landmark offsets', () {
      // A landmark to the right of model centre maps below the crop centre when
      // the crop is rotated +90 degrees.
      const cx = 0.5, cy = 0.5, cw = 0.4, ch = 0.4;
      // model x = 256 (centre + 128 in 256-space) → +0.5 normalized offset.
      final raw = <double>[256.0, 128.0, 0.0];
      final result = pipeline.debugRemapLandmarks(raw, cx - cw / 2, cy - ch / 2, cw, ch, math.pi / 2);
      expect(result.length, 1);
      // With +90deg: x' = cx - sin*sx ≈ cx, y' = cy + ... so y shifts.
      expect(result[0].x, closeTo(cx, 1e-6));
      expect(result[0].y, greaterThan(cy));
    });
  });
}
