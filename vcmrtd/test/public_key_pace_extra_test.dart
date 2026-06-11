// NEW tests for lib/src/proto/public_key_pace.dart covering branches not in
// public_key_pace_test.dart: fromHex / fromECPoint constructors, toBytes,
// toRelavantBytes, getters, toString, and the entire PublicKeyPACEdH (DH) class.

import 'package:pointycastle/ecc/curves/brainpoolp256r1.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';

void main() {
  group('PublicKeyPACEeCDH', () {
    test('agreementAlgorithm getter is ECDH', () {
      final k = PublicKeyPACEeCDH(x: BigInt.from(1), y: BigInt.from(2));
      expect(k.algo, TOKEN_AGREEMENT_ALGO.ECDH);
      expect(k.agreementAlgorithm, TOKEN_AGREEMENT_ALGO.ECDH);
    });

    test('x/y getters return the supplied BigInts', () {
      final k = PublicKeyPACEeCDH(x: BigInt.from(0xAB), y: BigInt.from(0xCD));
      expect(k.x, BigInt.from(0xAB));
      expect(k.y, BigInt.from(0xCD));
    });

    test('toBytes concatenates xBytes and yBytes', () {
      final k = PublicKeyPACEeCDH(x: BigInt.parse('AABB', radix: 16), y: BigInt.parse('CCDD', radix: 16));
      expect(k.toBytes(), 'AABBCCDD'.parseHex());
    });

    test('toRelavantBytes returns only xBytes', () {
      final k = PublicKeyPACEeCDH(x: BigInt.parse('AABB', radix: 16), y: BigInt.parse('CCDD', radix: 16));
      expect(k.toRelavantBytes(), 'AABB'.parseHex());
    });

    test('toString includes X and Y lines', () {
      final k = PublicKeyPACEeCDH(x: BigInt.parse('AABB', radix: 16), y: BigInt.parse('CCDD', radix: 16));
      final s = k.toString();
      expect(s, contains('X: aabb'));
      expect(s, contains('Y: ccdd'));
    });

    test('fromHex splits an even-length buffer into equal x and y halves', () {
      final k = PublicKeyPACEeCDH.fromHex(hexKey: 'AABBCCDD'.parseHex());
      expect(k.x, BigInt.parse('AABB', radix: 16));
      expect(k.y, BigInt.parse('CCDD', radix: 16));
      expect(k.toBytes(), 'AABBCCDD'.parseHex());
    });

    test('fromECPoint extracts coordinates from a real curve point', () {
      final domain = ECCurve_brainpoolp256r1();
      // G * 1 == G; use the generator as a valid point on the curve.
      final point = domain.G;
      final k = PublicKeyPACEeCDH.fromECPoint(public: point);
      expect(k.x, point.x!.toBigInteger());
      expect(k.y, point.y!.toBigInteger());
      expect(k.agreementAlgorithm, TOKEN_AGREEMENT_ALGO.ECDH);
    });
  });

  group('PublicKeyPACEdH (DH)', () {
    final pubBytes = '0102030405'.parseHex();
    final k = PublicKeyPACEdH(pub: pubBytes);

    test('algo / agreementAlgorithm is DH', () {
      expect(k.algo, TOKEN_AGREEMENT_ALGO.DH);
      expect(k.agreementAlgorithm, TOKEN_AGREEMENT_ALGO.DH);
    });

    test('pub getter returns the raw bytes', () {
      expect(k.pub, pubBytes);
    });

    test('toBytes and toRelavantBytes both return the raw public value', () {
      expect(k.toBytes(), pubBytes);
      expect(k.toRelavantBytes(), pubBytes);
    });

    test('toString returns hex of the public value', () {
      expect(k.toString(), '0102030405');
    });

    test('is usable polymorphically as PublicKeyPACE', () {
      final PublicKeyPACE base = k;
      expect(base.toBytes(), pubBytes);
      expect(base.agreementAlgorithm, TOKEN_AGREEMENT_ALGO.DH);
    });
  });
}
