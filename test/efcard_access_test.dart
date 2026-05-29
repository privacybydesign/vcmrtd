// Tests for EF.CardAccess SecurityInfos parsing.
//
// Test vectors are taken directly from gmrtd
// (https://github.com/gmrtd/gmrtd) so that vcmrtd's behaviour can be compared
// against an independent reference implementation that follows the same
// ICAO 9303 Part 11 §9.2 approach.
//
// Reference files in gmrtd:
//   - document/card_access_test.go      (TestNewCardAccessHappyAT / HappyDE)
//   - document/security_infos_test.go   (TestDecodeSecurityInfos,
//                                        TestDecodeSecurityInfosCardSecFile)
//
// These tests currently FAIL on master because `EfCardAccess.parse` only
// reads `set.elements[0]` and blindly casts it to a `PaceInfo`. See
// issue #120 for the full analysis — German passports place a
// TerminalAuthenticationInfo (id-TA, 0.4.0.127.0.7.2.2.2) at position 0
// under DER SET-OF ordering, which blows up the parser with
// `Invalid protocol in PaceInfo. Protocol is not valid: 0.4.0.127.0.7.2.2.2`.

import 'package:test/test.dart';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/extensions.dart';

void main() {
  group('EfCardAccess', () {
    // Matches gmrtd: document/card_access_test.go TestNewCardAccessHappyAT
    //
    // Single PACEInfo using id-PACE-ECDH-GM-AES-CBC-CMAC-128 (0.4.0.127.0.7.2.2.4.2.2)
    // with version=2 and parameterId=13. Representative of an Austrian passport.
    test('Parses AT SecurityInfos with a single PACEInfo (ECDH-GM-128)', () {
      final data = '31143012060a04007f0007020204020202010202010d'.parseHex();

      final ef = EfCardAccess.fromBytes(data);

      expect(ef.paceInfo, isNotNull);
      expect(ef.paceInfo!.protocol.identifierString, '0.4.0.127.0.7.2.2.4.2.2');
      expect(ef.paceInfo!.version, 2);
      expect(ef.paceInfo!.parameterId, 13);
    });

    // Matches gmrtd: document/card_access_test.go TestNewCardAccessHappyDE
    //
    // Two PACEInfos advertised:
    //   - id-PACE-ECDH-GM-AES-CBC-CMAC-128  (0.4.0.127.0.7.2.2.4.2.2)
    //   - id-PACE-ECDH-CAM-AES-CBC-CMAC-128 (0.4.0.127.0.7.2.2.4.6.2)
    //
    // Both entries are valid PACEInfo structures. Under DER SET-OF ordering
    // the GM entry sorts before the CAM entry, so on the current master
    // `elements[0]` is GM and this test happens NOT to throw. It is included
    // because the fix (modelled on gmrtd's SecurityInfos dispatcher) should
    // surface BOTH PACEInfos and prefer CAM when selecting the active one.
    test('Parses DE SecurityInfos with two PACEInfos (GM + CAM)', () {
      final data =
          ('31283012060a04007f0007020204020202010202010d'
                  '3012060a04007f0007020204060202010202010d')
              .parseHex();

      final ef = EfCardAccess.fromBytes(data);

      expect(ef.paceInfo, isNotNull);
      // After the fix, a CAM-capable chip should have its CAM entry selected
      // as the preferred PACEInfo (PACE-CAM is strictly stronger than PACE-GM
      // because it additionally authenticates the chip; ICAO 9303 p11 §4.4).
      expect(ef.paceInfo!.protocol.identifierString, '0.4.0.127.0.7.2.2.4.6.2');
      expect(ef.paceInfo!.version, 2);
      expect(ef.paceInfo!.parameterId, 13);
    });

    // Reproduces issue #120 directly.
    //
    // SET contains:
    //   1. TerminalAuthenticationInfo { protocol=id-TA (0.4.0.127.0.7.2.2.2),
    //                                   version=2 }
    //   2. PACEInfo { protocol=id-PACE-ECDH-CAM-AES-CBC-CMAC-128
    //                 (0.4.0.127.0.7.2.2.4.6.2),
    //                 version=2, parameterId=13 }
    //
    // Under DER SET-OF encoding (X.690 §11.6) the shorter TA encoding
    // (15 bytes) sorts before the longer PACEInfo encoding (20 bytes),
    // so the TA entry is `set.elements[0]`. The current master parser
    // blindly casts it to a PACEInfo and throws:
    //   "Invalid protocol in PaceInfo. Protocol is not valid: 0.4.0.127.0.7.2.2.2"
    //
    // After the fix EF.CardAccess should be parsed as a heterogeneous
    // SET OF SecurityInfo — exactly the approach gmrtd takes in
    // document/security_infos.go (DecodeSecurityInfos + per-type handlers).
    test('Parses SecurityInfos with TerminalAuthenticationInfo before PACEInfo (issue #120)', () {
      // SET (len 0x23 = 35):
      //   SEQUENCE (len 13): id-TA (0.4.0.127.0.7.2.2.2), version 2
      //   SEQUENCE (len 18): id-PACE-ECDH-CAM-AES-CBC-CMAC-128, v2, paramId 13
      final data =
          ('3123'
                  '300d060804007f0007020202020102'
                  '3012060a04007f0007020204060202010202010d')
              .parseHex();

      final ef = EfCardAccess.fromBytes(data);

      expect(ef.paceInfo, isNotNull);
      expect(ef.paceInfo!.protocol.identifierString, '0.4.0.127.0.7.2.2.4.6.2');
      expect(ef.paceInfo!.version, 2);
      expect(ef.paceInfo!.parameterId, 13);
    });

    // Matches gmrtd: document/security_infos_test.go
    // TestDecodeSecurityInfosCardSecFile
    //
    // Real-world test vector taken from the CardSecurity file of a German
    // ePassport. The SET contains 7 SecurityInfos of mixed types, and the
    // first element (under DER SET-OF ordering) is a TerminalAuthenticationInfo.
    //
    // Expected breakdown (per gmrtd reference):
    //   - 1 x TerminalAuthenticationInfo (id-TA, version 2)
    //   - 1 x ChipAuthenticationInfo
    //   - 2 x PACEInfo (ECDH-GM-128 + ECDH-CAM-128, both parameterId 13)
    //   - 1 x UnhandledInfo (malformed id-CA-ECDH entry present on the real
    //                         German passport — must be tolerated, not throw)
    //   - 2 x ChipAuthenticationPublicKeyInfo
    //
    // On master this blows up in the exact way issue #120 reports.
    test('Parses real-world DE SecurityInfos (CardSecurity) with mixed types', () {
      final data =
          ('31820131'
                  '300d060804007f0007020202020102'
                  '3012060a04007f00070202030202020102020148'
                  '3012060a04007f0007020204020202010202010d'
                  '3012060a04007f0007020204060202010202010d'
                  '301c060904007f000702020302300c060704007f0007010202010d020148'
                  '3062060904007f0007020201023052300c060704007f0007010202010d'
                  '03420004614cd88b00821a887869d0060b44a9d18789353e8cf7dfbc3f29f79327de30b97b1b2dda0be77f24ad415c327c7b7ab2e9c10b0258f5bcbf90c01825fbdfdef702010d'
                  '3062060904007f0007020201023052300c060704007f0007010202010d'
                  '034200048488a2dc34b6b36d6c01a8dfbd70a874610c53b32893a1de3b1c4bbf477eef3761aa51dfd6b52da43587e95386fc34ffe178d90086a7d646047c82bebc27da3e020148')
              .parseHex();

      final ef = EfCardAccess.fromBytes(data);

      expect(ef.paceInfo, isNotNull);
      // A German passport advertising PACE-CAM must have the CAM protocol
      // selected as the active PACEInfo.
      expect(ef.paceInfo!.protocol.identifierString, '0.4.0.127.0.7.2.2.4.6.2');
      expect(ef.paceInfo!.version, 2);
      expect(ef.paceInfo!.parameterId, 13);
    });

    // Matches gmrtd: document/security_infos_test.go TestDecodeSecurityInfos
    // (TermAuthInfos-only case).
    //
    // A stand-alone TerminalAuthenticationInfo SecurityInfos SET must not
    // throw during parsing. There is no PACEInfo present, so `paceInfo`
    // should simply be null / unset. The current master parser throws on
    // this input because it tries to parse element[0] as a PACEInfo.
    test('Does not throw on SecurityInfos containing only TerminalAuthenticationInfo', () {
      final data = '310f300d060804007f0007020202020101'.parseHex();

      expect(() => EfCardAccess.fromBytes(data), returnsNormally);
    });
  });
}
