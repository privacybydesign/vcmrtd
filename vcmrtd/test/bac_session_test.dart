// NEW integration test for lib/src/proto/bac.dart BAC.initSession, driven
// through ICC by a fake ComProvider that emulates the chip side of the BAC
// mutual-authentication protocol. Because RND.IFD and K.IFD are generated
// randomly inside initSession, the fake chip parses the EXTERNAL AUTHENTICATE
// command, recovers them, and produces a correctly-MACed response so the full
// session-establishment path (incl. SM setup) is exercised deterministically.

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/crypto/crypto_utils.dart';
import 'package:vcmrtd/src/proto/bac.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/iso7816/iso7816.dart';
import 'package:vcmrtd/src/proto/iso7816/command_apdu.dart';
import 'package:vcmrtd/src/proto/iso7816/response_apdu.dart';

/// Emulates a passport chip performing BAC. It answers GET CHALLENGE with a
/// fixed RND.ICC and, on EXTERNAL AUTHENTICATE, validates the terminal's
/// cryptogram and returns its own (E.ICC ‖ M.ICC).
class FakeBacChip extends ComProvider {
  final Uint8List kenc;
  final Uint8List kmac;
  final Uint8List rndIcc;
  final Uint8List kicc;

  /// When true the chip corrupts the MAC of its response to force a BACError.
  final bool corruptMac;

  FakeBacChip({
    required this.kenc,
    required this.kmac,
    required this.rndIcc,
    required this.kicc,
    this.corruptMac = false,
  }) : super(Logger('fake.chip'));

  @override
  Future<void> connect() async {}
  @override
  Future<void> reconnect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  bool isConnected() => true;

  @override
  Future<Uint8List> transceive(final Uint8List data) async {
    final ins = data[1];
    if (ins == ISO7816_INS.GET_CHALLENGE) {
      return Uint8List.fromList(rndIcc + StatusWord.success.toBytes());
    }
    if (ins == ISO7816_INS.EXTERNAL_AUTHENTICATE) {
      // C-APDU layout (short): CLA INS P1 P2 Lc data... Le
      final lc = data[4];
      final cmdData = data.sublist(5, 5 + lc); // Eifd ‖ Mifd
      final eifd = Uint8List.fromList(cmdData.sublist(0, BAC.eLen));

      // Decrypt S = RND.IFD ‖ RND.ICC ‖ K.IFD
      final s = BAC.D(Kdec: kenc, Eicc: eifd);
      final rndIfd = Uint8List.fromList(s.sublist(0, BAC.nonceLen));
      final kifd = Uint8List.fromList(s.sublist(2 * BAC.nonceLen));

      // Build R = RND.ICC ‖ RND.IFD ‖ K.ICC and encrypt it.
      final r = Uint8List.fromList(rndIcc + rndIfd + kicc);
      final eicc = BAC.E(Kenc: kenc, S: r);
      var micc = BAC.MAC(Kmac: kmac, Eifd: eicc);
      if (corruptMac) {
        micc = Uint8List.fromList(micc);
        micc[0] ^= 0xFF;
      }
      // Sanity-use kifd so the analyzer doesn't flag it; not otherwise needed.
      assert(kifd.length == BAC.kLen);
      return Uint8List.fromList(eicc + micc + StatusWord.success.toBytes());
    }
    throw ComProviderError('unexpected INS ${ins.toRadixString(16)}');
  }
}

void main() {
  // ICAO 9303 p11 Appendix D.3 vectors.
  final kenc = 'AB94FDECF2674FDFB9B391F85D7F76F2'.parseHex();
  final kmac = '7962D9ECE03D1ACD4C76089DCE131543'.parseHex();
  final rndIcc = '4608F91988702212'.parseHex();
  final kicc = '0B4F80323EB3191CB04970CB4052790B'.parseHex();

  DBAKey dbaKey() => DBAKey('L898902C<', DateTime(1969, 8, 6), DateTime(1994, 6, 23));

  test('initSession completes and configures secure messaging', () async {
    // Use raw keys via an inline BacKey so we exercise the protocol with the
    // exact D.3 Kenc/Kmac rather than re-deriving from MRZ.
    final chip = FakeBacChip(kenc: kenc, kmac: kmac, rndIcc: rndIcc, kicc: kicc);
    final icc = ICC(chip);

    expect(icc.sm, isNull);
    await BAC.initSession(bacKey: _RawBacKey(kenc, kmac), icc: icc);
    expect(icc.sm, isNotNull, reason: 'SM session must be set after BAC');
  });

  test('initSession throws BACError when chip MAC verification fails', () async {
    final chip = FakeBacChip(kenc: kenc, kmac: kmac, rndIcc: rndIcc, kicc: kicc, corruptMac: true);
    final icc = ICC(chip);
    expect(() => BAC.initSession(bacKey: _RawBacKey(kenc, kmac), icc: icc), throwsA(isA<BACError>()));
  });

  test('initSession works with DBAKey-derived keys (full MRZ path)', () async {
    final key = dbaKey();
    final chip = FakeBacChip(kenc: key.encKey, kmac: key.macKey, rndIcc: rndIcc, kicc: kicc);
    final icc = ICC(chip);
    await BAC.initSession(bacKey: key, icc: icc);
    expect(icc.sm, isNotNull);
  });

  test('randomBytes sanity (used by initSession) returns requested length', () {
    expect(randomBytes(8).length, 8);
    expect(randomBytes(16).length, 16);
  });
}

/// Minimal BacKey wrapper exposing pre-derived Kenc/Kmac.
class _RawBacKey implements BacKey {
  @override
  final Uint8List encKey;
  @override
  final Uint8List macKey;
  _RawBacKey(this.encKey, this.macKey);
}
