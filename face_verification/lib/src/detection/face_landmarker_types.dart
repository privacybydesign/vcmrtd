// Holds the full output of one landmark inference pass.
class FaceLandmarkerResult {
  FaceLandmarkerResult({required this.landmarks, this.transformMatrices});

  // Normalized (0–1) XYZ coordinates for each detected face.
  // Index 0 is the primary face; each inner list has 478 landmarks.
  final List<List<NormalizedLandmark>> landmarks;

  // Column-major 4×4 rotation matrix derived from ear-to-ear and chin-to-crown
  // landmark vectors via Gram-Schmidt. Used to extract yaw without a 3-D model.
  final List<List<double>>? transformMatrices;
}

// A single facial landmark in normalized image coordinates.
class NormalizedLandmark {
  const NormalizedLandmark(this.x, this.y, this.z);

  // Horizontal position, 0 = left edge, 1 = right edge of the image.
  final double x;

  // Vertical position, 0 = top edge, 1 = bottom edge of the image.
  final double y;

  // Estimated metric depth relative to the face plane; scale is model-specific
  // and should only be used comparatively between landmarks of the same result.
  final double z;
}
