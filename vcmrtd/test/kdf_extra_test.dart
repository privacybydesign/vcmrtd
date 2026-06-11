// New unit tests for lib/src/crypto/kdf.dart targeting branches NOT covered
// by the existing kdf_test.dart: AES-192/256, CMAC-192/256, paceMode (counter
// 3) for encryption keys, and the raw KDF() function / DeriveKey.derive switch.
//
// Expected outputs were computed independently from the ICAO 9303 algorithm
// (preimage = keySeed || counter[4 bytes BE], hashed with SHA-1 or SHA-256,
// truncated per key length) to avoid asserting the implementation against
// itself.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import 'package:vcmrtd/src/crypto/kdf.dart';
import 'package:vcmrtd/src/extension/string_apis.dart';

void main() {
  // Shared secret from ICAO 9303 Appendix G (also used in existing kdf_test).
  final seed = '28768D20701247DAE81804C9E780EDE582A9996DB4A315020B2733197DB84925'.parseHex();

  group('AES-256 / CMAC-256 (SHA-256, full 32 bytes)', () {
    test('aes256 uses counter mode 1 (ENC)', () {
      expect(DeriveKey.aes256(seed), '8419651a9932a555fe20d96406746a82f750f4ccb3d6be786d4630bcc681bf0e'.parseHex());
      expect(DeriveKey.aes256(seed).length, 32);
    });

    test('cmac256 uses counter mode 2 (MAC)', () {
      expect(DeriveKey.cmac256(seed), 'aa35fdb8d201bc2fd2bd98550c6fe549568c5e769be67f04733673b7c910a59f'.parseHex());
      expect(DeriveKey.cmac256(seed).length, 32);
    });

    test('aes256 with paceMode uses counter mode 3', () {
      expect(
        DeriveKey.aes256(seed, paceMode: true),
        'cf2cf7835c1568dabf1934175e76d45676e0943b946284e9d3fde5fa68f31192'.parseHex(),
      );
    });
  });

  group('AES-192 / CMAC-192 (SHA-256, truncated to 24 bytes)', () {
    test('aes192 truncates to 24 bytes (counter 1)', () {
      expect(DeriveKey.aes192(seed), '8419651a9932a555fe20d96406746a82f750f4ccb3d6be78'.parseHex());
      expect(DeriveKey.aes192(seed).length, 24);
    });

    test('cmac192 truncates to 24 bytes (counter 2)', () {
      expect(DeriveKey.cmac192(seed), 'aa35fdb8d201bc2fd2bd98550c6fe549568c5e769be67f04'.parseHex());
      expect(DeriveKey.cmac192(seed).length, 24);
    });
  });

  group('paceMode counter 3 for SHA-1 based keys', () {
    test('aes128 with paceMode differs from non-pace and matches counter-3 KDF', () {
      final pace = DeriveKey.aes128(seed, paceMode: true);
      final normal = DeriveKey.aes128(seed);
      expect(pace, 'acb3cce02946e3233c362d3fc68b78de'.parseHex());
      expect(pace, isNot(normal));
    });

    test('desEDE with paceMode produces a 16-byte parity-adjusted key', () {
      final pace = DeriveKey.desEDE(seed, paceMode: true);
      expect(pace.length, 16);
      // Even parity adjustment guarantees odd number of set bits per byte.
      for (final b in pace) {
        var count = 0;
        for (var j = 0; j < 8; j++) {
          count += (b >> j) & 0x01;
        }
        expect(count.isOdd, isTrue);
      }
    });
  });

  group('raw KDF function', () {
    test('SHA-1 KDF returns a 20-byte digest of keySeed||counter', () {
      final out = KDF(sha1, seed, Int32(1));
      expect(out.length, 20);
    });

    test('SHA-256 KDF returns a 32-byte digest', () {
      final out = KDF(sha256, seed, Int32(2));
      expect(out.length, 32);
      // Equivalent to cmac256 (which is the full SHA-256 with counter 2).
      expect(out, DeriveKey.cmac256(seed));
    });

    test('different counters yield different digests', () {
      expect(KDF(sha256, seed, Int32(1)), isNot(KDF(sha256, seed, Int32(2))));
    });
  });

  group('DeriveKey.derive dispatch', () {
    test('CMAC192 via derive matches cmac192 helper', () {
      expect(DeriveKey.derive(DeriveKeyType.CMAC192, seed), DeriveKey.cmac192(seed));
    });

    test('AES256 via derive matches aes256 helper', () {
      expect(DeriveKey.derive(DeriveKeyType.AES256, seed), DeriveKey.aes256(seed));
    });

    test('ISO9797MacAlg3 produces a 16-byte key (counter 2, parity adjusted)', () {
      final key = DeriveKey.iso9797MacAlg3(Uint8List.fromList(seed));
      expect(key.length, 16);
    });
  });
}
