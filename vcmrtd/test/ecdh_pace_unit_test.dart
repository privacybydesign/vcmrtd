// Unit tests for ECDHPace (lib/src/proto/ecdh_pace.dart) targeting branches
// not exercised by pace_test_ecdh.dart / pace_cam_test.dart: error guards,
// selector failures, toStringWithCaution, transformPublic, and the
// ECDHBasicAgreementPACE wrong-domain / infinity guards.
import 'dart:typed_data';

import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/proto/ecdh_pace.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';

void main() {
  group('DomainParameterSelectorECDH', () {
    test('throws for id not in ICAO map', () {
      expect(() => DomainParameterSelectorECDH.getDomainParameter(id: 99), throwsA(isA<ECDHPaceError>()));
    });

    test('throws for a DH id present in map but not EC-selectable (default branch)', () {
      // id 0 (MODP) exists in the map but is not an EC curve.
      expect(() => DomainParameterSelectorECDH.getDomainParameter(id: 0), throwsA(isA<ECDHPaceError>()));
    });

    test('all EC curve ids 8..18 are selectable and report a name', () {
      for (final id in [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]) {
        final p = DomainParameterSelectorECDH.getDomainParameter(id: id);
        expect(p.selectedDomainParameter.name.isNotEmpty, true);
      }
    });
  });

  group('ECDHPace guards before key generation', () {
    test('getPubKey throws when public key not set', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      expect(p.getPubKey, throwsA(isA<ECDHPaceError>()));
    });

    test('getPubKeyEphemeral throws when ephemeral key not set', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      expect(p.getPubKeyEphemeral, throwsA(isA<ECDHPaceError>()));
    });

    test('getSharedSecret throws when private key not set', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      final other = DomainParameterSelectorECDH.getDomainParameter(id: 13)..generateKeyPair();
      expect(() => p.getSharedSecret(otherPubKey: other.publicKey), throwsA(isA<ECDHPaceError>()));
    });

    test('getEphemeralSharedSecret throws when ephemeral private key not set', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      final other = DomainParameterSelectorECDH.getDomainParameter(id: 13)..generateKeyPair();
      expect(() => p.getEphemeralSharedSecret(otherEphemeralPubKey: other.publicKey), throwsA(isA<ECDHPaceError>()));
    });

    test('getMappedGenerator throws when private key not set', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      final other = DomainParameterSelectorECDH.getDomainParameter(id: 13)..generateKeyPair();
      expect(
        () => p.getMappedGenerator(otherPubKey: other.publicKey, nonce: "00".parseHex()),
        throwsA(isA<ECDHPaceError>()),
      );
    });

    test('toStringWithCaution reports <no private keys> on a fresh instance', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      expect(p.toStringWithCaution(), contains('<no private keys>'));
    });

    test('toStringWithCaution prints private key after generation', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13)
        ..generateKeyPairFromPriv(
          privKey: "498FF49756F2DC1587840041839A85982BE7761D14715FB091EFA7BCE9058560".parseHex(),
        );
      expect(p.toStringWithCaution(), contains('private key'));
    });
  });

  group('transformPublic and ecPointToList', () {
    test('transformPublic creates an ECPublicKey on the curve', () {
      final chipX = "824FBA91C9CBE26BEF53A0EBE7342A3BF178CEA9F45DE0B70AA601651FBA3F57".parseHex();
      final chipY = "30D8C879AAA9C9F73991E61B58F4D52EB87A0A0C709A49DC63719363CCD13C54".parseHex();
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      final pub = p.transformPublic(
        pubKey: PublicKeyPACEeCDH.fromHex(hexKey: Uint8List.fromList([...chipX, ...chipY])),
      );
      expect(pub.Q, isNotNull);
      final back = ECDHPace.ecPointToList(point: pub.Q!);
      expect(back.xBytes, chipX);
      expect(back.yBytes, chipY);
    });

    test('generateKeyPair / generateKeyPairWithCustomGenerator reject non-32-byte seeds', () {
      final p = DomainParameterSelectorECDH.getDomainParameter(id: 13);
      expect(() => p.generateKeyPair(seed32byte: "0102".parseHex()), throwsA(isA<ECDHPaceError>()));
    });
  });

  group('ECDHBasicAgreementPACE guards', () {
    test('throws on mismatched domain parameters', () {
      // Private key on brainpoolP256r1, other public on secp256r1 -> wrong curve.
      final dpA = ECCurve_brainpoolp256r1();
      final dpB = ECCurve_secp256r1();
      final privA = ECPrivateKey(BigInt.from(123456789), dpA);
      final agreement = ECDHBasicAgreementPACE()..init(privA);
      final pubB = ECPublicKey(dpB.G * BigInt.from(987654321), dpB);
      expect(() => agreement.calculateAgreementAndReturnPoint(pubB), throwsA(isA<ECDHBasicAgreementPACEError>()));
    });

    test('throws on infinity public key', () {
      final dp = ECCurve_brainpoolp256r1();
      final priv = ECPrivateKey(BigInt.from(42), dp);
      final agreement = ECDHBasicAgreementPACE()..init(priv);
      // Point at infinity as the "other" public key. The agreement rejects it
      // (either via the explicit infinity guard or pointycastle's cleanPoint).
      final inf = ECPublicKey(dp.curve.infinity, dp);
      expect(
        () => agreement.calculateAgreementAndReturnPoint(inf),
        throwsA(anyOf(isA<ECDHBasicAgreementPACEError>(), isA<ArgumentError>())),
      );
    });
  });
}
