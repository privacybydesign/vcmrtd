import 'face_status.dart';

/// Result of comparing two face images.
class FaceComparisonResult {
  /// Whether the faces match (distance below threshold).
  final bool match;

  /// The Euclidean distance between the two face vectors.
  /// Range: 0.0 to 2.0 (lower is more similar).
  /// A negative value indicates an error occurred.
  final double recognitionDistance;

  /// Status of the first image (live camera image).
  final FaceStatus statusImage1;

  /// Status of the second image (reference/passport image).
  final FaceStatus statusImage2;

  const FaceComparisonResult({
    required this.match,
    required this.recognitionDistance,
    required this.statusImage1,
    required this.statusImage2,
  });

  factory FaceComparisonResult.fromMap(Map<dynamic, dynamic> map) {
    return FaceComparisonResult(
      match: map['match'] as bool? ?? false,
      recognitionDistance: (map['recognition_distance'] as num?)?.toDouble() ?? -1.0,
      statusImage1: map['status_image_1'] != null
          ? FaceStatus.fromMap(map['status_image_1'] as Map<dynamic, dynamic>)
          : const FaceStatus(isOverallOk: false),
      statusImage2: map['status_image_2'] != null
          ? FaceStatus.fromMap(map['status_image_2'] as Map<dynamic, dynamic>)
          : const FaceStatus(isOverallOk: false),
    );
  }

  /// Whether the comparison was successful (both images had valid faces).
  bool get isSuccessful =>
      statusImage1.isOverallOk && statusImage2.isOverallOk && recognitionDistance >= 0;

  /// Returns true if the live image passed the liveness check.
  bool get passedLivenessCheck =>
      !statusImage1.passiveAntispoofingSpoofed &&
      !statusImage1.antispoofingSpoofed;

  /// Similarity score as a percentage (100% = identical, 0% = completely different).
  /// Returns null if comparison failed.
  double? get similarityPercentage {
    if (recognitionDistance < 0) return null;
    // Distance range is 0-2, so we convert to percentage
    return ((2.0 - recognitionDistance) / 2.0 * 100).clamp(0.0, 100.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'match': match,
      'recognition_distance': recognitionDistance,
      'status_image_1': statusImage1.toMap(),
      'status_image_2': statusImage2.toMap(),
    };
  }

  @override
  String toString() {
    final similarity = similarityPercentage?.toStringAsFixed(1);
    return 'FaceComparisonResult('
        'match: $match, '
        'similarity: ${similarity ?? "N/A"}%, '
        'distance: ${recognitionDistance.toStringAsFixed(3)}, '
        'image1: $statusImage1, '
        'image2: $statusImage2)';
  }
}
