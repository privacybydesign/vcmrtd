import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/features/face_verification/worker_result_types.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FaceObservation _makeFace({double yaw = 5.0, double mouthRatio = 0.03}) {
  final landmarks = List<NormalizedLandmark>.generate(478, (i) => NormalizedLandmark(i * 0.001, i * 0.001 + 0.001, 0));
  final blendshapes = <String, double>{'jawOpen': 0.1, 'mouthSmileLeft': 0.2};
  final result = FaceLandmarkerResult(
    landmarks: [landmarks],
    blendshapes: [blendshapes.entries.map((e) => Category(e.key, e.value)).toList()],
  );
  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(10, 20, 100, 120),
    boundingBoxAreaRatio: 0.15,
    boundingBoxCenter: const Offset(0.5, 0.5),
    mouthRatio: mouthRatio,
    yawDegrees: yaw,
    blendshapeScores: blendshapes,
    alignedFace112: img.Image(width: 112, height: 112),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FaceVerificationWorker — instance (no isolates)', () {
    test('frames is a broadcast stream', () {
      final worker = FaceVerificationWorker();
      expect(worker.debugFrames.isBroadcast, isTrue);
    });

    test('debugSessionId starts at 0', () {
      final worker = FaceVerificationWorker();
      expect(worker.debugSessionId, 0);
    });

    test('debugWaitPipelineIdle completes immediately when not busy', () async {
      final worker = FaceVerificationWorker();
      await expectLater(worker.debugWaitPipelineIdle(), completes);
    });

    test('debugWaitPassiveIdle completes immediately when not busy', () async {
      final worker = FaceVerificationWorker();
      await expectLater(worker.debugWaitPassiveIdle(), completes);
    });

    test('debugEmitFrameResult emits null-face result on frames stream', () async {
      final worker = FaceVerificationWorker();
      final future = worker.debugFrames.first;
      worker.debugEmitFrameResult(const WorkerFrameResult(face: null));
      final result = await future;
      expect(result.face, isNull);
    });

    test('debugEmitFrameResult emits non-null face result on frames stream', () async {
      final worker = FaceVerificationWorker();
      final face = _makeFace();
      final future = worker.debugFrames.first;
      worker.debugEmitFrameResult(WorkerFrameResult(face: face));
      final result = await future;
      expect(result.face, isNotNull);
      expect(result.face!.yawDegrees, 5.0);
    });

    test('debugEmitFrameError propagates error on frames stream', () async {
      final worker = FaceVerificationWorker();
      final future = worker.debugFrames.first.catchError((_) => const WorkerFrameResult(face: null));
      worker.debugEmitFrameError(Exception('test error'));
      await future; // just verify it doesnetes without hanging
    });
  });

  group('FaceVerificationWorker — BGRA to RGB conversion', () {
    test('2×1 BGRA pixel converts correctly (channels swapped)', () {
      // One pixel: B=10, G=20, R=30, A=255
      final bgra = Uint8List.fromList([10, 20, 30, 255]);
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 1, 1, 4);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 30); // R from position 2
      expect(bytes[1], 20); // G from position 1
      expect(bytes[2], 10); // B from position 0
    });

    test('output image has correct dimensions', () {
      final bgra = Uint8List(4 * 4 * 4); // 4×4 BGRA
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 4, 4, 16);
      expect(rgb.width, 4);
      expect(rgb.height, 4);
    });

    test('handles row stride padding correctly', () {
      // 2×2 image with 12-byte row stride (2 pixels×4 bytes + 4 bytes padding)
      final bgra = Uint8List(2 * 12);
      bgra[0] = 1;
      bgra[1] = 2;
      bgra[2] = 3; // pixel 0,0: B=1, G=2, R=3
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 2, 2, 12);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 3); // R
      expect(bytes[1], 2); // G
      expect(bytes[2], 1); // B
    });
  });

  group('FaceVerificationWorker — YUV420 to RGB conversion', () {
    test('output image has correct dimensions', () {
      final width = 4, height = 4;
      final yBytes = Uint8List(width * height);
      final uBytes = Uint8List(width * height ~/ 4);
      final vBytes = Uint8List(width * height ~/ 4);
      final planes = [
        {'bytes': yBytes, 'bytesPerRow': width, 'bytesPerPixel': 1},
        {'bytes': uBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
        {'bytes': vBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
      ];
      final rgb = FaceVerificationWorker.debugYuv420ToRgbImage(width, height, planes);
      expect(rgb.width, width);
      expect(rgb.height, height);
    });

    test('pure grey YUV (Y=128, U=128, V=128) produces grey pixel', () {
      const width = 2, height = 2;
      final yBytes = Uint8List(width * height)..fillRange(0, width * height, 128);
      final uBytes = Uint8List(width * height ~/ 4)..fillRange(0, width * height ~/ 4, 128);
      final vBytes = Uint8List(width * height ~/ 4)..fillRange(0, width * height ~/ 4, 128);
      final planes = [
        {'bytes': yBytes, 'bytesPerRow': width, 'bytesPerPixel': 1},
        {'bytes': uBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
        {'bytes': vBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
      ];
      final rgb = FaceVerificationWorker.debugYuv420ToRgbImage(width, height, planes);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      // Y=128, U=128, V=128 → near-grey (small rounding differences allowed)
      expect(bytes[0], closeTo(128, 5)); // R
      expect(bytes[1], closeTo(128, 5)); // G
      expect(bytes[2], closeTo(128, 5)); // B
    });
  });

  group('FaceVerificationWorker — image rotation', () {
    img.Image _colorImage(int w, int h) {
      final image = img.Image(width: w, height: h, numChannels: 3);
      image.setPixelRgb(0, 0, 255, 0, 0); // top-left = red
      return image;
    }

    test('rotation 0 returns same dimensions', () {
      final src = _colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 0);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('rotation 90 swaps width and height', () {
      final src = _colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 90);
      expect(out.width, 6);
      expect(out.height, 4);
    });

    test('rotation 180 preserves dimensions', () {
      final src = _colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 180);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('rotation 270 swaps width and height', () {
      final src = _colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 270);
      expect(out.width, 6);
      expect(out.height, 4);
    });

    test('rotation 360 behaves like rotation 0', () {
      final src = _colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 360);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('non-axis-aligned rotation (45°) produces output image', () {
      final src = _colorImage(4, 4);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 45);
      expect(out.width, greaterThan(0));
      expect(out.height, greaterThan(0));
    });
  });

  group('FaceVerificationWorker — image payload serialization', () {
    test('imagePayload round-trips through imageFromPayload', () {
      final original = img.Image(width: 10, height: 8);
      original.setPixelRgb(0, 0, 100, 150, 200);
      final payload = FaceVerificationWorker.debugImagePayload(original);
      final recovered = FaceVerificationWorker.debugImageFromPayload(payload);
      expect(recovered.width, 10);
      expect(recovered.height, 8);
    });

    test('imagePayload contains width, height and rgb bytes', () {
      final image = img.Image(width: 5, height: 3);
      final payload = FaceVerificationWorker.debugImagePayload(image);
      expect(payload['width'], 5);
      expect(payload['height'], 3);
      expect(payload['rgb'], isA<Uint8List>());
      expect((payload['rgb'] as Uint8List).length, 5 * 3 * 3);
    });

    test('imageFromPayload preserves pixel values', () {
      final image = img.Image(width: 2, height: 2);
      image.setPixelRgb(0, 0, 255, 0, 0); // red pixel
      final payload = FaceVerificationWorker.debugImagePayload(image);
      final recovered = FaceVerificationWorker.debugImageFromPayload(payload);
      final bytes = recovered.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 255); // R
      expect(bytes[1], 0); // G
      expect(bytes[2], 0); // B
    });
  });

  group('FaceVerificationWorker — face serialization round-trip', () {
    test('serializeFace / deserializeFaceMap preserves yaw', () {
      final face = _makeFace(yaw: 12.5);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.yawDegrees, closeTo(12.5, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves null yaw', () {
      final face = _makeFace(yaw: 0).copyWith(yawDegrees: null);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.yawDegrees, isNull);
    });

    test('serializeFace / deserializeFaceMap preserves mouthRatio', () {
      final face = _makeFace(mouthRatio: 0.08);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.mouthRatio, closeTo(0.08, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves blendshape scores', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.blendshapeScores['jawOpen'], closeTo(0.1, 1e-6));
      expect(recovered.blendshapeScores['mouthSmileLeft'], closeTo(0.2, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves landmark count', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.result.landmarks.first.length, 478);
    });

    test('serializeFace / deserializeFaceMap preserves bounding box', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.boundingBox.left, closeTo(10, 1e-6));
      expect(recovered.boundingBox.top, closeTo(20, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves alignedFace112 dimensions', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.alignedFace112.width, 112);
      expect(recovered.alignedFace112.height, 112);
    });
  });
}

extension on FaceObservation {
  FaceObservation copyWith({double? yawDegrees}) => FaceObservation(
    result: result,
    boundingBox: boundingBox,
    boundingBoxAreaRatio: boundingBoxAreaRatio,
    boundingBoxCenter: boundingBoxCenter,
    mouthRatio: mouthRatio,
    yawDegrees: yawDegrees,
    blendshapeScores: blendshapeScores,
    alignedFace112: alignedFace112,
  );
}
