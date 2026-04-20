// Regression tests for PACE-CAM and PACE-IM bugs.
// Also tested in gmrtd: pace/pace_test.go, pace/pace.go

import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';
import 'package:vcmrtd/src/lds/efcard_security.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/pace.dart';
import 'package:vcmrtd/src/proto/pace_cam.dart';

/// Replays scripted APDU responses in order; also records every sent APDU.
/// Returns 6A80 after all scripted responses are exhausted.
class _ScriptedComProvider extends ComProvider {
  final List<Uint8List> _responses;
  final List<Uint8List> sentApdus = [];
  int _idx = 0;

  _ScriptedComProvider(List<String> hexResponses)
    : _responses = hexResponses.map((h) => h.parseHex()).toList(),
      super(Logger('_ScriptedComProvider'));

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> reconnect() async {}
  @override
  bool isConnected() => true;

  @override
  Future<Uint8List> transceive(Uint8List data) async {
    sentApdus.add(Uint8List.fromList(data));
    if (_idx >= _responses.length) return Uint8List.fromList([0x6A, 0x80]);
    return _responses[_idx++];
  }
}

/// Records every APDU sent during PACE, returns 6A80 for each.
class _RecordingComProvider extends ComProvider {
  final List<Uint8List> sentApdus = [];
  bool _connected = true;

  _RecordingComProvider() : super(Logger('_RecordingComProvider'));

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> reconnect() async {
    _connected = true;
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(Uint8List data) async {
    sentApdus.add(Uint8List.fromList(data));
    return Uint8List.fromList([0x6A, 0x80]);
  }
}

void main() {
  final dbaKey = DBAKey('T22000129', DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

  // Also tested in gmrtd: pace/pace.go:704 (DoPACE IM rejection)
  group('PACE-IM', () {
    // Verifies IM OIDs are rejected before any APDU reaches the chip.
    test('IM-only EF.CardAccess should be rejected BEFORE any APDU is sent', () async {
      final efData = '31143012060a04007f0007020204040202010202010d'.parseHex();
      final ef = EfCardAccess.fromBytes(efData);

      expect(ef.paceInfo!.protocol.mappingType, MAPPING_TYPE.IM);

      final com = _RecordingComProvider();
      final icc = ICC(com);

      try {
        await PACE.initSession(paceKey: dbaKey, icc: icc, efCardAccess: ef);
      } catch (_) {}

      expect(com.sentApdus, isEmpty);
    });
  });

  // Also tested in gmrtd: pace/pace_test.go:488 (TestDoPace_CAM_ECDH_DE)
  group('PACE-CAM', () {
    // Verifies PaceResult exposes the same fields as gmrtd's document.PaceResult.
    test('PaceResult exposes oid, parameterId, and chipAuthenticated', () {
      final gmResult = PaceResult(oid: '0.4.0.127.0.7.2.2.4.2.2', parameterId: 13);
      expect(gmResult.chipAuthenticated, isFalse);

      final camResult = PaceResult(oid: '0.4.0.127.0.7.2.2.4.6.2', parameterId: 13, chipAuthenticated: true);
      expect(camResult.oid, '0.4.0.127.0.7.2.2.4.6.2');
      expect(camResult.parameterId, 13);
      expect(camResult.chipAuthenticated, isTrue);
    });

    // Verifies CAM OIDs dispatch through the ECDH code path (not rejected like IM)
    // and the MSE:Set AT APDU contains the CAM OID.
    test('CAM EF.CardAccess dispatches through the CAM-aware code path', () async {
      final efData = '31143012060a04007f0007020204060202010202010d'.parseHex();
      final ef = EfCardAccess.fromBytes(efData);
      expect(ef.paceInfo!.protocol.mappingType, MAPPING_TYPE.CAM);

      final com = _RecordingComProvider();
      final icc = ICC(com);

      try {
        await PACE.initSession(paceKey: dbaKey, icc: icc, efCardAccess: ef);
      } catch (_) {}

      // CAM shares the GM mapping phase, so MSE:Set AT should be sent.
      expect(com.sentApdus, isNotEmpty);

      // MSE:Set AT must contain the CAM OID.
      final mseHex = com.sentApdus.first.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final camOidHex = '04007f00070202040602'.parseHex().map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(mseHex.contains(camOidHex), isTrue);
    });

    // Test vectors from gmrtd TestDoPace_CAM_ECDH_DE.
    // The DE passport EF.CardSecurity has TWO ChipAuthenticationPublicKeyInfos:
    //   keyId=13  →  CAM key  (must be used, X starts 614CD88B…)
    //   keyId=72  →  GM key   (must NOT be used, X starts 8488A2DC…)
    // Per BSI TR-03110 §4.2.3.3, the correct key is the one whose
    // keyId equals the PACE domain-parameter ID (13 = BrainpoolP256r1).
    //
    // This test directly exercises the fix in _extractPkIcForCAM: using the
    // wrong key (keyId=72) must produce a failing verification, while the
    // correct key (keyId=13) must produce a passing one.
    test('CAM verification passes with keyId=13 and fails with keyId=72 (DE passport vectors)', () {
      // Session encryption key and ECAD from gmrtd TestDoPace_CAM_ECDH_DE step-4.
      final ksEnc = 'a8e85e938514ec67ae33cda3d43d3c48'.parseHex();
      final ecad = 'b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5'
          .parseHex();

      // PKMap_IC = chip's ephemeral public key from PACE Map Nonce step (tag 82 in gmrtd mock).
      // This is from the Map Nonce response, NOT the Key Agreement response (tag 84).
      // gmrtd mapNonceGmEcDh returns pubMapIC = decodeDynAuthData(0x82, ...).
      final pkMapIcX = '76dc295c4fb14237d87318d70967e25ec45f74d6fd4aff588c90efb3d868f05b'.parseHex();
      final pkMapIcY = '450ba6b64967227c2246dbe2905522c8086dac7f3bbe5cf3b192f0a0c2d97ee5'.parseHex();

      // Correct CA key from DE CardSecurity: keyId=13.
      final pkIcCamX = '614CD88B00821A887869D0060B44A9D18789353E8CF7DFBC3F29F79327DE30B9'.parseHex();
      final pkIcCamY = '7B1B2DDA0BE77F24AD415C327C7B7AB2E9C10B0258F5BCBF90C01825FBDFDEF7'.parseHex();

      // Wrong CA key from DE CardSecurity: keyId=72 (GM key — previously returned by the bug).
      final pkIcGmX = '8488A2DC34B6B36D6C01A8DFBD70A874610C53B32893A1DE3B1C4BBF477EEF37'.parseHex();
      final pkIcGmY = '61AA51DFD6B52DA43587E95386FC34FFE178D90086A7D646047C82BEBC27DA3E'.parseHex();

      expect(
        PaceCam.verifyChipAuthentication(
          encryptedChipAuthData: ecad,
          ksEnc: ksEnc,
          keyLength: KEY_LENGTH.s128,
          pkIcX: pkIcCamX,
          pkIcY: pkIcCamY,
          pkMapIcX: pkMapIcX,
          pkMapIcY: pkMapIcY,
          domainParameterId: 13,
        ),
        isTrue,
        reason: 'correct key (keyId=13) must pass CAM verification',
      );

      expect(
        () => PaceCam.verifyChipAuthentication(
          encryptedChipAuthData: ecad,
          ksEnc: ksEnc,
          keyLength: KEY_LENGTH.s128,
          pkIcX: pkIcGmX,
          pkIcY: pkIcGmY,
          pkMapIcX: pkMapIcX,
          pkMapIcY: pkMapIcY,
          domainParameterId: 13,
        ),
        throwsA(isA<PaceCamError>()),
        reason: 'wrong key (keyId=72) must fail CAM verification — was the pre-fix behaviour',
      );
    });

    // Also tested in gmrtd: pace/pace_test.go:690 (TestDoCamEcdhMappingNoEcadIcErr)
    // Verifies empty ECAD throws a clean PaceCamError instead of a crypto exception.
    test('PaceCam.verifyChipAuthentication rejects an empty ECAD', () {
      final pk = Uint8List.fromList(List.generate(32, (i) => i + 1));

      expect(
        () => PaceCam.verifyChipAuthentication(
          encryptedChipAuthData: Uint8List(0),
          ksEnc: Uint8List.fromList(List.generate(16, (i) => (i + 1) & 0xff)),
          keyLength: KEY_LENGTH.s128,
          pkIcX: pk,
          pkIcY: pk,
          pkMapIcX: pk,
          pkMapIcY: pk,
          domainParameterId: 13,
        ),
        throwsA(isA<PaceCamError>()),
      );
    });
  });

  // Real German ePassport EF.CardSecurity (same data as efcard_security_test.dart).
  // Contains TWO ChipAuthenticationPublicKeyInfos:
  //   keyId=13 (CAM key, X=614CD88B…) and keyId=72 (GM key, X=8488A2DC…).
  const deCardSecurityHex =
      '3082074206092A864886F70D010702A08207333082072F020103310F300D0609608648016503040202050030820147060804007F0007030201A08201390482013531820131300D060804007F00070202020201023012060A04007F000702020302020201020201483012060A04007F0007020204020202010202010D3012060A04007F0007020204060202010202010D301C060904007F000702020302300C060704007F0007010202010D0201483062060904007F0007020201023052300C060704007F0007010202010D03420004614CD88B00821A887869D0060B44A9D18789353E8CF7DFBC3F29F79327DE30B97B1B2DDA0BE77F24AD415C327C7B7AB2E9C10B0258F5BCBF90C01825FBDFDEF702010D3062060904007F0007020201023052300C060704007F0007010202010D034200048488A2DC34B6B36D6C01A8DFBD70A874610C53B32893A1DE3B1C4BBF477EEF3761AA51DFD6B52DA43587E95386FC34FFE178D90086A7D646047C82BEBC27DA3E020148A082049730820493308203F8A003020102020204A8300A06082A8648CE3D0403043041310B3009060355040613024445310D300B060355040A0C0462756E64310C300A060355040B0C036273693115301306035504030C0C637363612D6765726D616E79301E170D3233303130343036303434325A170D3333303730343233353935395A305D310B3009060355040613024445311D301B060355040A0C1442756E646573647275636B6572656920476D6248310C300A060355040513033135323121301F06035504030C18446F63756D656E74205369676E65722050617373706F7274308201B53082014D06072A8648CE3D020130820140020101303C06072A8648CE3D01010231008CB91E82A3386D280F5D6F7E50E641DF152F7109ED5456B412B1DA197FB71123ACD3A729901D1A71874700133107EC53306404307BC382C63D8C150C3C72080ACE05AFA0C2BEA28E4FB22787139165EFBA91F90F8AA5814A503AD4EB04A8C7DD22CE2826043004A8C7DD22CE28268B39B55416F0447C2FB77DE107DCD2A62E880EA53EEB62D57CB4390295DBC9943AB78696FA504C110461041D1C64F068CF45FFA2A63A81B7C13F6B8847A3E77EF14FE3DB7FCAFE0CBD10E8E826E03436D646AAEF87B2E247D4AF1E8ABE1D7520F9C2A45CB1EB8E95CFD55262B70B29FEEC5864E19C054FF99129280E4646217791811142820341263C53150231008CB91E82A3386D280F5D6F7E50E641DF152F7109ED5456B31F166E6CAC0425A7CF3AB6AF6B7FC3103B883202E9046565020101036200042CA852CB9A1CAAAA466256D1CFD678BB7E5D8502DFA6F3FDB287293C32AF9FA77AD3A7FA92E56F608110053121354002198B530BC60AC7050AB98D7F6C475FD50706A4A6207D7A6336CB480B966A3AA64894F7F42B8FB4AC4774C9D6892330FBA382016430820160301F0603551D23041830168014A40A5FC380AE3E59AF1B32D6136AEFEEC8CA35E8301D0603551D0E04160414AF9DD5E6565737A8804B5B4C6F45093D809AA865300E0603551D0F0101FF040403020780302B0603551D1004243022800F32303233303130343036303434325A810F32303233303730343233353935395A30160603551D20040F300D300B060904007F000703010101302D0603551D1104263024821262756E646573647275636B657265692E6465A40E300C310A300806035504070C014430510603551D12044A30488118637363612D6765726D616E79406273692E62756E642E6465861C68747470733A2F2F7777772E6273692E62756E642E64652F63736361A40E300C310A300806035504070C01443015060767810801010602040A3008020100310313015030300603551D1F042930273025A023A021861F687474703A2F2F7777772E6273692E62756E642E64652F637363615F63726C300A06082A8648CE3D0403040381880030818402404846F4A03E17896E9094AF7652C38FE31EC964C2C3A906AF813AABEF5FE4F3156D140E2EF991DC11FD860A4A301B225DE9FD4ED39B4F47AC72CDB88CC63B335902405D4E2895875E603CE2863073BF441D1EC53761CF47E5BC2B9B6BECE4F229712E39002D77B555290FA550DF5F40AA22D7D2A1E89FEB3FEF730AE33C937796E8E3318201313082012D02010130473041310B3009060355040613024445310D300B060355040A0C0462756E64310C300A060355040B0C036273693115301306035504030C0C637363612D6765726D616E79020204A8300D06096086480165030402020500A05A301706092A864886F70D010903310A060804007F0007030201303F06092A864886F70D010904313204300FF966AB1283D22A0046338B734FBAE653622C15FE7538392E0987D87BEE0AB009BA77506E45D964B138E688BE8DA60D300C06082A8648CE3D040303050004663064023025FDE09B7F60E9B8F57413427128E6B9ED29C252E396D0F699A84B90247BDBDCA66BDA66A319423EB1D95D206E6BDAE8023016D075859D63301201E925A55ACCC7D3BC1E4C0457A87F5575821C6345FF1C059DEEF935E8125EA948BAAC7A9EF97199';

  // Also tested in gmrtd: pace/pace.go:489 (icPubKeyECForCAM)
  group('PACE.extractPkIcForCAM key selection (BSI TR-03110 §4.2.3.3)', () {
    // Verifies the keyId-match path: DE passport has keyId=13 (CAM) and keyId=72 (GM).
    // When domainParameterId=13, the entry with keyId=13 must be returned.
    test('prefers entry whose keyId equals the PACE domain parameter ID', () {
      final si = EfCardSecurity.fromBytes(deCardSecurityHex.parseHex()).securityInfos!;
      final pkIc = PACE.extractPkIcForCAM(si.chipAuthenticationPublicKeyInfos, 13);
      final xHex = pkIc.x.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(xHex, startsWith('614cd88b'), reason: 'must return CAM key (keyId=13), not GM key (keyId=72)');
    });

    // Verifies the fallback path: single-key passports that have no keyId matching
    // the domain parameter still get their only EC key returned.
    // Also tested in gmrtd: pace/pace.go fallback logic.
    test('falls back to first valid EC key when no keyId matches', () {
      final si = EfCardSecurity.fromBytes(deCardSecurityHex.parseHex()).securityInfos!;
      // Use only the keyId=72 (GM) entry — no exact keyId match for domainParam=13.
      final gmKeyOnly = si.chipAuthenticationPublicKeyInfos.where((k) => k.keyId == 72).toList();
      final pkIc = PACE.extractPkIcForCAM(gmKeyOnly, 13);
      final xHex = pkIc.x.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(xHex, startsWith('8488a2dc'), reason: 'fallback must return the only available EC key');
    });

    // Verifies that a mismatched domain parameter produces a clear error rather than
    // silently returning a key for the wrong curve.
    test('throws PACEError when no entry matches the requested domain parameter', () {
      final si = EfCardSecurity.fromBytes(deCardSecurityHex.parseHex()).securityInfos!;
      expect(
        () => PACE.extractPkIcForCAM(si.chipAuthenticationPublicKeyInfos, 99),
        throwsA(isA<PACEError>()),
        reason: 'paramId=99 does not exist in DE CardSecurity',
      );
    });

    test('throws PACEError for an empty key list', () {
      expect(() => PACE.extractPkIcForCAM([], 13), throwsA(isA<PACEError>()));
    });
  });

  // Also tested in gmrtd: pace/pace.go:529-543 (loadCardSecurityFile).
  group('PACE.readCardSecurity SFI-based reading (German passport fix)', () {
    // Verifies the first READ BINARY uses SFI P1=0x9D instead of a SELECT FILE
    // followed by offset-0 READ BINARY. German passports reject SELECT FILE for
    // EF.CardSecurity over secure messaging (sw=6A80).
    test('first READ BINARY uses SFI P1=0x9D (no SELECT FILE)', () async {
      // Minimal valid TLV that fits in one 256-byte chunk.
      final tinyData = Uint8List.fromList([0x30, 0x04, 0x01, 0x02, 0x03, 0x04]);
      final com = _ScriptedComProvider(['${tinyData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}9000']);
      final icc = ICC(com);

      await PACE.readCardSecurity(icc);

      expect(com.sentApdus, isNotEmpty);
      final firstApdu = com.sentApdus.first;
      // INS must be READ BINARY (0xB0), not SELECT FILE (0xA4).
      expect(firstApdu[1], 0xB0, reason: 'INS must be READ BINARY');
      // P1 must be the SFI selector: 0x80 | EfCardSecurity.SFI (0x1D) = 0x9D.
      expect(firstApdu[2], 0x80 | EfCardSecurity.SFI, reason: 'P1 must use SFI encoding');
      // No SELECT FILE (INS=0xA4) may appear before the first READ BINARY.
      final hasSelectFile = com.sentApdus.any((apdu) => apdu[1] == 0xA4);
      expect(hasSelectFile, isFalse, reason: 'SELECT FILE must not be sent before SFI READ BINARY');
    });

    // Verifies that a multi-chunk file is assembled correctly from successive
    // READ BINARY responses (offset-based reads after the first SFI read).
    test('reassembles multi-chunk EF.CardSecurity correctly', () async {
      final deBytes = deCardSecurityHex.parseHex();
      // Split into 256-byte chunks, each followed by status 9000.
      final responses = <String>[];
      for (int offset = 0; offset < deBytes.length; offset += 256) {
        final end = min(offset + 256, deBytes.length);
        final chunk = deBytes.sublist(offset, end);
        responses.add('${chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}9000');
      }

      final com = _ScriptedComProvider(responses);
      final icc = ICC(com);
      final result = await PACE.readCardSecurity(icc);

      expect(result, deBytes, reason: 'reassembled bytes must equal the original DE CardSecurity');
    });

    // Verifies that an empty (or error) first response produces a clean PACEError
    // rather than a NullPointerException or ICCError bubbling up to the caller.
    test('throws PACEError when chip returns empty data for first chunk', () async {
      // Return 9000 with no data — triggers the "Failed to read EF.CardSecurity" guard.
      final com = _ScriptedComProvider(['9000']);
      final icc = ICC(com);

      expect(() => PACE.readCardSecurity(icc), throwsA(isA<PACEError>()));
    });
  });
}
