import 'package:json_annotation/json_annotation.dart';

part 'verification_response.g.dart';

// explicitToJson keeps nested objects serialised as maps, as the previously
// generated code did, so toJson()/fromJson() round-trip without jsonEncode.
@JsonSerializable(explicitToJson: true)
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

  /// The Iris face session the issuer opened for this document, present only
  /// when the session's assigned face verification method is Iris. The wallet
  /// streams camera frames to [FaceSession.streamUrl] and hands
  /// [FaceSession.faceSessionId] back at issuance.
  @JsonKey(name: 'face_session')
  final FaceSession? faceSession;

  VerificationResponse({
    required this.isExpired,
    required this.authenticChip,
    required this.authenticContent,
    this.faceMatch,
    this.faceSession,
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

/// An Iris face session opened by the issuer during verification, bound on the
/// issuer side to the portrait it authenticated. The wallet never sees or
/// supplies the portrait; it only streams frames and returns the id.
@JsonSerializable()
class FaceSession {
  /// Identifier the wallet sends back as `face_session_id` at issuance.
  @JsonKey(name: 'face_session_id')
  final String faceSessionId;

  /// WebSocket endpoint (`wss://…/stream/{face_session_id}`) to stream camera
  /// frames to.
  @JsonKey(name: 'stream_url')
  final String streamUrl;

  /// Bearer token sent as the first message on the stream, never in the URL.
  final String token;

  /// Seconds until the session expires if streaming has not started.
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  FaceSession({required this.faceSessionId, required this.streamUrl, required this.token, required this.expiresIn});

  factory FaceSession.fromJson(Map<String, dynamic> json) => _$FaceSessionFromJson(json);
  Map<String, dynamic> toJson() => _$FaceSessionToJson(this);
}
