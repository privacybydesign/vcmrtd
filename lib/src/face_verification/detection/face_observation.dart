import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:vcmrtd/face_verification.dart';

// Observation produced for a single detected face in one image frame.
class FaceObservation {
  const FaceObservation({
    required this.result,
    required this.boundingBox,
    required this.boundingBoxAreaRatio,
    required this.boundingBoxCenter,
    required this.mouthRatio,
    required this.yawDegrees,
    required this.blendshapeScores,
    required this.alignedFace112,
  });

  // Full landmark/blendshape/matrix output from the pipeline.
  final FaceLandmarkerResult result;

  // Bounding box in pixel coordinates of the source image.
  final Rect boundingBox;

  // [boundingBox] area as a fraction of the frame area (0–1).
  // Used to decide whether the face is too close or too far from the camera.
  final double boundingBoxAreaRatio;

  // Face center normalized to the frame (0–1 per axis). Mirror- and
  // rotation-robust; suitable for "is the face inside the oval" checks.
  final Offset boundingBoxCenter;

  // Vertical lip-gap divided by face height; >0 indicates an open mouth.
  final double mouthRatio;

  // Yaw in degrees derived from the 4×4 pose matrix (positive = turned right).
  // Null when the pose matrix is absent or degenerate.
  final double? yawDegrees;

  // MediaPipe blendshape name → score (0–1) map. Empty when blendshapes were
  // not requested (e.g. NFC photo alignment).
  final Map<String, double> blendshapeScores;

  // 112×112 RGB face crop aligned to the 5 ArcFace canonical keypoints.
  final img.Image alignedFace112;
}
