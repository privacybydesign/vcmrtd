// Unit tests for MrtdApi driven by a scripted FakeComProvider.
// Exercises selectMasterFile fallback chain, readFile / readFileBySFI chunked
// reads, activeAuthenticate, and error branches without NFC hardware.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/proto/mrtd_api.dart';

import 'fake_com_provider.dart';

void main() {
  group('MrtdApi', () {
    test('selectMasterFile succeeds on first attempt (P1=0,P2=0)', () async {
      final com = FakeComProvider.fromHex(["9000"]);
      final api = MrtdApi(com);
      await api.selectMasterFile();
      // Only one command sent: select with P1=0 P2=0.
      expect(com.sent.length, 1);
      // CLA=00 INS=A4 P1=00 P2=00
      expect(com.sent.first.hex().startsWith("00a40000"), true);
    });

    test('selectMasterFile falls through all fallbacks and finally succeeds', () async {
      // First three selects fail (6A82 file not found), the last succeeds.
      final com = FakeComProvider.fromHex(["6a82", "6a82", "6a82", "9000"]);
      final api = MrtdApi(com);
      await api.selectMasterFile();
      expect(com.sent.length, 4);
    });

    test('selectMasterFile rethrows if every fallback fails', () async {
      final com = FakeComProvider.fromHex(["6a82", "6a82", "6a82", "6a82"]);
      final api = MrtdApi(com);
      await expectLater(api.selectMasterFile(), throwsA(isA<Exception>()));
      expect(com.sent.length, 4);
    });

    test('selectEMrtdApplication sends SELECT by DF name', () async {
      final com = FakeComProvider.fromHex(["9000"]);
      final api = MrtdApi(com);
      final aid = "A0000002471001".parseHex();
      await api.selectEMrtdApplication(aid);
      expect(com.sent.length, 1);
      // INS A4, P1=04 (byDFName), P2=0x0C (default FCP|FMD)
      expect(com.sent.first.hex().substring(2, 8), "a4040c");
    });

    test('readFileBySFI reads a small file across two chunks', () async {
      // File: tag 0x60, length 0x0A (10), 10 value bytes => total 12 bytes.
      // chunk1 = first 8 bytes (header 60 0A + 6 value bytes), chunk2 = 4 bytes.
      final fullValue = "00112233445566778899".parseHex(); // 10 bytes
      final file = Uint8List.fromList([0x60, 0x0A, ...fullValue]); // 12 bytes
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final chunk2 = Uint8List.fromList([...file.sublist(8, 12), 0x90, 0x00]);

      final com = FakeComProvider([chunk1, chunk2]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x01);
      expect(raw, file);
      expect(com.sent.length, 2);
      // First read uses SFI (P1 = 0x80|0x01 = 0x81), p2=0 (offset), ne=8.
      expect(com.sent.first.hex(), "00b0810008");
    });

    test('readFileBySFI throws ArgumentError on invalid SFI', () async {
      final com = FakeComProvider.fromHex(["9000"]);
      final api = MrtdApi(com);
      // sfi 0x20 | 0x80 = 0xA0 > 0x9F -> ArgumentError
      await expectLater(api.readFileBySFI(0x20), throwsA(isA<ArgumentError>()));
    });

    test('readFile selects EF then reads file', () async {
      // Build a 12-byte file as above.
      final fullValue = "aabbccddeeff0011223344".parseHex(); // 11 bytes
      final file = Uint8List.fromList([0x60, 0x0B, ...fullValue]); // 13 bytes
      final selResp = "9000".parseHex();
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final chunk2 = Uint8List.fromList([...file.sublist(8), 0x90, 0x00]);

      final com = FakeComProvider([selResp, chunk1, chunk2]);
      final api = MrtdApi(com);
      final raw = await api.readFile(0x011E);
      expect(raw, file);
      // First command is SELECT EF.
      expect(com.sent.first.hex().substring(2, 6), "a402");
    });

    test('readFile throws MrtdApiError on fid > 0xFFFF', () async {
      final com = FakeComProvider.fromHex(["9000"]);
      final api = MrtdApi(com);
      await expectLater(api.readFile(0x10000), throwsA(isA<MrtdApiError>()));
    });

    test('activeAuthenticate sends INTERNAL AUTHENTICATE and returns signature', () async {
      final sig = "0102030405060708".parseHex();
      final resp = Uint8List.fromList([...sig, 0x90, 0x00]);
      final com = FakeComProvider([resp]);
      final api = MrtdApi(com);
      final challenge = "1122334455667788".parseHex();
      final result = await api.activeAuthenticate(challenge);
      expect(result, sig);
      // INS 0x88 INTERNAL_AUTHENTICATE
      expect(com.sent.first.hex().substring(2, 4), "88");
    });

    test('readFileBySFI propagates ICCError as MrtdApiError when read chunk fails', () async {
      // chunk1 OK (declares larger file), chunk2 returns hard error with no data.
      final file = Uint8List.fromList([0x60, 0x14, ...List.filled(20, 0xAB)]); // total 22
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      // 0x6A82 file not found, no data -> ICCError -> MrtdApiError
      final chunkErr = "6a82".parseHex();
      final com = FakeComProvider([chunk1, chunkErr]);
      final api = MrtdApi(com);
      await expectLater(api.readFileBySFI(0x02), throwsA(isA<MrtdApiError>()));
    });
  });
}
