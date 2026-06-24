import 'package:json_annotation/json_annotation.dart';

import 'face_session.dart';

part 'verification_response.g.dart';

@JsonSerializable()
class VerificationResponse {
  @JsonKey(name: 'is_expired')
  final bool isExpired;

  @JsonKey(name: 'authentic_chip')
  final bool authenticChip;

  @JsonKey(name: 'authentic_content')
  final bool authenticContent;

  /// Optional face verification session, present only when the passport issuer
  /// has the face verification integration configured and a session was created
  /// from the DG2 portrait.
  @JsonKey(name: 'face_session')
  final FaceSession? faceSession;

  VerificationResponse({
    required this.isExpired,
    required this.authenticChip,
    required this.authenticContent,
    this.faceSession,
  });

  factory VerificationResponse.fromJson(Map<String, dynamic> json) => _$VerificationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationResponseToJson(this);
}
