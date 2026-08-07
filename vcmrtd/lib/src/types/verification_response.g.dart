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
);

Map<String, dynamic> _$VerificationResponseToJson(VerificationResponse instance) => <String, dynamic>{
  'is_expired': instance.isExpired,
  'authentic_chip': instance.authenticChip,
  'authentic_content': instance.authenticContent,
  'face_match': instance.faceMatch?.toJson(),
};

FaceMatch _$FaceMatchFromJson(Map<String, dynamic> json) =>
    FaceMatch(matched: json['matched'] as bool, similarity: (json['similarity'] as num).toDouble());

Map<String, dynamic> _$FaceMatchToJson(FaceMatch instance) => <String, dynamic>{
  'matched': instance.matched,
  'similarity': instance.similarity,
};
