// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_data_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawDocumentData _$RawDocumentDataFromJson(Map<String, dynamic> json) => RawDocumentData(
  dataGroups: Map<String, String>.from(json['data_groups'] as Map),
  efSod: json['ef_sod'] as String,
  sessionId: json['session_id'] as String?,
  nonce: const Uint8ListConverter().fromJson(json['nonce'] as String?),
  aaSignature: const Uint8ListConverter().fromJson(json['aa_signature'] as String?),
  livenessTransactionId: json['liveness_transaction_id'] as String?,
  faceSessionId: json['face_session_id'] as String?,
  faceOndevicePassed: json['face_ondevice_passed'] as bool?,
  faceOndevicePortraitSha256: json['face_ondevice_portrait_sha256'] as String?,
  faceAttempt: (json['face_attempt'] as num?)?.toInt(),
  faceDurationMs: (json['face_duration_ms'] as num?)?.toInt(),
);

Map<String, dynamic> _$RawDocumentDataToJson(RawDocumentData instance) => <String, dynamic>{
  'data_groups': instance.dataGroups,
  'ef_sod': instance.efSod,
  'session_id': instance.sessionId,
  'nonce': const Uint8ListConverter().toJson(instance.nonce),
  'aa_signature': const Uint8ListConverter().toJson(instance.aaSignature),
  'liveness_transaction_id': ?instance.livenessTransactionId,
  'face_session_id': ?instance.faceSessionId,
  'face_ondevice_passed': ?instance.faceOndevicePassed,
  'face_ondevice_portrait_sha256': ?instance.faceOndevicePortraitSha256,
  'face_attempt': ?instance.faceAttempt,
  'face_duration_ms': ?instance.faceDurationMs,
};
