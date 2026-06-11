// Unit tests for DataGroupReader (lib/src/data_group_reader.dart) driven by a
// scripted FakeComProvider. Covers DF1/MF selection caching, SFI-based DG/EF
// reads, reset(), the null-access-key guards, and ICCError -> DocumentError
// mapping in _exec.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';

import 'fake_com_provider.dart';

/// Builds a canned SFI read pair (chunk1 of 8 bytes + chunk2 remainder) for a
/// file with the given single-byte tag and value length (< 0x80).
List<Uint8List> sfiReadResponses(int tag, int valueLen) {
  final value = Uint8List.fromList(List.generate(valueLen, (i) => (i + 1) & 0xFF));
  final file = Uint8List.fromList([tag, valueLen, ...value]);
  final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
  final chunk2 = Uint8List.fromList([...file.sublist(8), 0x90, 0x00]);
  return [chunk1, chunk2];
}

Uint8List fileBytes(int tag, int valueLen) {
  final value = Uint8List.fromList(List.generate(valueLen, (i) => (i + 1) & 0xFF));
  return Uint8List.fromList([tag, valueLen, ...value]);
}

void main() {
  final aid = "A0000002471001".parseHex();

  group('DataGroupReader DG/EF reads', () {
    test('readDG1 selects DF1 then reads via SFI', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select DF1
        ...sfiReadResponses(0x61, 10), // DG1 EF (12 bytes total)
      ]);
      final reader = DataGroupReader(com, aid);
      final dg1 = await reader.readDG1();
      expect(dg1, fileBytes(0x61, 10));
      // First command was SELECT DF1 (by DF name, INS A4 P1 04).
      expect(com.sent.first.hex().substring(2, 6), "a404");
    });

    test('second DG read reuses cached DF1 (no extra SELECT)', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select DF1 (once)
        ...sfiReadResponses(0x61, 10), // DG1
        ...sfiReadResponses(0x75, 10), // DG2
      ]);
      final reader = DataGroupReader(com, aid);
      await reader.readDG1();
      final sentAfterDg1 = com.sent.length;
      await reader.readDG2();
      // DG2 read should add exactly 2 commands (no new SELECT).
      expect(com.sent.length - sentAfterDg1, 2);
    });

    test('readEfCOM and readEfSOD read their SFIs', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select DF1
        ...sfiReadResponses(0x60, 10), // EF.COM
        ...sfiReadResponses(0x77, 10), // EF.SOD
      ]);
      final reader = DataGroupReader(com, aid);
      final efcom = await reader.readEfCOM();
      final efsod = await reader.readEfSOD();
      expect(efcom, fileBytes(0x60, 10));
      expect(efsod, fileBytes(0x77, 10));
    });

    test('readEfCardAccess selects MF then reads SFI 0x1C', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select MF (P1=0,P2=0 succeeds first try)
        ...sfiReadResponses(0x31, 10), // EF.CardAccess (SET OF)
      ]);
      final reader = DataGroupReader(com, aid);
      final ca = await reader.readEfCardAccess();
      expect(ca, fileBytes(0x31, 10));
      // First command is SELECT MF (INS A4 P1 00 P2 00).
      expect(com.sent.first.hex().startsWith("00a40000"), true);
    });

    test('all higher data groups read through SFI', () async {
      // Drive DG3..DG16 sequentially; DF1 selected once.
      final responses = <Uint8List>["9000".parseHex()];
      for (var i = 0; i < 14; i++) {
        responses.addAll(sfiReadResponses(0x6A, 10));
      }
      final com = FakeComProvider(responses);
      final reader = DataGroupReader(com, aid);
      final readers = [
        reader.readDG3,
        reader.readDG4,
        reader.readDG5,
        reader.readDG6,
        reader.readDG7,
        reader.readDG8,
        reader.readDG9,
        reader.readDG10,
        reader.readDG11,
        reader.readDG12,
        reader.readDG13,
        reader.readDG14,
        reader.readDG15,
        reader.readDG16,
      ];
      for (final r in readers) {
        final bytes = await r();
        expect(bytes, fileBytes(0x6A, 10));
      }
    });
  });

  group('DataGroupReader reset and session guards', () {
    test('reset re-selects DF1 on next read', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select DF1
        ...sfiReadResponses(0x61, 10), // DG1
        "9000".parseHex(), // select DF1 again after reset
        ...sfiReadResponses(0x61, 10), // DG1 again
      ]);
      final reader = DataGroupReader(com, aid);
      await reader.readDG1();
      reader.reset();
      await reader.readDG1();
      // Two SELECT DF1 commands should have been sent.
      final selects = com.sent.where((c) => c.hex().substring(2, 6) == "a404").length;
      expect(selects, 2);
    });

    test('startSession throws when no BAC key configured', () async {
      final com = FakeComProvider([]);
      final reader = DataGroupReader(com, aid);
      await expectLater(reader.startSession(), throwsA(isA<Exception>()));
    });

    test('startSessionPACE throws when no PACE key configured', () async {
      final com = FakeComProvider([], throwWhenEmpty: false);
      final reader = DataGroupReader(com, aid);
      final efCardAccess = EfCardAccess.fromBytes("31143012060A04007F0007020204020202010202010D".parseHex());
      await expectLater(reader.startSessionPACE(efCardAccess), throwsA(isA<Exception>()));
    });
  });

  group('DataGroupReader error mapping', () {
    test('maps a failed read to DocumentError', () async {
      final com = FakeComProvider([
        "9000".parseHex(), // select DF1
        // chunk1 declares a longer file...
        Uint8List.fromList([0x61, 0x14, ...List.filled(6, 0xAB), 0x90, 0x00]),
        "6a82".parseHex(), // chunk2 hard error -> ICCError -> MrtdApiError -> DocumentError
      ]);
      final reader = DataGroupReader(com, aid);
      await expectLater(reader.readDG1(), throwsA(isA<DocumentError>()));
    });

    test('maps a failed DF1 select to DocumentError', () async {
      final com = FakeComProvider(["6982".parseHex()]); // security status not satisfied
      final reader = DataGroupReader(com, aid);
      await expectLater(reader.readDG1(), throwsA(isA<DocumentError>()));
    });
  });
}
