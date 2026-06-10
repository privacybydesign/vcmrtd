// New unit tests for lib/src/crypto/aa_pubkey.dart
// Covers AAPublicKey.fromBytes for RSA and EC SubjectPublicKeyInfo, the
// toBytes/rawSubjectPublicKey accessors, and every "Invalid ... tag" error
// branch in the DER parser.

import 'package:test/test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/extensions.dart';

void main() {
  // Minimal DER SubjectPublicKeyInfo built by hand:
  //   SEQUENCE {
  //     AlgorithmIdentifier SEQUENCE { OID, params },
  //     BIT STRING subjectPublicKey
  //   }
  // BIT STRING here is 03 03 00 0102 (0 unused bits + 2 data bytes).

  group('AAPublicKey.fromBytes', () {
    test('parses an RSA SubjectPublicKeyInfo (rsaEncryption OID -> type RSA)', () {
      final der = '3014300D06092A864886F70D01010105000303000102'.parseHex();
      final key = AAPublicKey.fromBytes(der);

      expect(key.type, AAPublicKeyType.RSA);
      expect(key.toBytes(), der);
      // subjectPublicKey bytes begin with the BIT STRING tag 0x03.
      expect(key.rawSubjectPublicKey()[0], 0x03);
      expect(key.rawSubjectPublicKey(), '0303000102'.parseHex());
    });

    test('parses an EC SubjectPublicKeyInfo (non-RSA OID -> type ECC)', () {
      final der = '301A301306072A8648CE3D020106082A8648CE3D0301070303000102'.parseHex();
      final key = AAPublicKey.fromBytes(der);

      expect(key.type, AAPublicKeyType.ECC);
      expect(key.rawSubjectPublicKey()[0], 0x03);
    });
  });

  group('AAPublicKey.fromBytes error branches', () {
    test('throws when outer tag is not SEQUENCE (0x30)', () {
      // tag 0x31 (SET) instead of 0x30
      final der = '3114300D06092A864886F70D01010105000303000102'.parseHex();
      expect(() => AAPublicKey.fromBytes(der), throwsA(isA<Exception>()));
    });

    test('throws when AlgorithmIdentifier tag is not SEQUENCE', () {
      // Inner AlgorithmIdentifier uses tag 0x31 instead of 0x30.
      final der = '3014310D06092A864886F70D01010105000303000102'.parseHex();
      expect(() => AAPublicKey.fromBytes(der), throwsA(isA<Exception>()));
    });

    test('throws when Algorithm OID object tag is not 0x06', () {
      // The OID inside AlgorithmIdentifier uses tag 0x04 (OCTET STRING) not 0x06.
      // SEQUENCE { 04 09 <9 bytes>, NULL } ; outer adjusted accordingly.
      final der = '3014300D04092A864886F70D01010105000303000102'.parseHex();
      expect(() => AAPublicKey.fromBytes(der), throwsA(isA<Exception>()));
    });

    test('throws when SubjectPublicKey is not a BIT STRING (0x03)', () {
      // Replace the trailing BIT STRING tag 0x03 with 0x04 (OCTET STRING).
      final der = '3014300D06092A864886F70D01010105000403000102'.parseHex();
      expect(() => AAPublicKey.fromBytes(der), throwsA(isA<Exception>()));
    });
  });
}
