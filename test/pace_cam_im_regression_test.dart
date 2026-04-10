// Regression tests for PACE-CAM and PACE-IM, ported from gmrtd.
//
// These tests prove that vcmrtd silently skips PACE-CAM chip-authentication
// verification, and silently runs Generic Mapping code against PACE-IM
// advertisements — two bugs identified by comparing vcmrtd's PACE flow
// against gmrtd's reference implementation.
//
// gmrtd references:
//   - pace/pace.go:459-466            — CAM step-4 ECAD must be present
//   - pace/pace.go:509-564            — doCamEcdh: PKMap,IC = KA(CAIC, PKIC, DIC)
//   - pace/pace.go:704                — PACE-IM returns "NOT IMPLEMENTED"
//   - pace/pace_test.go:495           — TestDoPace_CAM_ECDH_DE (end-to-end DE)
//   - pace/pace_test.go:690           — TestDoCamEcdhMappingNoEcadIcErr
//
// ICAO 9303 Part 11 references:
//   - §4.4.3.3.3      Chip Authentication Mapping
//   - §4.4.3.5        Encrypted Chip Authentication Data
//   - §4.4.3.5.2      "The terminal SHALL decrypt AIC to recover CAIC and
//                      verify PKMap,IC = KA(CAIC, PKIC, DIC)"
//   - §4.4.3.5  note  "Encrypted Chip Authentication Data is REQUIRED for
//                      PACE with Chip Authentication Mapping."

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

/// Minimal `ComProvider` stub that records every APDU the PACE flow tries
/// to send. Used to prove whether an early rejection happens before any
/// network I/O (as gmrtd does for PACE-IM) or whether the flow dispatches
/// through unsupported code paths (the current vcmrtd behaviour).
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
    // We never want a reply here — these tests should either reject before
    // this point (PACE-IM), or the caller should abort on its own logic.
    // Returning an obviously-invalid SW lets PACE.initSession fail cleanly.
    return Uint8List.fromList([0x6A, 0x80]); // "Incorrect parameters"
  }
}

void main() {
  // Standard ICAO 9303 Appendix G test MRZi.
  final dbaKey = DBAKey('T22000129', DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

  group('PACE-IM — gmrtd pace.go:704 rejects at runtime', () {
    // Equivalent gmrtd behaviour: when the selected PaceConfig has
    // mapping == IM, DoPACE returns an error immediately:
    //
    //   case IM:
    //     return result, fmt.Errorf("[DoPACE] PACE-IM NOT IMPLEMENTED")
    //
    // before any APDU is sent to the chip. vcmrtd does not have this check —
    // PACE.initSession dispatches purely on tokenAgreementAlgorithm (DH/ECDH)
    // and runs the Generic Mapping code path for IM OIDs, starting with
    // MSE:Set AT. The test proves this by asserting that no APDU reaches
    // the recording mock when PACE is run against an IM-only EF.CardAccess.

    test('IM-only EF.CardAccess should be rejected BEFORE any APDU is sent', () async {
      // EF.CardAccess SET containing exactly one PACEInfo with OID
      // id-PACE-ECDH-IM-AES-CBC-CMAC-128 (0.4.0.127.0.7.2.2.4.4.2),
      // version 2, parameterId 13 (Brainpool P-256r1).
      //
      //   31 14                       SET, length 20
      //     30 12                       SEQUENCE, length 18
      //       06 0a 04 00 7f 00 07 02 02 04 04 02   OID id-PACE-ECDH-IM-AES-CBC-CMAC-128
      //       02 01 02                  INTEGER 2     (version)
      //       02 01 0d                  INTEGER 13    (parameterId)
      final efData = '31143012060a04007f0007020204040202010202010d'.parseHex();
      final ef = EfCardAccess.fromBytes(efData);

      // Sanity: the only PaceInfo really is IM.
      expect(ef.paceInfo, isNotNull);
      expect(ef.paceInfo!.protocol.identifierString, '0.4.0.127.0.7.2.2.4.4.2');
      expect(ef.paceInfo!.protocol.mappingType, MAPPING_TYPE.IM);

      // Wire up an ICC over a recording ComProvider.
      final com = _RecordingComProvider();
      final icc = ICC(com);

      // Run PACE and swallow whatever it throws — the key assertion is about
      // the recorded APDU list, not the exception type.
      try {
        await PACE.initSession(paceKey: dbaKey, icc: icc, efCardAccess: ef);
      } catch (_) {
        // expected: either a clean "IM not implemented" PACEError (after fix)
        // or the current cascade of ICCError → PACEError from the stub reply
      }

      // The assertion that matters: on a correct implementation, PACE must
      // reject IM before touching the wire. gmrtd does this at pace.go:704.
      //
      // CURRENT STATE: vcmrtd reaches icc.setAT() (the MSE:Set AT APDU,
      // INS 0x22) as its first action, so `sentApdus.length >= 1`.
      expect(
        com.sentApdus,
        isEmpty,
        reason:
            'PACE-IM must be rejected at dispatch time (matching gmrtd '
            'pace.go:704). Currently PACE.initSession runs the Generic '
            'Mapping code path against IM OIDs and reaches icc.setAT() '
            'before realising the mapping is not supported.',
      );
    });
  });

  group('PACE-CAM — gmrtd TestDoPace_CAM_ECDH_DE asserts ChipAuthenticated:true', () {
    // Equivalent gmrtd assertion (pace_test.go:574):
    //
    //   var expPaceResult *document.PaceResult = &document.PaceResult{
    //     Success: true,
    //     Oid: oid.OidPaceEcdhCamAesCbcCmac128,
    //     ParameterId: 13,
    //     ChipAuthenticated: true,   // <-- THE KEY ASSERTION
    //   }
    //
    // gmrtd sets `ChipAuthenticated: true` inside doCamEcdh (pace.go:509)
    // *only* after the PACE-CAM verification succeeds —
    //   PKMap,IC = KA(CAIC, PKIC, DIC)
    // i.e. the terminal recovers CAIC by decrypting the ECAD with KSEnc
    // and checks that the chip's static public key, scaled by CAIC, equals
    // the mapping public key the chip sent during PACE step 2.
    //
    // vcmrtd has every cryptographic building block for this verification
    // — see `PaceCam.decryptEcad`, `PaceCam.verify`, and
    // `PaceCam.verifyChipAuthentication` in lib/src/proto/pace_cam.dart —
    // and unit-tests them against gmrtd test vectors in pace_cam_test.dart.
    // But `lib/src/proto/pace.dart` never imports `pace_cam.dart`, and
    // `PACE.initSession` never calls any of those primitives.
    //
    // Additionally, `PACE.initSession` returns `Future<void>`, so even if
    // the verification *were* performed, callers would have no way to
    // observe that it happened — there is no `PaceResult` type at all.

    test('PACE.initSession should expose a chipAuthenticated flag for CAM sessions', () {
      // Contract assertion: after the fix, `PACE.initSession` MUST
      // return a result object with a `chipAuthenticated` flag —
      // analogous to gmrtd's `document.PaceResult.ChipAuthenticated`.
      //
      // Today the symbol does not exist anywhere in vcmrtd. The test
      // documents the gap and asserts that the fix must introduce it.

      // This would be the ideal assertion:
      //
      //   final PaceResult result = await PACE.initSession(
      //     paceKey: dbaKey, icc: icc, efCardAccess: camCardAccess,
      //   );
      //   expect(result.oid, '0.4.0.127.0.7.2.2.4.6.2');
      //   expect(result.parameterId, 13);
      //   expect(result.chipAuthenticated, isTrue);
      //
      // Neither `PaceResult` nor a `chipAuthenticated` return value
      // exists in lib/src/proto/pace.dart today. The test fails with a
      // descriptive message until the fix is in place.
      fail(
        'vcmrtd has no PaceResult type and PACE.initSession returns '
        'Future<void>. There is no API surface to observe whether '
        'PACE-CAM chip authentication was verified. '
        '\n\n'
        'Expected state after the fix:\n'
        '  - PACE.initSession returns Future<PaceResult>\n'
        '  - PaceResult exposes {oid, parameterId, chipAuthenticated}\n'
        '  - chipAuthenticated == true iff PaceCam.verifyChipAuthentication '
        'succeeded against PK_IC from EF.CardSecurity.\n'
        '\n'
        'gmrtd reference: pace/pace_test.go:574 '
        '(TestDoPace_CAM_ECDH_DE) and pace/pace.go:509 (doCamEcdh).',
      );
    });

    test('pace.dart must import and call PaceCam during a CAM session', () {
      // Static integration assertion: the PACE flow module must reference
      // pace_cam.dart. This is a crude proxy for "CAM verification is
      // wired into the session flow" — but it is a necessary condition.
      //
      // Today the import is absent. `lib/src/proto/pace.dart` knows
      // nothing about `PaceCam` and cannot possibly call it.
      //
      // This test will be replaced by a proper end-to-end integration
      // test once PACE.initSession is refactored to take an injectable
      // EC key source (needed to replay gmrtd's recorded CAM APDUs
      // deterministically — see gmrtd pace_test.go:522 getTestKeyGenEc).

      // Touch-test: the bindings should exist after the fix.
      // Verified by grep in the CI — use a sentinel expectation so the
      // test shows up in the failing list today.
      expect(
        // ignore: unnecessary_null_comparison
        PaceCam,
        isNotNull,
        reason: 'PaceCam class must be reachable — sanity check.',
      );
      fail(
        'lib/src/proto/pace.dart does not import '
        'lib/src/proto/pace_cam.dart. `PaceCam.verifyChipAuthentication` '
        'is never called from `PACE.initSession`. PACE-CAM silently '
        'downgrades to PACE-GM at runtime: the mapping phase is identical '
        '(per §4.4.3.3.3), session keys are established, the step-4 ECAD '
        'is parsed into ResponseAPDUStep4Pace._encryptedChipAuthData, '
        'and then discarded without verification. '
        '\n\n'
        'After the fix, pace.dart must:\n'
        '  1. Import pace_cam.dart\n'
        '  2. Read EF.CardSecurity to obtain the chip\'s static '
        'PK_IC when the selected config has mappingType == CAM\n'
        '  3. Call PaceCam.verifyChipAuthentication with (ECAD, KSEnc, '
        'keyLength, PK_IC, PKMap_IC, parameterId)\n'
        '  4. Set PaceResult.chipAuthenticated = true on success '
        'OR throw if verification fails.\n'
        '\n'
        'gmrtd reference: pace/pace.go:509-564 doCamEcdh.',
      );
    });

    // Ported from gmrtd pace_test.go:690 TestDoCamEcdhMappingNoEcadIcErr.
    //
    // gmrtd's `doCamEcdh` explicitly rejects an empty ECAD with:
    //
    //   if len(ecadIC) < 1 {
    //     return fmt.Errorf("[doCamEcdh] ECAD missing")
    //   }
    //
    // vcmrtd's `PaceCam.verifyChipAuthentication` has no such guard. When
    // fed an empty ECAD byte string it goes into `decryptEcad`, which calls
    // `aes.decrypt(data: Uint8List(0), ...)` and then `ISO9797.unpad(...)`
    // — the failure mode is an incidental exception from the crypto layer,
    // not a clean `PaceCamError('ECAD missing')` as gmrtd reports. This
    // test asserts the CLEAN error path the user gets from gmrtd today.
    test('PaceCam.verifyChipAuthentication must reject an empty ECAD with a clean error', () {
      final pk = Uint8List.fromList(List.generate(32, (i) => i + 1));

      expect(
        () => PaceCam.verifyChipAuthentication(
          encryptedChipAuthData: Uint8List(0), // empty ECAD
          ksEnc: Uint8List.fromList(List.generate(16, (i) => (i + 1) & 0xff)),
          keyLength: KEY_LENGTH.s128,
          pkIcX: pk,
          pkIcY: pk,
          pkMapIcX: pk,
          pkMapIcY: pk,
          domainParameterId: 13,
        ),
        throwsA(
          isA<PaceCamError>().having(
            (e) => e.message,
            'message',
            anyOf(contains('ECAD'), contains('empty'), contains('missing')),
          ),
        ),
        reason:
            'PaceCam.verifyChipAuthentication must validate that the ECAD '
            'is non-empty before decrypting it — mirroring gmrtd\'s '
            'doCamEcdh guard at pace/pace.go. Currently the empty-ECAD '
            'case fails with an unrelated crypto/unpad exception.',
      );
    });
  });
}
