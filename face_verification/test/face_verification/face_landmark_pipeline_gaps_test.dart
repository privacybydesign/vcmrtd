import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_landmark_pipeline.dart';
import 'package:face_verification/src/detection/face_landmarker_types.dart';

// ---------------------------------------------------------------------------
// These tests load the real TFLite model assets via Interpreter.fromBuffer
// (which works in the flutter_test VM) and drive the full detector → landmark
// → blendshape pipeline on a deterministic synthetic face image. This exercises
// the initialize / warm-up / inference / crop / close paths that the existing
// math-only and mock-output suites never reach. The native face_frame_buffer
// FFI is NOT used here, so everything stays test-VM safe.
// ---------------------------------------------------------------------------

Future<Uint8List> _load(String name) async {
  final data = await rootBundle.load('packages/face_verification/lib/src/models/$name');
  return data.buffer.asUint8List();
}

// A simple face-like 128×128 image that the MediaPipe detector reliably
// detects (verified empirically). Larger sizes do not detect, so keep 128.
img.Image _faceImage() {
  const w = 128, h = 128;
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 180, 160));
  img.fillCircle(im, x: w ~/ 2, y: h ~/ 2, radius: (w * 0.3).round(), color: img.ColorRgb8(220, 190, 170));
  img.fillCircle(
    im,
    x: (w * 0.4).round(),
    y: (h * 0.42).round(),
    radius: (w * 0.04).round(),
    color: img.ColorRgb8(30, 30, 30),
  );
  img.fillCircle(
    im,
    x: (w * 0.6).round(),
    y: (h * 0.42).round(),
    radius: (w * 0.04).round(),
    color: img.ColorRgb8(30, 30, 30),
  );
  img.fillCircle(
    im,
    x: (w * 0.5).round(),
    y: (h * 0.55).round(),
    radius: (w * 0.03).round(),
    color: img.ColorRgb8(180, 150, 130),
  );
  img.fillRect(
    im,
    x1: (w * 0.42).round(),
    y1: (h * 0.66).round(),
    x2: (w * 0.58).round(),
    y2: (h * 0.70).round(),
    color: img.ColorRgb8(150, 80, 80),
  );
  return im;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FaceLandmarkPipeline — full inference with real models', () {
    late FaceLandmarkPipeline pipeline;
    late img.Image face;

    setUp(() async {
      pipeline = FaceLandmarkPipeline();
      pipeline.initializeFromBuffers(
        detector: await _load('face_detector.tflite'),
        landmarks: await _load('face_landmarks_detector.tflite'),
        blendshapes: await _load('face_blendshapes.tflite'),
      );
      face = _faceImage();
    });

    tearDown(() => pipeline.close());

    test('initializeFromBuffers is idempotent (second call is a no-op)', () async {
      // Second initialize should early-return because _detectorInterp != null.
      // Passing throwaway bytes that would fail to parse proves it never reloads.
      pipeline.initializeFromBuffers(
        detector: Uint8List.fromList(<int>[0, 1, 2]),
        landmarks: Uint8List.fromList(<int>[0, 1, 2]),
        blendshapes: Uint8List.fromList(<int>[0, 1, 2]),
      );
      // Still functional after the no-op call.
      final crop = pipeline.runDetectorStage(face);
      expect(crop, isNotNull);
    });

    test('runDetectorStage (selfie) detects a face and returns a finite crop', () {
      final crop = pipeline.runDetectorStage(face, mode: FaceAlignmentMode.selfie);
      expect(crop, isNotNull);
      expect(crop!.cropW, greaterThan(0));
      expect(crop.cropH, greaterThan(0));
      expect(crop.cropX1.isFinite, isTrue);
      expect(crop.cropY1.isFinite, isTrue);
      expect(crop.angle.isFinite, isTrue);
    });

    test('runDetectorStage (nfc) detects a face and returns a crop', () {
      final crop = pipeline.runDetectorStage(face, mode: FaceAlignmentMode.nfc);
      expect(crop, isNotNull);
      expect(crop!.cropW, greaterThan(0));
      expect(crop.cropH, greaterThan(0));
    });

    test('runLandmarkStage produces 478 landmarks, blendshapes and a pose matrix', () {
      final crop = pipeline.runDetectorStage(face)!;
      final result = pipeline.runLandmarkStage(face, crop, runBlendshapes: true);
      expect(result, isNotNull);
      expect(result!.landmarks.first.length, 478);
      expect(result.blendshapes, isNotNull);
      expect(result.blendshapes!.first.length, 52);
      expect(result.transformMatrices, isNotNull);
      expect(result.transformMatrices!.first.length, 16);
    });

    test('runLandmarkStage with runBlendshapes:false skips blendshapes', () {
      final crop = pipeline.runDetectorStage(face)!;
      final result = pipeline.runLandmarkStage(face, crop, runBlendshapes: false);
      expect(result, isNotNull);
      expect(result!.landmarks.first.length, 478);
      expect(result.blendshapes, isNull);
    });

    test('selfie-mode tracking crop is cached and reused on the next detector call', () {
      final first = pipeline.runDetectorStage(face)!;
      final result = pipeline.runLandmarkStage(face, first, runBlendshapes: false)!;
      pipeline.updateTrackingCrop(result, face.width, face.height);

      // Next selfie detector call returns the cached tracking crop without
      // re-running the detector model.
      final cached = pipeline.runDetectorStage(face, mode: FaceAlignmentMode.selfie);
      expect(cached, isNotNull);
      final tracking = pipeline.computeTrackingCrop(result, face.width, face.height)!;
      expect(cached!.cropX1, closeTo(tracking.cropX1, 1e-9));
      expect(cached.cropW, closeTo(tracking.cropW, 1e-9));
    });

    test('resetTracking forces the detector to re-run instead of reusing the cache', () {
      final result = pipeline.runLandmarkStage(face, pipeline.runDetectorStage(face)!, runBlendshapes: false)!;
      pipeline.updateTrackingCrop(result, face.width, face.height);
      pipeline.resetTracking();

      // After reset, selfie detector re-runs the model and still finds the face.
      final crop = pipeline.runDetectorStage(face, mode: FaceAlignmentMode.selfie);
      expect(crop, isNotNull);
    });

    test('nfc-mode detector never uses the selfie tracking cache', () {
      // Prime the cache with an obviously wrong crop.
      pipeline.setTrackingCrop(
        const DetectorStageOutput(cropX1: 0.9, cropY1: 0.9, cropW: 0.01, cropH: 0.01, angle: 1.0),
      );
      // NFC ignores the cache (cached = null for nfc) and re-detects.
      final crop = pipeline.runDetectorStage(face, mode: FaceAlignmentMode.nfc);
      expect(crop, isNotNull);
      // The detected crop should differ from the bogus cached one.
      expect(crop!.cropW, isNot(closeTo(0.01, 1e-6)));
    });

    test('runDetectorStage returns null on a blank image with no detectable face', () {
      final blank = img.Image(width: 128, height: 128);
      img.fill(blank, color: img.ColorRgb8(0, 0, 0));
      final crop = pipeline.runDetectorStage(blank, mode: FaceAlignmentMode.nfc);
      expect(crop, isNull);
    });

    test('close() releases interpreters so subsequent stage calls return null', () {
      pipeline.close();
      expect(pipeline.runDetectorStage(face), isNull);
      expect(
        pipeline.runLandmarkStage(
          face,
          const DetectorStageOutput(cropX1: 0.1, cropY1: 0.1, cropW: 0.5, cropH: 0.5, angle: 0),
        ),
        isNull,
      );
      // Double close is safe.
      pipeline.close();
    });
  });

  group('FaceLandmarkPipeline — initialize() via asset loader', () {
    test('initialize loads interpreters and detects a face, second call is a no-op', () async {
      final pipeline = FaceLandmarkPipeline();
      addTearDown(pipeline.close);

      await pipeline.initialize();
      await pipeline.initialize(); // idempotent early-return branch

      final crop = pipeline.runDetectorStage(_faceImage(), mode: FaceAlignmentMode.nfc);
      expect(crop, isNotNull);
    });
  });
}
