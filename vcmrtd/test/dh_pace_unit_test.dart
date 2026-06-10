// Unit tests for DHPace (lib/src/proto/dh_pace.dart) using the ICAO 9303 p11
// Appendix G.2 DH worked-example vectors. Exercises mapping math, key
// agreement, ephemeral key handling, getters and error branches directly.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/proto/dh_pace.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';
import 'package:vcmrtd/src/utils.dart';

void main() {
  // Vectors from ICAO 9303 p11 Appendix G.2 (PACE DH worked example).
  final terminalPriv = "5265030F751F4AD18B08AC565FC7AC952E41618D".parseHex();
  final terminalPub =
      ("23FB3749EA030D2A25B278D2A562047ADE3F01B74F17A15402CB7352CA7D2B3E"
              "B71C343DB13D1DEBCE9A3666DBCFC920B49174A602CB47965CAA73DC702489A4"
              "4D41DB914DE9613DC5E98C94160551C0DF86274B9359BC0490D01B03AD54022D"
              "CB4F57FAD6322497D7A1E28D46710F461AFE710FBBBC5F8BA166F4311975EC6C")
          .parseHex();
  final chipPriv = "66DDAFEAC1609CB5B963BB0CB3FF8B3E047F336C".parseHex();
  final chipPub =
      ("78879F57225AA8080D52ED0FC890A4B25336F699AA89A2D3A189654AF70729E6"
              "23EA5738B26381E4DA19E004706FACE7B235C2DBF2F38748312F3C98C2DD4882"
              "A41947B324AA1259AC22579DB93F7085655AF30889DBB845D9E6783FE42C9F24"
              "49400306254C8AE8EE9DD812A804C0B66E8CAFC14F84D8258950A91B44126EE6")
          .parseHex();
  final sharedSecret =
      ("5BABEBEF5B74E5BA94B5C063FDA15F1F1CDE94873EE0A5D3A2FCAB49F258D07F"
              "544F13CB66658C3AFEE9E727389BE3F6CBBBD32128A8C21DD6EEA3CF7091CDDF"
              "B08B8D007D40318DCCA4FFBF51208790FB4BD111E5A968ED6B6F08B26CA87C41"
              "0B3CE0C310CE104EABD16629AA48620C1279270CB0750C0D37C57FFFE302AE7F")
          .parseHex();
  final mappedGenerator =
      ("7C9CBFE98F9FBDDA8D143506FA7D9306F4CB17E3C71707AFF5E1C1A123702496"
              "84D64EE37AF44B8DBD9D45BF6023919CBAA027AB97ACC771666C8E98FF483301"
              "BFA4872DEDE9034EDFACB70814166B7F360676829B826BEA57291B5AD69FBC84"
              "EF1E779032A305803F74341793E869742D401325B37EE8565FFCDEE618342DC5")
          .parseHex();
  final nonceDecrypted = "FA5B7E3E49753A0DB9178B7B9BD898C8".parseHex();

  final terminalEphPriv = "89CCD99B0E8D3B1F11E1296DCA68EC53411CF2CA".parseHex();
  final chipEphPriv = "A5B780126B7C980E9FCEA1D4539DA1D27C342DFA".parseHex();
  final ephSharedSecret =
      ("6BABC7B3A72BCD7EA385E4C62DB2625BD8613B24149E146A629311C4CA6698E3"
              "8B834B6A9E9CD7184BA8834AFF5043D436950C4C1E7832367C10CB8C314D40E5"
              "990B0DF7013E64B4549E2270923D06F08CFF6BD3E977DDE6ABE4C31D55C0FA2E"
              "465E553E77BDF75E3193D3834FC26E8EB1EE2FA1E4FC97C18C3F6CFFFE2607FD")
          .parseHex();

  group('DHPace key agreement and mapping (param id 0)', () {
    test('generateKeyPairFromPriv produces expected public keys', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0);
      terminal.generateKeyPairFromPriv(privKey: terminalPriv);
      expect(terminal.isPublicKeySet, true);
      expect(terminal.getPubKey().toBytes(), terminalPub);

      final chip = DomainParameterSelectorDH.getDomainParameter(id: 0);
      chip.generateKeyPairFromPriv(privKey: chipPriv);
      expect(chip.getPubKey().toBytes(), chipPub);
    });

    test('shared secret is symmetric and matches vector', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0)
        ..generateKeyPairFromPriv(privKey: terminalPriv);
      final chip = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: chipPriv);

      final ssT = terminal.getSharedSecret(otherPubKey: chip.getPubKey().toBytes());
      final ssC = chip.getSharedSecret(otherPubKey: terminal.getPubKey().toBytes());
      expect(ssT, ssC);
      expect(Utils.bigIntToUint8List(bigInt: ssT), sharedSecret);
    });

    test('mapped generator matches vector and is symmetric', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0)
        ..generateKeyPairFromPriv(privKey: terminalPriv);
      final chip = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: chipPriv);

      final genT = terminal.getMappedGenerator(otherPubKey: chip.getPubKey().toBytes(), nonce: nonceDecrypted);
      final genC = chip.getMappedGenerator(otherPubKey: terminal.getPubKey().toBytes(), nonce: nonceDecrypted);
      expect(genT, genC);
      expect(genT, mappedGenerator);
    });

    test('ephemeral key agreement on mapped generator matches vector', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0)
        ..generateKeyPairFromPriv(privKey: terminalPriv);
      final chip = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: chipPriv);

      final gen = terminal.getMappedGenerator(otherPubKey: chip.getPubKey().toBytes(), nonce: nonceDecrypted);
      final genBig = Utils.uint8ListToBigInt(gen);

      terminal.setEphemeralKeyPair(private: terminalEphPriv, ephemeralGenerator: genBig);
      chip.setEphemeralKeyPair(private: chipEphPriv, ephemeralGenerator: genBig);
      expect(terminal.isEphemeralPublicKeySet, true);
      expect(chip.isEphemeralPublicKeySet, true);

      final eT = terminal.getEphemeralSharedSecret(otherEphemeralPubKey: chip.getPubKeyEphemeral().toBytes());
      final eC = chip.getEphemeralSharedSecret(otherEphemeralPubKey: terminal.getPubKeyEphemeral().toBytes());
      expect(eT, eC);
      expect(Utils.bigIntToUint8List(bigInt: eT), ephSharedSecret);
    });

    test('generateKeyPairWithCustomGenerator yields an ephemeral public key', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0)
        ..generateKeyPairFromPriv(privKey: terminalPriv);
      final chip = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: chipPriv);
      final gen = terminal.getMappedGenerator(otherPubKey: chip.getPubKey().toBytes(), nonce: nonceDecrypted);

      terminal.generateKeyPairWithCustomGenerator(ephemeralGenerator: Utils.uint8ListToBigInt(gen), seed: 7);
      expect(terminal.isEphemeralPublicKeySet, true);
      expect(terminal.getPubKeyEphemeral().toBytes().isNotEmpty, true);
    });

    test('transformPublic round-trips a DH public key to BigInt', () {
      final terminal = DomainParameterSelectorDH.getDomainParameter(id: 0)
        ..generateKeyPairFromPriv(privKey: terminalPriv);
      final big = terminal.transformPublic(pubKey: PublicKeyPACEdH(pub: terminalPub));
      expect(big, Utils.uint8ListToBigInt(terminalPub));
    });

    test('toStringWithCaution reflects key state', () {
      final fresh = DomainParameterSelectorDH.getDomainParameter(id: 0);
      // Constructor already creates an engine (public key set), so it reports a key.
      expect(fresh.toStringWithCaution(), contains('private key'));
    });
  });

  group('DHPace error branches', () {
    test('getDomainParameter throws for unknown id', () {
      expect(() => DomainParameterSelectorDH.getDomainParameter(id: 99), throwsA(isA<DHPaceError>()));
    });

    test('getDomainParameter throws for an EC id present in map but not DH-selectable', () {
      // id 8 (secp192r1) exists in ICAO_DOMAIN_PARAMETERS but hits the DH switch
      // default branch since it is an EC curve, not a DH MODP group.
      expect(() => DomainParameterSelectorDH.getDomainParameter(id: 8), throwsA(isA<DHPaceError>()));
    });

    test('getPubKeyEphemeral throws before ephemeral key is set', () {
      final dh = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: terminalPriv);
      expect(dh.getPubKeyEphemeral, throwsA(isA<DHPaceError>()));
    });

    test('getEphemeralSharedSecret throws before ephemeral key is set', () {
      final dh = DomainParameterSelectorDH.getDomainParameter(id: 0)..generateKeyPairFromPriv(privKey: terminalPriv);
      expect(() => dh.getEphemeralSharedSecret(otherEphemeralPubKey: chipPub), throwsA(isA<DHPaceError>()));
    });

    test('all three DH curves are selectable', () {
      for (final id in [0, 1, 2]) {
        expect(() => DomainParameterSelectorDH.getDomainParameter(id: id), returnsNormally);
      }
    });
  });
}
