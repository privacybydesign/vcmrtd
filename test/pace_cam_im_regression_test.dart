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
