// NEW tests for lib/src/proto/can_key.dart and lib/src/proto/dba_key.dart
// covering construction validation, the CAN byte encoding, and the
// per-cipher Kpi derivation branches not exercised by access_key_test.dart.

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/proto/can_key.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/types/document_type.dart';

void main() {
  group('CanKey construction & validation', () {
    test('passport CAN must be 6 digits — valid', () {
      final k = CanKey('123456', DocumentType.passport);
      // CAN stored as ASCII byte string '123456'
      expect(k.can, '313233343536'.parseHex());
    });

    test('passport CAN rejects non-6-digit input', () {
      expect(() => CanKey('12345', DocumentType.passport), throwsA(isA<CanKeysError>()));
      expect(() => CanKey('1234567', DocumentType.passport), throwsA(isA<CanKeysError>()));
      expect(() => CanKey('12345A', DocumentType.passport), throwsA(isA<CanKeysError>()));
    });

    test('driving licence CAN must be 10 uppercase alphanumerics — valid', () {
      final k = CanKey('ABCD123456', DocumentType.drivingLicence);
      expect(k.can, '41424344313233343536'.parseHex());
    });

    test('driving licence CAN rejects wrong length / lowercase', () {
      expect(() => CanKey('ABCD12345', DocumentType.drivingLicence), throwsA(isA<CanKeysError>()));
      expect(() => CanKey('abcd123456', DocumentType.drivingLicence), throwsA(isA<CanKeysError>()));
    });

    test('CanKeysError.toString returns the message', () {
      final e = CanKeysError('boom');
      expect(e.toString(), 'boom');
    });

    test('PACE_REF_KEY_TAG is 0x02 (CAN)', () {
      expect(CanKey('123456', DocumentType.passport).PACE_REF_KEY_TAG, 0x02);
    });
  });

  group('CanKey.Kpi derivation branches', () {
    final k = CanKey('123456', DocumentType.passport);

    test('DESede branch', () {
      expect(k.Kpi(CipherAlgorithm.DESede, KEY_LENGTH.s128), '581568cda83d64209dcdb9570232610e'.parseHex());
    });

    test('AES-128 branch (matches access_key_test vector)', () {
      expect(k.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s128), '591468cda83d65219cccb8560233600f'.parseHex());
    });

    test('AES-192 branch produces 24-byte key', () {
      final key = k.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s192);
      expect(key.length, 24);
      expect(key, '8df3278fb32026e66277357fcd6c826dbeb3de32088b2531'.parseHex());
    });

    test('AES-256 branch produces 32-byte key', () {
      final key = k.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s256);
      expect(key.length, 32);
      expect(key, '8df3278fb32026e66277357fcd6c826dbeb3de32088b2531757d753940185923'.parseHex());
    });

    test('toString warns and contains CAN hex', () {
      expect(k.toString(), contains('313233343536'));
    });
  });

  group('DBAKey extra branches', () {
    final dba = DBAKey('T22000129', DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

    test('PACE_REF_KEY_TAG is 0x01 (MRZ)', () {
      expect(dba.PACE_REF_KEY_TAG, 0x01);
    });

    test('getters round-trip mrtdNumber / dateOfBirth / dateOfExpiry', () {
      expect(dba.mrtdNumber, 'T22000129');
      expect(dba.dateOfBirth, DateTime(1964, 8, 12));
      expect(dba.dateOfExpiry, DateTime(2010, 10, 31));
    });

    test('Kpi DESede branch', () {
      expect(dba.Kpi(CipherAlgorithm.DESede, KEY_LENGTH.s128), '89dfd0b36725ec1f624c1989312949dc'.parseHex());
    });

    test('Kpi AES-192 branch (24 bytes)', () {
      final key = dba.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s192);
      expect(key.length, 24);
      expect(key, 'd79a23c126202ac9051febfbc0e8a03b1c6645d85752b4b7'.parseHex());
    });

    test('Kpi AES-256 branch (32 bytes)', () {
      final key = dba.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s256);
      expect(key.length, 32);
      expect(key, 'd79a23c126202ac9051febfbc0e8a03b1c6645d85752b4b71408fa229ab6d56b'.parseHex());
    });

    test('keySeed is cached (same instance returned on repeated access)', () {
      final s1 = dba.keySeed;
      final s2 = dba.keySeed;
      expect(identical(s1, s2), isTrue);
    });

    test('BAC-mode seed is 16 bytes, PACE-mode seed is 20 bytes', () {
      final bac = DBAKey('T22000129', DateTime(1964, 8, 12), DateTime(2010, 10, 31));
      expect(bac.keySeed.length, 16);
      expect(dba.keySeed.length, 20);
    });

    test('toString contains the document number', () {
      expect(dba.toString(), contains('T22000129'));
    });
  });

  group('BapKey', () {
    test('derives 16-byte seed and stable enc/mac keys', () {
      final a = BapKey('hello-seed');
      final b = BapKey('hello-seed');
      expect(a.encKey, b.encKey);
      expect(a.macKey, b.macKey);
      expect(a.encKey.length, 16);
      expect(a.toString(), startsWith('BapKey(seed='));
    });

    test('different seed inputs give different keys', () {
      expect(BapKey('a').encKey, isNot(equals(BapKey('b').encKey)));
    });
  });
}
