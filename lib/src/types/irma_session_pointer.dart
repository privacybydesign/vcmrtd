import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
part 'irma_session_pointer.g.dart';

@JsonSerializable()
class IrmaSessionPointer {
  @JsonKey(name: 'u', required: true)
  final String u;

  @JsonKey(name: 'irmaqr', required: true)
  final String irmaqr;

  IrmaSessionPointer({required this.u, required this.irmaqr});

  factory IrmaSessionPointer.fromJson(Map<String, dynamic> json) => _$IrmaSessionPointerFromJson(json);
  Map<String, dynamic> toJson() => _$IrmaSessionPointerToJson(this);

  Uri toUniversalLink() {
    final urlEncodedSessionPtr = Uri.encodeFull(jsonEncode(toJson()));
    return Uri.parse('https://open.staging.yivi.app/-/session#$urlEncodedSessionPtr');
  }
}
