import 'dart:convert';
import 'dart:typed_data';

class PassportDataResult {
  final Map<String, String> dataGroups;
  final String efSod;
  final String? sessionId;
  final Uint8List? nonce;

  PassportDataResult({
    required this.dataGroups,
    required this.efSod,
    this.sessionId,
    this.nonce
  });

  Map<String, dynamic> toJson() => {
    'data_groups': dataGroups,
    'ef_sod': efSod,
    'nonce': nonce,
    'sessionId': sessionId
  };

  String toJsonString() => jsonEncode(toJson());
}