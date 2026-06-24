// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerificationResponse _$VerificationResponseFromJson(Map<String, dynamic> json) => VerificationResponse(
  isExpired: json['is_expired'] as bool,
  authenticChip: json['authentic_chip'] as bool,
  authenticContent: json['authentic_content'] as bool,
  faceSession: json['face_session'] == null
      ? null
      : FaceSession.fromJson(json['face_session'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VerificationResponseToJson(VerificationResponse instance) => <String, dynamic>{
  'is_expired': instance.isExpired,
  'authentic_chip': instance.authenticChip,
  'authentic_content': instance.authenticContent,
  'face_session': instance.faceSession?.toJson(),
};
