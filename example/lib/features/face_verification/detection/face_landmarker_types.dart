class FaceLandmarkerResult {
  FaceLandmarkerResult({required this.landmarks, this.blendshapes, this.transformMatrices});

  final List<List<NormalizedLandmark>> landmarks;
  final List<List<Category>>? blendshapes;
  final List<List<double>>? transformMatrices;
}

class NormalizedLandmark {
  const NormalizedLandmark(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

class Category {
  const Category(this.categoryName, this.score);

  final String categoryName;
  final double score;
}
