// New unit tests for lib/src/lds/asn1ObjectIdentifiers.dart
// Covers OIE (fromMap validation + error paths, equality), OIEPaceProtocol
// setParams switch branches (DESede/AES, key lengths, DH/ECDH, GM/IM/CAM,
// unknown -> throw), the ASN1ObjectIdentifierType singleton lookups
// (has/getOIDByIdentifierString + not-found error), and KEY_LENGTH enum.

import 'package:test/test.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';

void main() {
  group('OIE.fromMap validation', () {
    test('constructs from a valid map and toString includes its parts', () {
      final oie = OIE.fromMap(
        item: {
          'identifierString': '1.2.3',
          'readableName': 'test-oid',
          'identifier': <int>[1, 2, 3],
        },
      );
      expect(oie.identifierString, '1.2.3');
      expect(oie.readableName, 'test-oid');
      expect(oie.identifier, [1, 2, 3]);
      expect(oie.toString(), contains('1.2.3'));
      expect(oie.toString(), contains('test-oid'));
    });

    test('throws when a required key is missing', () {
      expect(() => OIE.fromMap(item: {'identifierString': '1.2.3', 'readableName': 'x'}), throwsA(isA<OIEexception>()));
    });

    test('throws when identifier is not List<int>', () {
      expect(
        () => OIE.fromMap(item: {'identifierString': '1.2.3', 'readableName': 'x', 'identifier': 'nope'}),
        throwsA(isA<OIEexception>()),
      );
    });

    test('throws when identifierString is not a String', () {
      expect(
        () => OIE.fromMap(
          item: {
            'identifierString': 123,
            'readableName': 'x',
            'identifier': <int>[1],
          },
        ),
        throwsA(isA<OIEexception>()),
      );
    });

    test('throws when readableName is not a String', () {
      expect(
        () => OIE.fromMap(
          item: {
            'identifierString': '1.2.3',
            'readableName': 9,
            'identifier': <int>[1],
          },
        ),
        throwsA(isA<OIEexception>()),
      );
    });

    test('instance fromMap() method (non-constructor) also validates', () {
      final oie = OIE(identifierString: 'a', readableName: 'b', identifier: [0]);
      expect(() => oie.fromMap(item: {'identifierString': '1.2.3', 'readableName': 'x'}), throwsA(isA<OIEexception>()));
    });
  });

  group('OIE equality (compareOnlyIdentifier)', () {
    test('equal when identifier lists match, regardless of other fields', () {
      final a = OIE(identifierString: 'x', readableName: 'X', identifier: [1, 2, 3]);
      final b = OIE(identifierString: 'y', readableName: 'Y', identifier: [1, 2, 3]);
      expect(a == b, isTrue);
      expect(a.compareOnlyIdentifier(identifier: [1, 2, 3]), isTrue);
    });

    test('not equal when identifier lists differ', () {
      final a = OIE(identifierString: 'x', readableName: 'X', identifier: [1, 2, 3]);
      final b = OIE(identifierString: 'x', readableName: 'X', identifier: [1, 2, 4]);
      expect(a == b, isFalse);
    });

    test('not equal to a non-OIE object', () {
      final a = OIE(identifierString: 'x', readableName: 'X', identifier: [1]);
      // ignore: unrelated_type_equality_checks
      expect(a == 'string', isFalse);
    });
  });

  group('OIEPaceProtocol.setParams switch branches', () {
    // readableName -> (cipher, keyLength, tokenAgreement, mapping)
    OIEPaceProtocol make(String readable, List<int> id) =>
        OIEPaceProtocol(identifierString: '0.0', readableName: readable, identifier: id);

    test('DH-GM 3DES', () {
      final p = make('id-PACE-DH-GM-3DES-CBC-CBC', [0, 4, 0, 127, 0, 7, 2, 2, 4, 1, 1]);
      expect(p.cipherAlgoritm, CipherAlgorithm.DESede);
      expect(p.keyLength, KEY_LENGTH.s128);
      expect(p.tokenAgreementAlgorithm, TOKEN_AGREEMENT_ALGO.DH);
      expect(p.mappingType, MAPPING_TYPE.GM);
    });

    test('DH-GM AES 128/192/256', () {
      expect(make('id-PACE-DH-GM-AES-CBC-CMAC-128', [0]).keyLength, KEY_LENGTH.s128);
      expect(make('id-PACE-DH-GM-AES-CBC-CMAC-192', [0]).keyLength, KEY_LENGTH.s192);
      final p256 = make('id-PACE-DH-GM-AES-CBC-CMAC-256', [0]);
      expect(p256.keyLength, KEY_LENGTH.s256);
      expect(p256.cipherAlgoritm, CipherAlgorithm.AES);
      expect(p256.mappingType, MAPPING_TYPE.GM);
    });

    test('DH-IM variants', () {
      expect(make('id-PACE-DH-IM-AES-CBC-CMAC-128', [0]).mappingType, MAPPING_TYPE.IM);
      expect(make('id-PACE-DH-IM-AES-CBC-CMAC-192', [0]).keyLength, KEY_LENGTH.s192);
      expect(make('id-PACE-DH-IM-AES-CBC-CMAC-256', [0]).keyLength, KEY_LENGTH.s256);
    });

    test('ECDH-GM variants', () {
      final p = make('id-PACE-ECDH-GM-3DES-CBC-CBC', [0]);
      expect(p.tokenAgreementAlgorithm, TOKEN_AGREEMENT_ALGO.ECDH);
      expect(p.cipherAlgoritm, CipherAlgorithm.DESede);
      expect(make('id-PACE-ECDH-GM-AES-CBC-CMAC-128', [0]).keyLength, KEY_LENGTH.s128);
      expect(make('id-PACE-ECDH-GM-AES-CBC-CMAC-192', [0]).keyLength, KEY_LENGTH.s192);
      expect(make('id-PACE-ECDH-GM-AES-CBC-CMAC-256', [0]).keyLength, KEY_LENGTH.s256);
    });

    test('ECDH-IM variants', () {
      expect(make('id-PACE-ECDH-IM-3DES-CBC-CBC', [0]).cipherAlgoritm, CipherAlgorithm.DESede);
      expect(make('id-PACE-ECDH-IM-AES-CBC-CMAC-128', [0]).mappingType, MAPPING_TYPE.IM);
      expect(make('id-PACE-ECDH-IM-AES-CBC-CMAC-192', [0]).keyLength, KEY_LENGTH.s192);
      expect(make('id-PACE-ECDH-IM-AES-CBC-CMAC-256', [0]).keyLength, KEY_LENGTH.s256);
    });

    test('ECDH-CAM variants', () {
      final cam128 = make('id-PACE-ECDH-CAM-AES-CBC-CMAC-128', [0]);
      expect(cam128.mappingType, MAPPING_TYPE.CAM);
      expect(cam128.keyLength, KEY_LENGTH.s128);
      expect(make('id-PACE-ECDH-CAM-AES-CBC-CMAC-192', [0]).keyLength, KEY_LENGTH.s192);
      expect(make('id-PACE-ECDH-CAM-AES-CBC-CMAC-256', [0]).keyLength, KEY_LENGTH.s256);
    });

    test('toString reflects parsed parameters', () {
      final p = make('id-PACE-ECDH-CAM-AES-CBC-CMAC-256', [0]);
      final s = p.toString();
      expect(s, contains('OIEPaceProtocol'));
      expect(s, contains('CAM'));
      expect(s, contains('s256'));
    });

    test('unknown readableName throws OIEexception', () {
      expect(() => make('id-PACE-TOTALLY-UNKNOWN', [0]), throwsA(isA<OIEexception>()));
    });
  });

  group('ASN1ObjectIdentifierType singleton', () {
    final t = ASN1ObjectIdentifierType.instance;

    test('instance is a singleton', () {
      expect(identical(ASN1ObjectIdentifierType.instance, ASN1ObjectIdentifierType.instance), isTrue);
    });

    test('hasOIDWithIdentifierString true for a registered custom PACE OID', () {
      expect(t.hasOIDWithIdentifierString(identifierString: '0.4.0.127.0.7.2.2.4.1.1'), isTrue);
    });

    test('hasOIDWithIdentifierString false for an unknown OID', () {
      expect(t.hasOIDWithIdentifierString(identifierString: '9.9.9.9'), isFalse);
    });

    test('getOIDByIdentifierString returns the matching map', () {
      final map = t.getOIDByIdentifierString(identifierString: '0.4.0.127.0.7.2.2.4.6.2');
      expect(map['readableName'], 'id-PACE-ECDH-CAM-AES-CBC-CMAC-128');
      expect(map['identifier'], [0, 4, 0, 127, 0, 7, 2, 2, 4, 6, 2]);
    });

    test('getOIDByIdentifierString throws on unknown OID', () {
      expect(
        () => t.getOIDByIdentifierString(identifierString: 'not.a.real.oid'),
        throwsA(isA<ASN1ObjectIdentifierObjectException>()),
      );
    });

    test('checkOID rejects maps missing keys or with wrong types', () {
      expect(t.checkOID(item: {'identifierString': '1.2', 'readableName': 'x'}), isFalse);
      expect(t.checkOID(item: {'identifierString': '1.2', 'readableName': 'x', 'identifier': 'bad'}), isFalse);
      expect(
        t.checkOID(
          item: {
            'identifierString': 5,
            'readableName': 'x',
            'identifier': <int>[1],
          },
        ),
        isFalse,
      );
      expect(
        t.checkOID(
          item: {
            'identifierString': '1.2',
            'readableName': 5,
            'identifier': <int>[1],
          },
        ),
        isFalse,
      );
      expect(
        t.checkOID(
          item: {
            'identifierString': '1.2',
            'readableName': 'x',
            'identifier': <int>[1],
          },
        ),
        isTrue,
      );
    });
  });

  group('oidHasPrefix', () {
    test('true only for strict children', () {
      expect(oidHasPrefix('0.4.0.127.0.7.2.2.4.2.2', '0.4.0.127.0.7.2.2.4.2'), isTrue);
      expect(oidHasPrefix('0.4.0.127.0.7.2.2.4.2', '0.4.0.127.0.7.2.2.4.2'), isFalse);
    });
  });

  group('KEY_LENGTH enum', () {
    test('carries the byte-size value', () {
      expect(KEY_LENGTH.s128.value, 16);
      expect(KEY_LENGTH.s192.value, 24);
      expect(KEY_LENGTH.s256.value, 32);
    });
  });

  group('exceptions', () {
    test('OIEexception carries a name and message', () {
      final e = OIEexception('boom');
      expect(e.exceptionName, 'OIEexception');
      expect(e.toString(), contains('boom'));
    });

    test('ASN1ObjectIdentifierObjectException carries a name', () {
      final e = ASN1ObjectIdentifierObjectException('bad');
      expect(e.exceptionName, 'ASN1ObjectIdentifierObjectException');
    });
  });
}
