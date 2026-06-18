import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_detector.dart';
import 'package:face_verification/src/detection/face_landmarker_types.dart';

void main() {
  group('FaceDetectorService pure observation helpers', () {
    test('returns null yaw when pose matrix is missing or too short', () {
      final detector = FaceDetectorService();

      expect(detector.matrixYaw(FaceLandmarkerResult(landmarks: <List<NormalizedLandmark>>[])), isNull);
      expect(
        detector.matrixYaw(
          FaceLandmarkerResult(
            landmarks: <List<NormalizedLandmark>>[],
            transformMatrices: <List<double>>[
              <double>[1, 0],
            ],
          ),
        ),
        isNull,
      );
    });

    test('builds observation from landmarks and pose matrix', () {
      final detector = FaceDetectorService();
      final image = img.Image(width: 200, height: 100);
      final result = FaceLandmarkerResult(
        landmarks: <List<NormalizedLandmark>>[_landmarks()],
        transformMatrices: <List<double>>[
          <double>[1, 0, -0.5],
        ],
      );

      final observation = detector.buildObservation(image, result);

      expect(observation.result, same(result));
      expect(observation.boundingBox.left, closeTo(10, 1e-9));
      expect(observation.boundingBox.top, closeTo(10, 1e-9));
      expect(observation.boundingBox.right, closeTo(190, 1e-9));
      expect(observation.boundingBox.bottom, closeTo(90, 1e-9));
      expect(observation.boundingBoxCenter, const Offset(0.5, 0.5));
      expect(observation.boundingBoxAreaRatio, closeTo(0.72, 1e-9));
      expect(observation.yawDegrees, closeTo(30, 1e-9));
      expect(observation.alignedFace112.width, 112);
      expect(observation.alignedFace112.height, 112);
    });

    test('throws when required alignment landmarks are missing', () {
      final detector = FaceDetectorService();
      final result = FaceLandmarkerResult(
        landmarks: <List<NormalizedLandmark>>[
          List<NormalizedLandmark>.filled(10, const NormalizedLandmark(0.5, 0.5, 0)),
        ],
      );

      expect(() => detector.buildObservation(img.Image(width: 20, height: 20), result), throwsA(isA<StateError>()));
    });
  });
}

List<NormalizedLandmark> _landmarks() {
  final landmarks = List<NormalizedLandmark>.generate(478, (_) => const NormalizedLandmark(0.5, 0.5, 0));

  void set(int index, double x, double y) {
    landmarks[index] = NormalizedLandmark(x, y, 0);
  }

  set(10, 0.5, 0.1);
  set(152, 0.5, 0.9);
  set(13, 0.5, 0.45);
  set(14, 0.5, 0.55);

  set(468, 0.35, 0.42);
  set(473, 0.65, 0.42);
  set(1, 0.5, 0.55);
  set(61, 0.4, 0.72);
  set(291, 0.6, 0.72);

  set(100, 0.05, 0.1);
  set(101, 0.95, 0.9);
  set(102, 0.5, 0.5);
  return landmarks;
}
