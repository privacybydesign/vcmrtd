import 'face_status.dart';

/// Result of a liveness check.
class LivenessResult {
  /// Whether the liveness check passed.
  final bool isLive;

  /// Liveness score (higher is more likely to be a real face).
  final double score;

  /// Full face status including liveness flags.
  final FaceStatus status;

  const LivenessResult({
    required this.isLive,
    required this.score,
    required this.status,
  });

  factory LivenessResult.fromMap(Map<dynamic, dynamic> map) {
    final status = map['status'] != null
        ? FaceStatus.fromMap(map['status'] as Map<dynamic, dynamic>)
        : const FaceStatus(isOverallOk: false);

    return LivenessResult(
      isLive: map['is_live'] as bool? ??
          (!status.passiveAntispoofingSpoofed && !status.antispoofingSpoofed),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      status: status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_live': isLive,
      'score': score,
      'status': status.toMap(),
    };
  }

  @override
  String toString() =>
      'LivenessResult(isLive: $isLive, score: ${score.toStringAsFixed(2)})';
}
