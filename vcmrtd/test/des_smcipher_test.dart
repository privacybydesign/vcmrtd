// NEW tests for lib/src/proto/des_smcipher.dart (3DES secure-messaging cipher).
//
// The MAC reference value is cross-checked against ICAO 9303 p11 Appendix D.4:
// MAC of N with KSmac=F1CB1F1FB5ADF208806B89DC579DC1F8 == BF8B92D635FF24F8
// (same value asserted in the existing sm_test for the protected command CC).

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/proto/des_smcipher.dart';

void main() {
  final encKey = '979EC13B1CBFE9DCD01AB0FED307EAE5'.parseHex();
  final macKey = 'F1CB1F1FB5ADF208806B89DC579DC1F8'.parseHex();

  DES_SMCipher newCipher() => DES_SMCipher(encKey, macKey);

  test('type and cipherAlgorithm are DESede', () {
    final c = newCipher();
    expect(c.type, CipherAlgorithm.DESede);
    expect(c.cipherAlgorithm, CipherAlgorithm.DESede);
  });

  test('encrypt then decrypt round-trips (zero IV, no padding)', () {
    final c = newCipher();
    final data = '0011223344556677'.parseHex(); // exactly one 8-byte block
    final enc = c.encrypt(data);
    expect(enc, isNot(equals(data)));
    expect(c.decrypt(enc), data);
  });

  test('encrypt is deterministic for fixed key + zero IV', () {
    final c = newCipher();
    final enc = c.encrypt('0011223344556677'.parseHex());
    expect(enc, 'B48462AE9D4B68E0'.parseHex());
  });

  test('multi-block round-trip', () {
    final c = newCipher();
    final data = '00112233445566778899AABBCCDDEEFF'.parseHex(); // two blocks
    expect(c.decrypt(c.encrypt(data)), data);
  });

  test('mac matches ICAO 9303 D.4 reference value', () {
    final c = newCipher();
    final n = '887022120C06C2270CA4020C800000008709016375432908C044F68000000000'.parseHex();
    expect(c.mac(n), 'BF8B92D635FF24F8'.parseHex());
  });

  test('mac output is 8 bytes', () {
    final c = newCipher();
    final n = '887022120C06C2280CB00000800000009701048000000000'.parseHex();
    expect(c.mac(n).length, 8);
  });
}
