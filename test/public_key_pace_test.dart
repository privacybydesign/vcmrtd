// Tests for PublicKeyPACEeCDH coordinate zero-padding.
// Ported from gmrtd (https://github.com/gmrtd/gmrtd).
//
// EC coordinates from a BigInt may be shorter than the curve's field size
// when the leading byte is 0x00. Without padding, the encoded uncompressed
// point 04‖X‖Y would be malformed and rejected by the chip.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';

void main() {
  group('PublicKeyPACEeCDH coordinate padding', () {
    // -------------------------------------------------------------------
    // Core padding behaviour
    // -------------------------------------------------------------------

    test('xBytes is zero-padded when BigInt representation is shorter than coordLen', () {
      // A 256-bit coordinate whose top byte is 0x00 encodes as only 31 bytes
      // when using BigInt.toRadixString. coordLen=32 must restore the full width.
      final xBigInt = BigInt.parse('00${'AB' * 31}', radix: 16);
      final yBigInt = BigInt.parse('FF' * 32, radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt, coordLen: 32);

      expect(pubKey.xBytes.length, 32, reason: 'xBytes must be padded to coordLen');
      expect(pubKey.xBytes[0], 0x00, reason: 'leading zero byte must be preserved');
      expect(pubKey.xBytes.sublist(1), Uint8List.fromList(List.filled(31, 0xAB)));
    });

    test('yBytes is zero-padded when BigInt representation is shorter than coordLen', () {
      final xBigInt = BigInt.parse('FF' * 32, radix: 16);
      final yBigInt = BigInt.parse('00${'CD' * 31}', radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt, coordLen: 32);

      expect(pubKey.yBytes.length, 32, reason: 'yBytes must be padded to coordLen');
      expect(pubKey.yBytes[0], 0x00);
      expect(pubKey.yBytes.sublist(1), Uint8List.fromList(List.filled(31, 0xCD)));
    });

    test('full-length coordinate is returned unchanged', () {
      final xBigInt = BigInt.parse('FF' * 32, radix: 16);
      final yBigInt = BigInt.parse('AB' * 32, radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt, coordLen: 32);

      expect(pubKey.xBytes.length, 32);
      expect(pubKey.yBytes.length, 32);
    });

    test('coordLen=0 disables padding (backward-compatibility default)', () {
      // When no coordLen is supplied the constructor defaults to 0 and returns
      // the raw BigInt byte representation (no zero-padding).
      final xBigInt = BigInt.parse('00${'AB' * 31}', radix: 16);
      final yBigInt = BigInt.parse('FF' * 32, radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt);

      expect(pubKey.xBytes.length, 31, reason: 'without coordLen the leading zero is absent');
    });

    // -------------------------------------------------------------------
    // BrainpoolP256r1 real-world test vectors (gmrtd TestDoPace_CAM_ECDH_DE)
    // -------------------------------------------------------------------

    test('BrainpoolP256r1 coordLen formula: (256 + 7) ~/ 8 == 32', () {
      // This is the formula used in ecdh_pace.dart to compute coordLen
      // from the domain-parameter bit size.
      const bitSize = 256;
      expect((bitSize + 7) ~/ 8, 32);
    });

    test('gmrtd DE PACE-CAM terminal key-pair 1 coordinates are full 32 bytes', () {
      // From gmrtd TestDoPace_CAM_ECDH_DE, terminal private key index 0:
      //   privKey  = 01fd26013f5bc41fad8bb09811e435f16fbe2eb3c2e1d999b0f63da8c3d58bb5
      //   pubKey X = 303f340815eea501772393e299a4a6f6694600189c249c63a8513ff3fefa66e3
      //   pubKey Y = 46d11970b5f76fb564c3b0e54b215528f647ec5a9ab209cdbe262e763d6119a1
      // Both coordinates are exactly 32 bytes — no padding is needed here, but
      // the coordLen path must still produce exactly 32 bytes.
      final xBigInt = BigInt.parse('303f340815eea501772393e299a4a6f6694600189c249c63a8513ff3fefa66e3', radix: 16);
      final yBigInt = BigInt.parse('46d11970b5f76fb564c3b0e54b215528f647ec5a9ab209cdbe262e763d6119a1', radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt, coordLen: 32);

      expect(pubKey.xBytes.length, 32);
      expect(pubKey.yBytes.length, 32);
    });

    test('padding produces correct uncompressed-point byte sequence', () {
      // Uncompressed EC point encoding: 04 || X (coordLen bytes) || Y (coordLen bytes)
      // If X has a leading-zero byte that BigInt drops, the encoded point must still
      // start with 04 and have exactly 1 + 2*coordLen bytes total.
      final xBigInt = BigInt.parse('00${'AB' * 31}', radix: 16);
      final yBigInt = BigInt.parse('CD' * 32, radix: 16);

      final pubKey = PublicKeyPACEeCDH(x: xBigInt, y: yBigInt, coordLen: 32);
      final encoded = Uint8List.fromList([0x04, ...pubKey.xBytes, ...pubKey.yBytes]);

      expect(encoded.length, 65); // 1 + 32 + 32
      expect(encoded[0], 0x04);
      expect(encoded[1], 0x00); // leading-zero byte preserved in X
    });
  });
}
