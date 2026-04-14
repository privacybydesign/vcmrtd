/// Status flags for face detection and quality checks.
class FaceStatus {
  final bool detectionTooSmall;
  final bool detectionScoreTooLow;
  final bool detectionOutsideImage;
  final bool detectionOutsideDepthImage;
  final bool detectionNoFaces;
  final bool detectionTooManyFaces;
  final bool qualitycheckBlurry;
  final bool qualitycheckRotated;
  final bool qualitycheckOverexposed;
  final bool antispoofingTooFar;
  final bool antispoofingSpoofed;
  final bool passiveAntispoofingSpoofed;
  final bool facevectorTooSimilarInDb;
  final bool facevectorNotRecognized;
  final bool facevectorFailedToCreate;
  final bool isOverallOk;

  const FaceStatus({
    this.detectionTooSmall = false,
    this.detectionScoreTooLow = false,
    this.detectionOutsideImage = false,
    this.detectionOutsideDepthImage = false,
    this.detectionNoFaces = false,
    this.detectionTooManyFaces = false,
    this.qualitycheckBlurry = false,
    this.qualitycheckRotated = false,
    this.qualitycheckOverexposed = false,
    this.antispoofingTooFar = false,
    this.antispoofingSpoofed = false,
    this.passiveAntispoofingSpoofed = false,
    this.facevectorTooSimilarInDb = false,
    this.facevectorNotRecognized = false,
    this.facevectorFailedToCreate = false,
    this.isOverallOk = true,
  });

  factory FaceStatus.fromMap(Map<dynamic, dynamic> map) {
    return FaceStatus(
      detectionTooSmall: map['detection_too_small'] as bool? ?? false,
      detectionScoreTooLow: map['detection_score_too_low'] as bool? ?? false,
      detectionOutsideImage: map['detection_outside_image'] as bool? ?? false,
      detectionOutsideDepthImage:
          map['detection_outside_depth_image'] as bool? ?? false,
      detectionNoFaces: map['detection_no_faces'] as bool? ?? false,
      detectionTooManyFaces: map['detection_too_many_faces'] as bool? ?? false,
      qualitycheckBlurry: map['qualitycheck_blurry'] as bool? ?? false,
      qualitycheckRotated: map['qualitycheck_rotated'] as bool? ?? false,
      qualitycheckOverexposed:
          map['qualitycheck_overexposed'] as bool? ?? false,
      antispoofingTooFar: map['antispoofing_too_far'] as bool? ?? false,
      antispoofingSpoofed: map['antispoofing_spoofed'] as bool? ?? false,
      passiveAntispoofingSpoofed:
          map['passive_antispoofing_spoofed'] as bool? ?? false,
      facevectorTooSimilarInDb:
          map['facevector_too_similar_in_db'] as bool? ?? false,
      facevectorNotRecognized:
          map['facevector_not_recognized'] as bool? ?? false,
      facevectorFailedToCreate:
          map['facevector_failed_to_create'] as bool? ?? false,
      isOverallOk: map['is_overall_ok'] as bool? ?? false,
    );
  }

  Map<String, bool> toMap() {
    return {
      'detection_too_small': detectionTooSmall,
      'detection_score_too_low': detectionScoreTooLow,
      'detection_outside_image': detectionOutsideImage,
      'detection_outside_depth_image': detectionOutsideDepthImage,
      'detection_no_faces': detectionNoFaces,
      'detection_too_many_faces': detectionTooManyFaces,
      'qualitycheck_blurry': qualitycheckBlurry,
      'qualitycheck_rotated': qualitycheckRotated,
      'qualitycheck_overexposed': qualitycheckOverexposed,
      'antispoofing_too_far': antispoofingTooFar,
      'antispoofing_spoofed': antispoofingSpoofed,
      'passive_antispoofing_spoofed': passiveAntispoofingSpoofed,
      'facevector_too_similar_in_db': facevectorTooSimilarInDb,
      'facevector_not_recognized': facevectorNotRecognized,
      'facevector_failed_to_create': facevectorFailedToCreate,
      'is_overall_ok': isOverallOk,
    };
  }

  /// Returns a list of human-readable error messages based on status flags.
  List<String> get errorMessages {
    final messages = <String>[];
    if (detectionTooSmall) messages.add('Face is too small');
    if (detectionScoreTooLow) messages.add('Face detection confidence too low');
    if (detectionOutsideImage) messages.add('Face is outside image bounds');
    if (detectionNoFaces) messages.add('No face detected');
    if (detectionTooManyFaces) messages.add('Multiple faces detected');
    if (qualitycheckBlurry) messages.add('Image is too blurry');
    if (qualitycheckRotated) messages.add('Face is rotated too much');
    if (qualitycheckOverexposed) messages.add('Image is overexposed');
    if (antispoofingTooFar) messages.add('Face is too far for liveness check');
    if (antispoofingSpoofed) messages.add('Liveness check failed');
    if (passiveAntispoofingSpoofed) messages.add('Passive liveness check failed');
    if (facevectorFailedToCreate) messages.add('Failed to create face vector');
    return messages;
  }

  @override
  String toString() {
    if (isOverallOk) return 'FaceStatus(OK)';
    return 'FaceStatus(errors: ${errorMessages.join(", ")})';
  }
}
