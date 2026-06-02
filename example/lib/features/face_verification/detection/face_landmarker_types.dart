/// Holds the full output of one landmark inference pass.
class FaceLandmarkerResult {
  FaceLandmarkerResult({required this.landmarks, this.blendshapes, this.transformMatrices});

  /// Normalized (0–1) XYZ coordinates for each detected face.
  /// Index 0 is the primary face; each inner list has 478 landmarks.
  final List<List<NormalizedLandmark>> landmarks;

  /// MediaPipe blendshape scores (0–1) per face, parallel to [landmarks].
  /// Null when blendshape inference was skipped (e.g. NFC photo alignment).
  final List<List<Category>>? blendshapes;

  /// Column-major 4×4 rotation matrix derived from ear-to-ear and chin-to-crown
  /// landmark vectors via Gram-Schmidt. Used to extract yaw without a 3-D model.
  final List<List<double>>? transformMatrices;
}

/// A single facial landmark in normalized image coordinates.
class NormalizedLandmark {
  const NormalizedLandmark(this.x, this.y, this.z);

  /// Horizontal position, 0 = left edge, 1 = right edge of the image.
  final double x;

  /// Vertical position, 0 = top edge, 1 = bottom edge of the image.
  final double y;

  /// Estimated metric depth relative to the face plane; scale is model-specific
  /// and should only be used comparatively between landmarks of the same result.
  final double z;
}

/// A named prediction score produced by the blendshape model.
class Category {
  const Category(this.categoryName, this.score);

  /// MediaPipe blendshape name, e.g. "eyeBlinkLeft" or "jawOpen".
  final String categoryName;

  /// Confidence in the range [0, 1].
  final double score;
}
