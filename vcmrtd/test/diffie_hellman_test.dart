// New unit tests for lib/src/crypto/diffie_hellman.dart
// Exercises DH key generation / shared-secret math with small known
// textbook parameters (p=23, g=5) where results are hand-verifiable.

import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/src/crypto/diffie_hellman.dart';

void main() {
  // Classic textbook DH group.
  final p = BigInt.from(23);
  final g = BigInt.from(5);

  DhParameterSpec smallSpec({int length = 256}) => DhParameterSpec(p: p, g: g, length: length);

  group('DhParameterSpec', () {
    test('exposes p, g and default length', () {
      final spec = DhParameterSpec(p: p, g: g);
      expect(spec.p, p);
      expect(spec.g, g);
      expect(spec.length, DhParameterSpec.defaultPrivateKeyLength);
      expect(spec.length, 256);
    });

    test('honours explicit length', () {
      final spec = DhParameterSpec(p: p, g: g, length: 8);
      expect(spec.length, 8);
    });

    test('toString contains length and label', () {
      final s = smallSpec(length: 16).toString();
      expect(s, contains('DhParameterSpec'));
      expect(s, contains('length: 16'));
    });
  });

  group('DhKeyPair', () {
    test('exposes public and private keys', () {
      final kp = DhKeyPair(publicKey: BigInt.from(8), privateKey: BigInt.from(6));
      expect(kp.publicKey, BigInt.from(8));
      expect(kp.privateKey, BigInt.from(6));
    });

    test('toString only reveals public key', () {
      final kp = DhKeyPair(publicKey: BigInt.from(8), privateKey: BigInt.from(6));
      final s = kp.toString();
      expect(s, contains('PublicKey'));
      expect(s, isNot(contains('PrivateKey')));
    });

    test('toStringAlsoPrivate reveals both', () {
      final kp = DhKeyPair(publicKey: BigInt.from(8), privateKey: BigInt.from(6));
      final s = kp.toStringAlsoPrivate();
      expect(s, contains('PublicKey'));
      expect(s, contains('PrivateKey'));
    });
  });

  group('DHpkcs3Engine with known private key', () {
    test('createKeyPair / fromPrivate computes public = g^priv mod p', () {
      // priv a = 6 -> pub = 5^6 mod 23 = 8
      final engine = DHpkcs3Engine.fromPrivate(private: BigInt.from(6), parameterSpec: smallSpec());
      expect(engine.privateKey, BigInt.from(6));
      expect(engine.publicKey, BigInt.from(8));
      expect(engine.parameterSpec.p, p);
    });

    test('computeSecretKey matches the other party (symmetric)', () {
      // a = 6 -> pubA = 8 ; b = 15 -> pubB = 19 ; shared = 2
      final alice = DHpkcs3Engine.fromPrivate(private: BigInt.from(6), parameterSpec: smallSpec());
      final bob = DHpkcs3Engine.fromPrivate(private: BigInt.from(15), parameterSpec: smallSpec());

      expect(alice.publicKey, BigInt.from(8));
      expect(bob.publicKey, BigInt.from(19));

      final sAlice = alice.computeSecretKey(otherPublicKey: bob.publicKey);
      final sBob = bob.computeSecretKey(otherPublicKey: alice.publicKey);

      expect(sAlice, BigInt.from(2));
      expect(sAlice, sBob);
    });

    test('computeGenerator = (g^nonce * H) mod p', () {
      // priv = 6, otherPub = 19, nonce = 3 -> H = 19^6 mod 23 = 2 ; (5^3 * 2) mod 23 = 20
      final engine = DHpkcs3Engine.fromPrivate(private: BigInt.from(6), parameterSpec: smallSpec());
      final gen = engine.computeGenerator(otherPublicKey: BigInt.from(19), nonce: BigInt.from(3));
      expect(gen, BigInt.from(20));
    });

    test('constructor with privateKey sets the key pair (no generation)', () {
      final engine = DHpkcs3Engine(parameterSpec: smallSpec(), privateKey: BigInt.from(6));
      expect(engine.publicKey, BigInt.from(8));
      expect(engine.privateKey, BigInt.from(6));
    });
  });

  group('DHpkcs3Engine with generated private key (seeded, deterministic)', () {
    test('generated private key lies in [2^(len-1), 2^len) and public key is consistent', () {
      const len = 8; // small but multiple of 8 (RandomExtension requires % 8 == 0)
      final engine = DHpkcs3Engine(parameterSpec: smallSpec(length: len), seed: 42);

      final lower = BigInt.two.pow(len - 1);
      final upper = BigInt.two * lower;
      expect(engine.privateKey >= lower, isTrue);
      expect(engine.privateKey < upper, isTrue);

      // public must equal g^priv mod p
      expect(engine.publicKey, g.modPow(engine.privateKey, p));
    });

    test('same seed produces same key pair (deterministic)', () {
      final e1 = DHpkcs3Engine(parameterSpec: smallSpec(length: 8), seed: 7);
      final e2 = DHpkcs3Engine(parameterSpec: smallSpec(length: 8), seed: 7);
      expect(e1.privateKey, e2.privateKey);
      expect(e1.publicKey, e2.publicKey);
    });
  });

  group('RandomExtension.nextBigInt', () {
    test('produces a BigInt of the requested byte width', () {
      final rnd = Random(123);
      final v = rnd.nextBigInt(16); // 2 bytes
      expect(v >= BigInt.zero, isTrue);
      expect(v < BigInt.two.pow(16), isTrue);
    });

    test('throws when bitLength is not a multiple of 8', () {
      final rnd = Random(1);
      expect(() => rnd.nextBigInt(7), throwsA(anything));
    });
  });

  group('Uint8ListExtension.toBigInt', () {
    test('reads bytes big-endian', () {
      final bytes = Uint8List.fromList([0x01, 0x00]); // 256
      expect(bytes.toBigInt(), BigInt.from(256));
    });

    test('empty list is zero', () {
      expect(Uint8List.fromList([]).toBigInt(), BigInt.zero);
    });
  });

  group('DHpkcs3EngineError', () {
    test('toString returns the message', () {
      final e = DHpkcs3EngineError('boom');
      expect(e.toString(), 'boom');
    });
  });
}
