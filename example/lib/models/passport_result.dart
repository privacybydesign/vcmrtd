import 'dart:convert';
import 'dart:typed_data';

class PassportDataResult {
  final Map<String, String> dataGroups;
  final String efSod;
  final String? sessionId;
  final Uint8List? nonce;
  final Uint8List? signature;

  PassportDataResult({
    required this.dataGroups,
    required this.efSod,
    this.sessionId,
    this.nonce,
    this.signature
  });

  String _bytesToHex(Uint8List bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'data_groups': dataGroups,
    'ef_sod': efSod,
    'nonce': nonce != null ? _bytesToHex(nonce!) : null,
    'session_id': sessionId
  };

  String toJsonString() => jsonEncode(toJson());
}