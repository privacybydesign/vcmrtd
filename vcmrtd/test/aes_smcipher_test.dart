// NEW tests for lib/src/proto/aes_smcipher.dart (AES secure-messaging cipher).
//
// CMAC reference values are the official RFC 4493 (NIST AES-CMAC) test vectors,
// truncated to the first 8 bytes (this cipher fixes CMAC output to 64 bits).
//   K = 2b7e151628aed2a6abf7158809cf4f3c
//   AES-CMAC("")                       = bb1d6929e9593728 (94f592e7) ...
//   AES-CMAC(6bc1bee22e409f96e93d7e117393172a) = 070a16b46b4d4144 ...

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/proto/aes_smcipher.dart';
import 'package:vcmrtd/src/proto/ssc.dart';

void main() {
  // Session keys from ICAO 9303 p11 Appendix D.4 (reused as arbitrary 128-bit keys).
  final ksenc = '979EC13B1CBFE9DCD01AB0FED307EAE5'.parseHex();
  final ksmac = 'F1CB1F1FB5ADF208806B89DC579DC1F8'.parseHex();

  AES_SMCipher newCipher() => AES_SMCipher(ksenc, ksmac, size: KEY_LENGTH.s128);

  test('cipherAlgorithm getter and type are AES', () {
    final c = newCipher();
    expect(c.type, CipherAlgorithm.AES);
    expect(c.cipherAlgorithm, CipherAlgorithm.AES);
  });

  test('encrypt then decrypt round-trips with same SSC', () {
    final c = newCipher();
    final data = '00112233445566778899AABBCCDDEEFF'.parseHex();

    final ssc1 = AES_SSC();
    final enc = c.encrypt(data, ssc: ssc1);
    expect(enc, isNot(equals(data)), reason: 'ciphertext must differ from plaintext');

    // Decrypt with an SSC at the same value (fresh AES_SSC initialised to 0).
    final ssc2 = AES_SSC();
    final dec = c.decrypt(enc, ssc: ssc2);
    expect(dec, data);
  });

  test('encrypt produces a deterministic, IV-derived ciphertext', () {
    // The IV is E(KSenc, SSC) in ECB, so encryption is deterministic for a
    // fixed SSC. This pins the byte output of the full encrypt path.
    final c = newCipher();
    final data = '00112233445566778899AABBCCDDEEFF'.parseHex();
    final enc = c.encrypt(data, ssc: AES_SSC());
    expect(enc, 'A9B4951042E08A5A2EE51C6E410D35EE'.parseHex());
  });

  test('encrypt throws when SSC is null', () {
    final c = newCipher();
    expect(() => c.encrypt('0011223344556677'.parseHex(), ssc: null), throwsA(isA<Exception>()));
  });

  test('decrypt throws when SSC is null', () {
    final c = newCipher();
    expect(() => c.decrypt('0011223344556677'.parseHex(), ssc: null), throwsA(isA<Exception>()));
  });

  group('mac (CMAC truncated to 64 bits) — RFC 4493 vectors', () {
    final rfcKey = '2b7e151628aed2a6abf7158809cf4f3c'.parseHex();

    test('empty message', () {
      final c = AES_SMCipher(ksenc, rfcKey, size: KEY_LENGTH.s128);
      expect(c.mac(Uint8List(0)), 'bb1d6929e9593728'.parseHex());
    });

    test('16-byte message (one block)', () {
      final c = AES_SMCipher(ksenc, rfcKey, size: KEY_LENGTH.s128);
      expect(c.mac('6bc1bee22e409f96e93d7e117393172a'.parseHex()), '070a16b46b4d4144'.parseHex());
    });

    test('mac output is exactly 8 bytes', () {
      final c = newCipher();
      expect(c.mac('00112233445566778899AABBCCDDEEFF'.parseHex()).length, 8);
    });
  });
}
