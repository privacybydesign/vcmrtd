// New unit tests for lib/src/proto/domain_parameter.dart
// Covers DomainParameter getters, toString, operator== branches and the
// ICAO_DOMAIN_PARAMETERS lookup table entries.

import 'package:test/test.dart';
import 'package:vcmrtd/src/proto/domain_parameter.dart';

void main() {
  group('DomainParameter getters and toString', () {
    test('exposes all fields via getters', () {
      final dp = DomainParameter(
        id: 99,
        name: 'TestCurve',
        size: 256,
        type: DomainParameterType.ECP,
        isSupported: true,
      );
      expect(dp.id, 99);
      expect(dp.name, 'TestCurve');
      expect(dp.size, 256);
      expect(dp.type, DomainParameterType.ECP);
      expect(dp.isSupported, isTrue);
    });

    test('toString includes id, name, size, type and isSupported', () {
      final dp = DomainParameter(
        id: 12,
        name: 'NIST P-256 (secp256r1)',
        size: 256,
        type: DomainParameterType.ECP,
        isSupported: true,
      );
      final s = dp.toString();
      expect(s, contains('id: 12'));
      expect(s, contains('NIST P-256'));
      expect(s, contains('size: 256'));
      expect(s, contains('ECP'));
      expect(s, contains('isSupported: true'));
    });
  });

  group('DomainParameter operator==', () {
    test('equal when ids match (ignores other fields)', () {
      final a = DomainParameter(id: 5, name: 'A', size: 1, type: DomainParameterType.GFP, isSupported: false);
      final b = DomainParameter(id: 5, name: 'B', size: 2, type: DomainParameterType.ECP, isSupported: true);
      expect(a == b, isTrue);
    });

    test('not equal when ids differ', () {
      final a = DomainParameter(id: 5, name: 'A', size: 1, type: DomainParameterType.GFP, isSupported: false);
      final b = DomainParameter(id: 6, name: 'A', size: 1, type: DomainParameterType.GFP, isSupported: false);
      expect(a == b, isFalse);
    });

    test('not equal when compared to a non-DomainParameter', () {
      final a = DomainParameter(id: 5, name: 'A', size: 1, type: DomainParameterType.GFP, isSupported: false);
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a domain parameter', isFalse);
    });
  });

  group('ICAO_DOMAIN_PARAMETERS table', () {
    test('contains the GFP MODP groups (ids 0,1,2) marked unsupported', () {
      for (final id in [0, 1, 2]) {
        final dp = ICAO_DOMAIN_PARAMETERS[id]!;
        expect(dp.type, DomainParameterType.GFP);
        expect(dp.isSupported, isFalse);
        expect(dp.id, id);
      }
    });

    test('NIST P-256 (id 12) is the only one flagged supported', () {
      expect(ICAO_DOMAIN_PARAMETERS[12]!.isSupported, isTrue);
      expect(ICAO_DOMAIN_PARAMETERS[12]!.name, 'NIST P-256 (secp256r1)');
      expect(ICAO_DOMAIN_PARAMETERS[12]!.size, 256);

      final supported = ICAO_DOMAIN_PARAMETERS.values.where((d) => d.isSupported).toList();
      expect(supported.length, 1);
      expect(supported.single.id, 12);
    });

    test('all EC entries (8..18) are typed ECP with expected sizes', () {
      final expectedSizes = {
        8: 192,
        9: 192,
        10: 224,
        11: 224,
        12: 256,
        13: 256,
        14: 320,
        15: 384,
        16: 384,
        17: 512,
        18: 521,
      };
      expectedSizes.forEach((id, size) {
        final dp = ICAO_DOMAIN_PARAMETERS[id]!;
        expect(dp.type, DomainParameterType.ECP, reason: 'id $id type');
        expect(dp.size, size, reason: 'id $id size');
      });
    });

    test('unknown id is absent from the table', () {
      expect(ICAO_DOMAIN_PARAMETERS.containsKey(7), isFalse);
      expect(ICAO_DOMAIN_PARAMETERS[7], isNull);
    });
  });

  group('module-level p constant', () {
    test('p is a large prime-sized BigInt', () {
      expect(p.bitLength, greaterThan(1000));
    });
  });
}
