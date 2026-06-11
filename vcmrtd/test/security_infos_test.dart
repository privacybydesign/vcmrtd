// New unit tests for lib/src/lds/substruct/security_infos.dart
// Drives SecurityInfos.parse over hand-built DER SET-OF bytes to exercise each
// per-type dispatch handler (ChipAuthenticationInfo, ActiveAuthenticationInfo,
// EFDIRInfo, PaceDomainParameterInfo, ChipAuthenticationPublicKeyInfo,
// TerminalAuthenticationInfo, PACEInfo) plus the malformed/empty/unhandled
// fall-through branches and the top-level parse errors.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/substruct/security_infos.dart';
import 'package:vcmrtd/src/lds/ef.dart';

void main() {
  group('SecurityInfos.parse top-level errors', () {
    test('throws EfParseError on empty input (nothing to parse)', () {
      expect(() => SecurityInfos.parse(Uint8List(0)), throwsA(isA<EfParseError>()));
    });

    test('throws EfParseError when top-level object is not a SET', () {
      // A bare SEQUENCE instead of a SET.
      final data = '300D060804007F0007020202020102'.parseHex();
      expect(() => SecurityInfos.parse(data), throwsA(isA<EfParseError>()));
    });
  });

  group('SecurityInfos.parse per-type dispatch', () {
    test('TerminalAuthenticationInfo (id-TA)', () {
      final data = '310F300D060804007F0007020202020102'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.terminalAuthenticationInfos.length, 1);
      expect(s.terminalAuthenticationInfos.single.version, 2);
      expect(s.terminalAuthenticationInfos.single.protocol, '0.4.0.127.0.7.2.2.2');
      expect(s.totalCount, 1);
    });

    test('ChipAuthenticationInfo (child of id-CA-ECDH) with keyId', () {
      final data = '31143012060A04007F00070202030202020101020148'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.chipAuthenticationInfos.length, 1);
      expect(s.chipAuthenticationInfos.single.version, 1);
      expect(s.chipAuthenticationInfos.single.keyId, 0x48);
    });

    test('ActiveAuthenticationInfo (id-icao-mrtd-security-aaProtocolObject)', () {
      final data = '31173015060667810801010502010106082A8648CE3D040302'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.activeAuthenticationInfos.length, 1);
      expect(s.activeAuthenticationInfos.single.protocol, '2.23.136.1.1.5');
      expect(s.activeAuthenticationInfos.single.version, 1);
      expect(s.activeAuthenticationInfos.single.signatureAlgorithm, isNotEmpty);
    });

    test('EFDIRInfo (id-EFDIR) carries the octet string', () {
      final data = '310D300B06052B1B01010D0402AABB'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.efDirInfos.length, 1);
      expect(s.efDirInfos.single.protocol, '1.3.27.1.1.13');
      expect(s.efDirInfos.single.efDir, 'AABB'.parseHex());
    });

    test('PaceDomainParameterInfo (PACE base OID) with parameterId', () {
      final data = '31153013060904007F000702020402300302010102010D'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.paceDomainParameterInfos.length, 1);
      expect(s.paceDomainParameterInfos.single.protocol, '0.4.0.127.0.7.2.2.4.2');
      expect(s.paceDomainParameterInfos.single.parameterId, 13);
    });

    test('ChipAuthenticationPublicKeyInfo (id-PK-ECDH) with keyId', () {
      final data = '31153013060904007F0007020201023003020100020148'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.chipAuthenticationPublicKeyInfos.length, 1);
      expect(s.chipAuthenticationPublicKeyInfos.single.protocol, '0.4.0.127.0.7.2.2.1.2');
      expect(s.chipAuthenticationPublicKeyInfos.single.keyId, 0x48);
    });

    test('PACEInfo (child of a PACE base OID) is collected', () {
      // id-PACE-ECDH-GM-AES-CBC-CMAC-128, v2, paramId 13
      final data = '31143012060a04007f0007020204020202010202010d'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.paceInfos.length, 1);
      expect(s.paceInfos.single.version, 2);
    });

    test('mixed SET dispatches each element to the right bucket', () {
      final data =
          ('3171'
                  '300D060804007F0007020202020102' // TA
                  '3012060A04007F00070202030202020101020148' // CA info
                  '3015060667810801010502010106082A8648CE3D040302' // AA info
                  '300B06052B1B01010D0402AABB' // EFDIR
                  '3013060904007F000702020402300302010102010D' // PACE domain param
                  '3013060904007F0007020201023003020100020148') // CA pubkey
              .parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.terminalAuthenticationInfos.length, 1);
      expect(s.chipAuthenticationInfos.length, 1);
      expect(s.activeAuthenticationInfos.length, 1);
      expect(s.efDirInfos.length, 1);
      expect(s.paceDomainParameterInfos.length, 1);
      expect(s.chipAuthenticationPublicKeyInfos.length, 1);
      expect(s.totalCount, 6);
    });
  });

  group('SecurityInfos.parse tolerant/unhandled branches', () {
    test('unknown OID is recorded as UnhandledInfo, not thrown', () {
      // SET { SEQUENCE { OID 1.2.840.10045.2.2 (not a SecurityInfo protocol),
      //                  INTEGER 1 } }
      final data = '310C300A06062A8648CE3D02020101'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.unhandledInfos.length, 1);
      expect(s.paceInfos, isEmpty);
      expect(s.totalCount, 1);
    });

    test('non-SEQUENCE element inside the SET is skipped', () {
      // SET { INTEGER 1, TA-SEQUENCE } -> the bare INTEGER is skipped, TA kept.
      final data = '311202010130 0D060804007F0007020202020102'.replaceAll(' ', '').parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.terminalAuthenticationInfos.length, 1);
      expect(s.totalCount, 1);
    });

    test('empty SET yields zero infos', () {
      final data = '3100'.parseHex();
      final s = SecurityInfos.parse(data);
      expect(s.totalCount, 0);
    });
  });
}
