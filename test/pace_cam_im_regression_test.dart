// Regression tests for PACE-CAM and PACE-IM bugs.
// Also tested in gmrtd: pace/pace_test.go, pace/pace.go

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/pace.dart';
import 'package:vcmrtd/src/proto/pace_cam.dart';

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
}
