import 'package:json_annotation/json_annotation.dart';

part 'verification_response.g.dart';

@JsonSerializable()
class VerificationResponse {
  @JsonKey(name: 'is_expired')
  final bool isExpired;

  @JsonKey(name: 'authentic_chip')
  final bool authenticChip;

  @JsonKey(name: 'authentic_content')
  final bool authenticContent;

  /// Optional result of comparing the document chip portrait against the live
  /// face from a Regula liveness transaction. Present only when the issuer has
  /// face verification enabled and a liveness transaction was supplied.
  @JsonKey(name: 'face_match')
  final FaceMatch? faceMatch;

  VerificationResponse({
    required this.isExpired,
    required this.authenticChip,
    required this.authenticContent,
    this.faceMatch,
  });

  factory VerificationResponse.fromJson(Map<String, dynamic> json) => _$VerificationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationResponseToJson(this);
}

/// Result of the issuer's 1:1 comparison of the document chip portrait against
/// the live face captured during a Regula liveness session.
@JsonSerializable()
class FaceMatch {
  /// True when the similarity is at or above the issuer's configured threshold.
  final bool matched;

  /// Similarity score between the chip portrait and the live face (0..1).
  final double similarity;

  FaceMatch({required this.matched, required this.similarity});

  factory FaceMatch.fromJson(Map<String, dynamic> json) => _$FaceMatchFromJson(json);
  Map<String, dynamic> toJson() => _$FaceMatchToJson(this);
}
