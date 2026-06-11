// New unit tests for lib/src/lds/substruct/pace_info.dart
// Drives PaceInfo(content: ...) directly with hand-built ASN1Sequences to
// cover branches not exercised by efcard_access_test: <2-element error,
// invalid/unregistered protocol error, wrong-version error, the optional
// parameterId present/absent paths, and the DH-vs-ECDH domain-parameter
// support branch (including the "unsupported -> caught" fall-through).

import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:test/test.dart';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/ef.dart';
import 'package:vcmrtd/src/lds/substruct/pace_info.dart';

ASN1Sequence _seq(String hex) {
  final parser = ASN1Parser(hex.parseHex());
  return parser.nextObject() as ASN1Sequence;
}

void main() {
  group('PaceInfo error branches', () {
    test('throws EfParseError when sequence has fewer than 2 elements', () {
      final content = _seq('300C060A04007F00070202040202');
      expect(() => PaceInfo(content: content), throwsA(isA<EfParseError>()));
    });

    test('throws EfParseError when protocol OID is not a registered PACE protocol', () {
      // id-TA (0.4.0.127.0.7.2.2.2) is not a PACE protocol.
      final content = _seq('300D060804007F0007020202020102');
      expect(() => PaceInfo(content: content), throwsA(isA<EfParseError>()));
    });

    test('throws EfParseError when version is not 2', () {
      // valid ECDH-GM-128 OID but version = 3
      final content = _seq('300F060A04007F00070202040202020103');
      expect(() => PaceInfo(content: content), throwsA(isA<EfParseError>()));
    });
  });

  group('PaceInfo parameterId handling', () {
    test('ECDH protocol with parameterId 13 is supported', () {
      final content = _seq('3012060A04007F0007020204020202010202010D');
      final info = PaceInfo(content: content);
      expect(info.version, 2);
      expect(info.isParameterSet, isTrue);
      expect(info.parameterId, 13);
      expect(info.isPaceDomainParameterSupported, isTrue);
    });

    test('two-element sequence leaves parameterId null and support false', () {
      final content = _seq('300F060A04007F00070202040202020102');
      final info = PaceInfo(content: content);
      expect(info.isParameterSet, isFalse);
      expect(info.parameterId, isNull);
      expect(info.isPaceDomainParameterSupported, isFalse);
    });
  });

  group('PaceInfo DH token-agreement support branch', () {
    test('DH protocol with parameterId 0 is supported (DH curve 0 exists)', () {
      final content = _seq('3012060A04007F00070202040102020102020100');
      final info = PaceInfo(content: content);
      expect(info.parameterId, 0);
      // DomainParameterSelectorDH.getDomainParameter(0) succeeds.
      expect(info.isPaceDomainParameterSupported, isTrue);
    });

    test('DH protocol with parameterId 13 is NOT supported (DH selector throws, caught)', () {
      // parameterId 13 exists in the ICAO table but the DH selector only
      // implements 0/1/2, so getDomainParameter throws and the catch sets
      // isPaceDomainParameterSupported = false (without rethrowing).
      final content = _seq('3012060A04007F0007020204010202010202010D');
      final info = PaceInfo(content: content);
      expect(info.parameterId, 13);
      expect(info.isPaceDomainParameterSupported, isFalse);
    });
  });

  group('PaceInfo accessors', () {
    test('toString and getMappingType are accessible', () {
      final content = _seq('3012060A04007F0007020204020202010202010D');
      final info = PaceInfo(content: content);
      expect(info.toString(), contains('PaceInfo'));
      expect(info.getMappingType(), isA<String>());
      expect(info.protocol.identifierString, '0.4.0.127.0.7.2.2.4.2.2');
    });
  });
}
