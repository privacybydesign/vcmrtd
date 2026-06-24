import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/services/face_verification_client.dart';

// These vectors were generated from the face-verification-service backend's own
// crypto (backend/services/crypto_service.py) for session_id "fs_test",
// photo bytes [4,5,6], frame bytes [1,2,3], sequence 1. They guard that the Dart
// HKDF/HMAC derivation matches the server byte-for-byte — if it drifts, the
// handshake/frame MAC are rejected and verification silently fails.
const _sessionId = 'fs_test';
final _photo = Uint8List.fromList([4, 5, 6]);
const _expectedKeyB64 = 'r9JRGggQs4qejC9XibTWQdmjJL//UM+QAyEccgBW/+Q=';
const _expectedHandshakeB64 = 'RECirVdIbdNRf7V42Zgov6hsBJyT4gtEwzlSGw0SCs0=';
const _expectedFrameMacB64 = '3/wmu856jVTS8pY2RpVMwmfFBhzVozN22rGBfnICqO8=';

Uint8List _hmac(List<int> key, List<int> data) => Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

void main() {
  test('binding key matches the backend HKDF-SHA256 derivation', () {
    final key = deriveBindingKey(_sessionId, _photo);
    expect(base64.encode(key), _expectedKeyB64);
  });

  test('handshake signature matches the backend', () {
    final key = deriveBindingKey(_sessionId, _photo);
    final signature = _hmac(key, utf8.encode(_sessionId));
    expect(base64.encode(signature), _expectedHandshakeB64);
  });

  test('frame MAC matches the backend (frame_bytes || sequence_be64)', () {
    final key = deriveBindingKey(_sessionId, _photo);
    final frame = [1, 2, 3];
    final seqBe64 = (ByteData(8)..setUint64(0, 1, Endian.big)).buffer.asUint8List();
    final mac = _hmac(key, [...frame, ...seqBe64]);
    expect(base64.encode(mac), _expectedFrameMacB64);
  });
}
