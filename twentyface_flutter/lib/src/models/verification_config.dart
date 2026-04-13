/// Configuration for face verification.
class FaceVerificationConfig {
  /// Distance threshold for considering faces as a match.
  /// Lower values are stricter. Default: 0.7
  final double matchThreshold;

  /// Enable passive liveness detection. Default: true
  final bool enablePassiveLiveness;

  /// Threshold for passive liveness detection.
  /// Higher values are stricter. Default: 0.5
  final double livenessThreshold;

  /// Maximum allowed horizontal (yaw) rotation in degrees. Default: 30.0
  final double maxHorizontalRotation;

  /// Maximum allowed vertical (pitch) rotation in degrees. Default: 30.0
  final double maxVerticalRotation;

  /// Minimum sharpness score (0-12). Default: 3.0
  final double minSharpness;

  /// Maximum exposure percentage (0-100). Default: 4.0
  final double maxExposure;

  /// Only detect the closest (largest) face. Default: true
  final bool detectClosestOnly;

  const FaceVerificationConfig({
    this.matchThreshold = 0.7,
    this.enablePassiveLiveness = true,
    this.livenessThreshold = 0.5,
    this.maxHorizontalRotation = 30.0,
    this.maxVerticalRotation = 30.0,
    this.minSharpness = 3.0,
    this.maxExposure = 4.0,
    this.detectClosestOnly = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'match_threshold': matchThreshold,
      'enable_passive_liveness': enablePassiveLiveness,
      'liveness_threshold': livenessThreshold,
      'max_horizontal_rotation': maxHorizontalRotation,
      'max_vertical_rotation': maxVerticalRotation,
      'min_sharpness': minSharpness,
      'max_exposure': maxExposure,
      'detect_closest_only': detectClosestOnly,
    };
  }

  FaceVerificationConfig copyWith({
    double? matchThreshold,
    bool? enablePassiveLiveness,
    double? livenessThreshold,
    double? maxHorizontalRotation,
    double? maxVerticalRotation,
    double? minSharpness,
    double? maxExposure,
    bool? detectClosestOnly,
  }) {
    return FaceVerificationConfig(
      matchThreshold: matchThreshold ?? this.matchThreshold,
      enablePassiveLiveness:
          enablePassiveLiveness ?? this.enablePassiveLiveness,
      livenessThreshold: livenessThreshold ?? this.livenessThreshold,
      maxHorizontalRotation:
          maxHorizontalRotation ?? this.maxHorizontalRotation,
      maxVerticalRotation: maxVerticalRotation ?? this.maxVerticalRotation,
      minSharpness: minSharpness ?? this.minSharpness,
      maxExposure: maxExposure ?? this.maxExposure,
      detectClosestOnly: detectClosestOnly ?? this.detectClosestOnly,
    );
  }
}
