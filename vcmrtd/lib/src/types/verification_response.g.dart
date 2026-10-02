// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerificationResponse _$VerificationResponseFromJson(Map<String, dynamic> json) => VerificationResponse(
  isExpired: json['is_expired'] as bool,
  authenticChip: json['authentic_chip'] as bool,
  authenticContent: json['authentic_content'] as bool,
  faceMatch: json['face_match'] == null ? null : FaceMatch.fromJson(json['face_match'] as Map<String, dynamic>),
  faceSession: json['face_session'] == null ? null : FaceSession.fromJson(json['face_session'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VerificationResponseToJson(VerificationResponse instance) => <String, dynamic>{
  'is_expired': instance.isExpired,
  'authentic_chip': instance.authenticChip,
  'authentic_content': instance.authenticContent,
  'face_match': instance.faceMatch?.toJson(),
  'face_session': instance.faceSession?.toJson(),
};

FaceMatch _$FaceMatchFromJson(Map<String, dynamic> json) =>
    FaceMatch(matched: json['matched'] as bool, similarity: (json['similarity'] as num).toDouble());

Map<String, dynamic> _$FaceMatchToJson(FaceMatch instance) => <String, dynamic>{
  'matched': instance.matched,
  'similarity': instance.similarity,
};

FaceSession _$FaceSessionFromJson(Map<String, dynamic> json) => FaceSession(
  faceSessionId: json['face_session_id'] as String,
  streamUrl: json['stream_url'] as String,
  token: json['token'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
);

Map<String, dynamic> _$FaceSessionToJson(FaceSession instance) => <String, dynamic>{
  'face_session_id': instance.faceSessionId,
  'stream_url': instance.streamUrl,
  'token': instance.token,
  'expires_in': instance.expiresIn,
};
