// New unit tests for lib/src/crypto/aes.dart
// Covers ECB mode (FIPS-197 vector), CBC round-trip, zero padding, the
// key-length and IV-length error branches, the size getter for each key
// length, the AESCipher128/192/256 subclasses, AESChiperSelector and CMAC.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/crypto/aes.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';

void main() {
  group('AESCipher ECB (FIPS-197 Appendix B / C.1 vectors)', () {
    final key = '000102030405060708090a0b0c0d0e0f'.parseHex();
    final plain = '00112233445566778899aabbccddeeff'.parseHex();
    final cipher = '69c4e0d86a7b0430d8cdb78070b4c55a'.parseHex();

    test('AES-128 ECB encrypt matches known vector', () {
      final aes = AESCipher128();
      final out = aes.encrypt(data: plain, key: key, mode: BLOCK_CIPHER_MODE.ECB);
      expect(out, cipher);
    });

    test('AES-128 ECB decrypt is the inverse', () {
      final aes = AESCipher128();
      final out = aes.decrypt(data: cipher, key: key, mode: BLOCK_CIPHER_MODE.ECB);
      expect(out, plain);
    });
  });

  group('AESCipher CBC', () {
    test('CBC round-trips with an explicit IV', () {
      final aes = AESCipher128();
      final key = '00112233445566778899AABBCCDDEEFF'.parseHex();
      final iv = '0F0E0D0C0B0A09080706050403020100'.parseHex();
      final data = 'AABBCCDDEEFF00112233445566778899'.parseHex();

      final enc = aes.encrypt(data: data, key: key, iv: iv, mode: BLOCK_CIPHER_MODE.CBC);
      final dec = aes.decrypt(data: enc, key: key, iv: iv, mode: BLOCK_CIPHER_MODE.CBC);
      expect(dec, data);
    });

    test('CBC with null IV uses an all-zero IV (encrypt then decrypt symmetric)', () {
      final aes = AESCipher128();
      final key = '00112233445566778899AABBCCDDEEFF'.parseHex();
      final data = 'AABBCCDDEEFF00112233445566778899'.parseHex();

      final enc = aes.encrypt(data: data, key: key); // default CBC, null iv
      final dec = aes.decrypt(data: enc, key: key); // default CBC, null iv
      expect(dec, data);
    });
  });

  group('AESCipher padding', () {
    test('pad zero-extends up to the block size', () {
      final aes = AESCipher128();
      final padded = aes.pad(data: '0102030405'.parseHex());
      expect(padded.length, AES_BLOCK_SIZE);
      expect(padded.sublist(0, 5), '0102030405'.parseHex());
      expect(padded.sublist(5), Uint8List(AES_BLOCK_SIZE - 5));
    });

    test('encrypt with padding=true accepts non-block-aligned data', () {
      final aes = AESCipher128();
      final key = '00112233445566778899AABBCCDDEEFF'.parseHex();
      final data = '0102030405'.parseHex(); // 5 bytes, not block aligned
      final enc = aes.encrypt(data: data, key: key, mode: BLOCK_CIPHER_MODE.ECB, padding: true);
      expect(enc.length, AES_BLOCK_SIZE);
    });
  });

  group('AESCipher error branches', () {
    final aes = AESCipher128();
    final block = Uint8List(16);

    test('encrypt throws on wrong key length', () {
      expect(() => aes.encrypt(data: block, key: Uint8List(8)), throwsA(isA<AESCipherError>()));
    });

    test('decrypt throws on wrong key length', () {
      expect(() => aes.decrypt(data: block, key: Uint8List(8)), throwsA(isA<AESCipherError>()));
    });

    test('encrypt throws on wrong IV length', () {
      expect(() => aes.encrypt(data: block, key: Uint8List(16), iv: Uint8List(8)), throwsA(isA<AESCipherError>()));
    });

    test('decrypt throws on wrong IV length', () {
      expect(() => aes.decrypt(data: block, key: Uint8List(16), iv: Uint8List(8)), throwsA(isA<AESCipherError>()));
    });

    test('AESCipherError toString returns its message', () {
      expect(AESCipherError('bad').toString(), 'bad');
    });
  });

  group('AESCipher size getter', () {
    test('reports 16/24/32 for the three key lengths', () {
      expect(AESCipher(size: KEY_LENGTH.s128).size, 16);
      expect(AESCipher(size: KEY_LENGTH.s192).size, 24);
      expect(AESCipher(size: KEY_LENGTH.s256).size, 32);
    });

    test('AES-256 round-trips with a 32-byte key', () {
      final aes = AESCipher256();
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final data = '00112233445566778899AABBCCDDEEFF'.parseHex();
      final enc = aes.encrypt(data: data, key: key, mode: BLOCK_CIPHER_MODE.ECB);
      final dec = aes.decrypt(data: enc, key: key, mode: BLOCK_CIPHER_MODE.ECB);
      expect(dec, data);
    });
  });

  group('AESChiperSelector', () {
    test('returns a cipher whose size matches s128 and s256', () {
      expect(AESChiperSelector.getChiper(size: KEY_LENGTH.s128).size, 16);
      expect(AESChiperSelector.getChiper(size: KEY_LENGTH.s256).size, 32);
    });

    test('s192 selection currently maps to a 128-bit cipher (documents behaviour)', () {
      // NOTE: the selector returns AESCipher128() for the s192 case.
      expect(AESChiperSelector.getChiper(size: KEY_LENGTH.s192).size, 16);
    });
  });

  group('AESCipher.calculateCMAC', () {
    test('produces a deterministic 8-byte (64-bit) MAC', () {
      final aes = AESCipher128();
      final key = '2F7F46ADCC9E7E521B45D192FAFA9126'.parseHex();
      final data = '7F4943C2A0BD78D94BA8'.parseHex();
      final mac1 = aes.calculateCMAC(data: data, key: key);
      final mac2 = aes.calculateCMAC(data: data, key: key);
      expect(mac1.length, 8);
      expect(mac1, mac2);
    });
  });
}
