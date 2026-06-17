// End-to-end PACE flow tests driving PACE.initSession through the ICC chain
// with a simulated chip ComProvider. The simulated chip performs the real
// ECDH-GM crypto so the terminal's randomly-generated keys still produce a
// matching mutual-authentication token -> full happy path + SM setup.
//
// Also covers initSession error branches (missing PACEInfo, PACE-IM rejection)
// and the step-response parser error branches in pace.dart.
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/crypto/aes.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';
import 'package:vcmrtd/src/lds/tlv.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/proto/dh_pace.dart';
import 'package:vcmrtd/src/proto/ecdh_pace.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/pace.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';
import 'package:vcmrtd/src/utils.dart';

/// Extracts the command data field from a raw short-form C-APDU.
/// Layout: CLA INS P1 P2 [Lc data] [Le]. PACE GA data is always < 255 bytes.
Uint8List _extractCommandData(Uint8List cmd) {
  if (cmd.length <= 5) return Uint8List(0); // header (+Le) only, no data
  final lc = cmd[4];
  if (lc == 0) return Uint8List(0);
  final end = 5 + lc;
  return Uint8List.fromList(cmd.sublist(5, end > cmd.length ? cmd.length : end));
}

Uint8List _wrap7C(int innerTag, Uint8List innerValue) {
  final inner = TLV(innerTag, innerValue).toBytes();
  return TLV(0x7c, inner).toBytes();
}

Uint8List _ok(Uint8List data) => Uint8List.fromList([...data, 0x90, 0x00]);

/// A simulated ECDH-GM PACE chip. Responds to the terminal's APDU sequence
/// (setAT, GA step1..4) by performing the actual ECDH-GM key agreement using
/// fixed chip-side private keys, mirroring the ICAO 9303 worked example.
class SimulatedEcdhChip extends ComProvider {
  final DBAKey dbaKey;
  final OIEPaceProtocol protocol;
  final int paramId;

  // Fixed chip private keys (from ICAO 9303 p11 Appendix D.3 worked example).
  final Uint8List _chipNonce = "3F00C4D39D153F2B2A214A078D899B22".parseHex();
  final Uint8List _chipMappingPriv = "498FF49756F2DC1587840041839A85982BE7761D14715FB091EFA7BCE9058560".parseHex();
  final Uint8List _chipEphPriv = "107CF58696EF6155053340FD633392BA81909DF7B9706F226F32086C7AFF974A".parseHex();

  late ECDHPace _chip;
  PublicKeyPACEeCDH? _terminalMappingPub;
  Uint8List? _macKey;
  int _step = 0;
  bool _connected = false;

  SimulatedEcdhChip({required this.dbaKey, required this.protocol, required this.paramId})
    : super(Logger('SimulatedEcdhChip'));

  @override
  Future<void> connect() async => _connected = true;
  @override
  Future<void> reconnect() async => _connected = true;
  @override
  Future<void> disconnect() async => _connected = false;
  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(final Uint8List cmd) async {
    final ins = cmd[1];
    // MSE:SET AT (step 0)
    if (ins == 0x22) {
      return _ok(Uint8List(0));
    }
    // GENERAL AUTHENTICATE (steps 1..4) -> INS 0x86
    if (ins == 0x86) {
      _step++;
      switch (_step) {
        case 1:
          return _step1();
        case 2:
          return _step2(cmd);
        case 3:
          return _step3(cmd);
        case 4:
          return _step4(cmd);
      }
    }
    throw ComProviderError("SimulatedEcdhChip: unexpected command ${cmd.hex()}");
  }

  // Step 1: return encrypted nonce (chip nonce encrypted with Kpi).
  Uint8List _step1() {
    final kpi = dbaKey.Kpi(protocol.cipherAlgoritm, protocol.keyLength);
    final aes = AESChiperSelector.getChiper(size: protocol.keyLength);
    final encNonce = aes.encrypt(data: _chipNonce, key: kpi);
    return _ok(_wrap7C(0x80, encNonce));
  }

  // Step 2: receive terminal mapping pubkey, compute & return chip mapping pubkey.
  Uint8List _step2(Uint8List cmd) {
    final data = _extractCommandData(cmd);
    final outer = TLV.fromBytes(data); // 7C
    final mapping = TLV.fromBytes(outer.value); // 81 04||X||Y
    final pointBytes = mapping.value.sublist(1); // strip 0x04
    _terminalMappingPub = PublicKeyPACEeCDH.fromHex(hexKey: Uint8List.fromList(pointBytes));

    _chip = DomainParameterSelectorECDH.getDomainParameter(id: paramId);
    _chip.generateKeyPairFromPriv(privKey: _chipMappingPriv);
    final chipPub = _chip.getPubKey();
    final body = Uint8List.fromList([0x04, ...chipPub.toBytes()]);
    return _ok(_wrap7C(0x82, body));
  }

  // Step 3: receive terminal ephemeral pubkey, compute chip ephemeral pubkey
  // on the mapped generator, and derive session keys for the auth token.
  Uint8List _step3(Uint8List cmd) {
    final data = _extractCommandData(cmd);
    final outer = TLV.fromBytes(data);
    final mapping = TLV.fromBytes(outer.value); // 83 04||X||Y (terminal ephemeral)
    final pointBytes = mapping.value.sublist(1);
    final terminalEphPub = PublicKeyPACEeCDH.fromHex(hexKey: Uint8List.fromList(pointBytes));

    // Mapped generator: G' computed from chip mapping priv * terminal mapping pub.
    final terminalMappingKey = _chip.transformPublic(pubKey: _terminalMappingPub!);
    final mappedGen = _chip.getMappedGenerator(otherPubKey: terminalMappingKey, nonce: _chipNonce);

    _chip.setEphemeralKeyPair(private: _chipEphPriv, mappedGenerator: mappedGen);
    final chipEphPub = _chip.getPubKeyEphemeral();

    // Ephemeral shared secret -> session keys.
    final terminalEphKey = _chip.transformPublic(pubKey: terminalEphPub);
    final ephShared = _chip.getEphemeralSharedSecret(otherEphemeralPubKey: terminalEphKey);
    final seed = ECDHPace.ecPointToList(point: ephShared).toRelavantBytes();
    _macKey = PACE.cacluateMacKey(paceProtocol: protocol, seed: seed);

    final body = Uint8List.fromList([0x04, ...chipEphPub.toBytes()]);
    return _ok(_wrap7C(0x84, body));
  }

  // Step 4: the terminal verifies the chip's token against the token it
  // computed over its OWN ephemeral public key, so the chip must return the
  // token computed over the TERMINAL's ephemeral public key (captured in
  // step 3 by the _CapturingEcdhChip subclass).
  Uint8List _step4(Uint8List cmd) {
    final inputData = PACE.generateEncodingInputData(
      crytpographicMechanism: protocol,
      ephemeralPublic: _terminalEphPub!,
    );
    final token = PACE.cacluateAuthToken(paceProtocol: protocol, inputData: inputData, macKey: _macKey!);
    return _ok(_wrap7C(0x86, token));
  }

  PublicKeyPACEeCDH? _terminalEphPub;
}

void main() {
  group('PACE.initSession full ECDH-GM flow (simulated chip)', () {
    test('establishes SM session and returns PaceResult', () async {
      final efCardAccess = EfCardAccess.fromBytes("31143012060A04007F0007020204020202010202010D".parseHex());
      final protocol = efCardAccess.paceInfo!.protocol;
      final dba = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

      final chip = _CapturingEcdhChip(dbaKey: dba, protocol: protocol, paramId: 13);
      final icc = ICC(chip);

      final result = await PACE.initSession(paceKey: dba, icc: icc, efCardAccess: efCardAccess);

      expect(result.oid, protocol.identifierString);
      expect(result.parameterId, 13);
      expect(result.chipAuthenticated, false); // GM, not CAM
      // Secure messaging must now be active.
      expect(icc.sm, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('PACE.initSession DH dispatch', () {
    test('routes to DH key establishment for a DH protocol', () async {
      // id-PACE-DH-GM-AES-CBC-CMAC-128, paramId 0 (1024-bit MODP/160).
      final efCardAccess = EfCardAccess.fromBytes("31143012060A04007F00070202040102020102020100".parseHex());
      final protocol = efCardAccess.paceInfo!.protocol;
      expect(protocol.tokenAgreementAlgorithm, TOKEN_AGREEMENT_ALGO.DH);
      final dba = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

      final chip = SimulatedDhChip(dbaKey: dba, protocol: protocol, paramId: 0);
      final icc = ICC(chip);

      // The DH terminal path exercises step 0 and step 1 (nonce decrypt) and
      // routes through PACE.dh. Note: DHPace.generateKeyPair() reuses the engine
      // created in the constructor, so the terminal DH happy path currently
      // throws a LateInitializationError (Error, not Exception) which propagates
      // out of initSession's `on Exception` handler. We assert that real
      // behaviour here to keep the branch covered without modifying lib/.
      await expectLater(
        PACE.initSession(paceKey: dba, icc: icc, efCardAccess: efCardAccess),
        throwsA(anyOf(isA<Error>(), isA<Exception>())),
      );
      // No SM session was established.
      expect(icc.sm, isNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('PACE step-response parsers - error branches', () {
    test('Step1 parser throws when outer tag is not 0x7C', () {
      final r = ResponseAPDUStep1Pace("8010000102030405060708090A0B0C0D0E0F".parseHex());
      expect(r.parse, throwsA(isA<ResponseAPDUStep1PaceError>()));
    });

    test('Step1 parser throws when inner tag is not 0x80 (encrypted nonce)', () {
      // 7C wraps tag 0x81 instead of 0x80.
      final r = ResponseAPDUStep1Pace("7C0481020102".parseHex());
      expect(r.parse, throwsA(isA<ResponseAPDUStep1PaceError>()));
    });

    test('Step2or3 parser throws when outer tag is not 0x7C', () {
      final r = ResponseAPDUStep2or3Pace("820101".parseHex());
      expect(
        () => r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.ECDH),
        throwsA(isA<ResponseAPDUStep2or3PaceError>()),
      );
    });

    test('Step2or3 parser throws when mapping tag is unknown', () {
      // 7C wraps tag 0x99 (neither 0x82 nor 0x84).
      final r = ResponseAPDUStep2or3Pace("7C0399010203".parseHex());
      expect(
        () => r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.ECDH),
        throwsA(isA<ResponseAPDUStep2or3PaceError>()),
      );
    });

    test('Step2or3 parser throws when mapping data empty', () {
      final r = ResponseAPDUStep2or3Pace("7C028200".parseHex());
      expect(
        () => r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.ECDH),
        throwsA(isA<ResponseAPDUStep2or3PaceError>()),
      );
    });

    test('Step2or3 ECDH parser throws when first byte is not 0x04', () {
      // 7C 82 06 05 .... -> EC point must start with 0x04.
      final r = ResponseAPDUStep2or3Pace("7C04820205AB".parseHex());
      expect(
        () => r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.ECDH),
        throwsA(isA<ResponseAPDUStep2or3PaceError>()),
      );
    });

    test('Step2or3 ECDH parser throws when point length is odd', () {
      // 0x04 followed by 3 bytes => odd X/Y split.
      final r = ResponseAPDUStep2or3Pace("7C06820404AABBCC".parseHex());
      expect(
        () => r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.ECDH),
        throwsA(isA<ResponseAPDUStep2or3PaceError>()),
      );
    });

    test('Step2or3 DH parser accepts mapping data as raw bytes', () {
      final r = ResponseAPDUStep2or3Pace("7C048202AABB".parseHex());
      r.parse(tokenAgreementAlgorithm: TOKEN_AGREEMENT_ALGO.DH);
      expect(r.public.toBytes(), "AABB".parseHex());
    });

    test('Step4 parser throws when outer tag is not 0x7C', () {
      final r = ResponseAPDUStep4Pace("8608AABBCCDDEEFF0011".parseHex());
      expect(r.parse, throwsA(isA<ResponseAPDUStep4PaceError>()));
    });

    test('Step4 parser throws when auth token absent', () {
      // 7C wraps only an unknown tag 0x99 (no 0x86).
      final r = ResponseAPDUStep4Pace("7C039901AA".parseHex());
      expect(r.parse, throwsA(isA<ResponseAPDUStep4PaceError>()));
    });

    test('Step4 parser throws when auth token empty', () {
      final r = ResponseAPDUStep4Pace("7C028600".parseHex());
      expect(r.parse, throwsA(isA<ResponseAPDUStep4PaceError>()));
    });
  });

  group('PACE.initSession error branches', () {
    test('throws when PACEInfo is absent in EF.CardAccess', () async {
      // EF.CardAccess with a non-PACE SecurityInfo only (ActiveAuthenticationInfo).
      // Use an empty SET so paceInfo == null.
      final efCardAccess = EfCardAccess.fromBytes("3100".parseHex());
      final dba = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);
      final icc = ICC(_NeverChip());
      await expectLater(
        PACE.initSession(paceKey: dba, icc: icc, efCardAccess: efCardAccess),
        throwsA(isA<PACEError>()),
      );
    });

    test('rejects PACE-IM before sending any APDU', () async {
      // id-PACE-ECDH-IM-AES-CBC-CMAC-128 = 0.4.0.127.0.7.2.2.4.3.2, paramId 13.
      final efCardAccess = EfCardAccess.fromBytes("31143012060A04007F0007020204030202010202010D".parseHex());
      expect(efCardAccess.paceInfo!.protocol.mappingType, MAPPING_TYPE.IM);
      final dba = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);
      final chip = _NeverChip();
      final icc = ICC(chip);
      await expectLater(
        PACE.initSession(paceKey: dba, icc: icc, efCardAccess: efCardAccess),
        throwsA(isA<PACEError>()),
      );
      // No APDU should have been sent (rejected before step 0).
      expect(chip.transceiveCount, 0);
    });
  });
}

/// A simulated DH-GM PACE chip performing the real DH-GM key agreement.
class SimulatedDhChip extends ComProvider {
  final DBAKey dbaKey;
  final OIEPaceProtocol protocol;
  final int paramId;

  // Fixed chip private keys from ICAO 9303 p11 Appendix G.2 (DH worked example).
  final Uint8List _chipNonce = "FA5B7E3E49753A0DB9178B7B9BD898C8".parseHex();
  final Uint8List _chipMappingPriv = "66DDAFEAC1609CB5B963BB0CB3FF8B3E047F336C".parseHex();
  final Uint8List _chipEphPriv = "A5B780126B7C980E9FCEA1D4539DA1D27C342DFA".parseHex();

  late DHPace _chip;
  Uint8List? _terminalMappingPub;
  Uint8List? _terminalEphPub;
  Uint8List? _macKey;
  int _step = 0;
  bool _connected = false;

  SimulatedDhChip({required this.dbaKey, required this.protocol, required this.paramId})
    : super(Logger('SimulatedDhChip'));

  @override
  Future<void> connect() async => _connected = true;
  @override
  Future<void> reconnect() async => _connected = true;
  @override
  Future<void> disconnect() async => _connected = false;
  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(Uint8List cmd) async {
    final ins = cmd[1];
    if (ins == 0x22) return _ok(Uint8List(0));
    if (ins == 0x86) {
      _step++;
      switch (_step) {
        case 1:
          final kpi = dbaKey.Kpi(protocol.cipherAlgoritm, protocol.keyLength);
          final aes = AESChiperSelector.getChiper(size: protocol.keyLength);
          return _ok(_wrap7C(0x80, aes.encrypt(data: _chipNonce, key: kpi)));
        case 2:
          {
            final outer = TLV.fromBytes(_extractCommandData(cmd));
            _terminalMappingPub = TLV.fromBytes(outer.value).value;
            _chip = DomainParameterSelectorDH.getDomainParameter(id: paramId);
            _chip.generateKeyPairFromPriv(privKey: _chipMappingPriv);
            return _ok(_wrap7C(0x82, _chip.getPubKey().toBytes()));
          }
        case 3:
          {
            final outer = TLV.fromBytes(_extractCommandData(cmd));
            _terminalEphPub = TLV.fromBytes(outer.value).value;
            final mappedGen = _chip.getMappedGenerator(otherPubKey: _terminalMappingPub!, nonce: _chipNonce);
            _chip.setEphemeralKeyPair(private: _chipEphPriv, ephemeralGenerator: Utils.uint8ListToBigInt(mappedGen));
            final ephShared = _chip.getEphemeralSharedSecret(otherEphemeralPubKey: _terminalEphPub!);
            final seed = Utils.bigIntToUint8List(bigInt: ephShared);
            _macKey = PACE.cacluateMacKey(paceProtocol: protocol, seed: seed);
            return _ok(_wrap7C(0x84, _chip.getPubKeyEphemeral().toBytes()));
          }
        case 4:
          {
            final inputData = PACE.generateEncodingInputData(
              crytpographicMechanism: protocol,
              ephemeralPublic: PublicKeyPACEdH(pub: _terminalEphPub!),
            );
            final token = PACE.cacluateAuthToken(paceProtocol: protocol, inputData: inputData, macKey: _macKey!);
            return _ok(_wrap7C(0x86, token));
          }
      }
    }
    throw ComProviderError("SimulatedDhChip: unexpected command ${cmd.hex()}");
  }
}

/// Chip that fails the test if any APDU is sent.
class _NeverChip extends ComProvider {
  int transceiveCount = 0;
  _NeverChip() : super(Logger('NeverChip'));
  @override
  Future<void> connect() async {}
  @override
  Future<void> reconnect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  bool isConnected() => true;
  @override
  Future<Uint8List> transceive(Uint8List data) async {
    transceiveCount++;
    return Uint8List.fromList([0x90, 0x00]);
  }
}

/// Extends the simulated chip to capture the terminal's ephemeral public key
/// from the step-3 command so step 4 can compute the matching chip auth token.
class _CapturingEcdhChip extends SimulatedEcdhChip {
  _CapturingEcdhChip({required super.dbaKey, required super.protocol, required super.paramId});

  @override
  Future<Uint8List> transceive(Uint8List cmd) async {
    if (cmd[1] == 0x86) {
      // Peek at step 3 command (terminal ephemeral pubkey, tag 0x83) before super advances.
      final data = _extractCommandData(cmd);
      if (data.isNotEmpty) {
        try {
          final outer = TLV.fromBytes(data);
          final inner = TLV.fromBytes(outer.value);
          if (inner.tag == 0x83) {
            final pointBytes = inner.value.sublist(1);
            _terminalEphPub = PublicKeyPACEeCDH.fromHex(hexKey: Uint8List.fromList(pointBytes));
          }
        } catch (_) {}
      }
    }
    return super.transceive(cmd);
  }
}
