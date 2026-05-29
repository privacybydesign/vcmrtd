// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'irma_session_pointer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IrmaSessionPointer _$IrmaSessionPointerFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['u', 'irmaqr']);
  return IrmaSessionPointer(u: json['u'] as String, irmaqr: json['irmaqr'] as String);
}

Map<String, dynamic> _$IrmaSessionPointerToJson(IrmaSessionPointer instance) => <String, dynamic>{
  'u': instance.u,
  'irmaqr': instance.irmaqr,
};
