// Unit tests for MrtdApi driven by a scripted FakeComProvider.
// Exercises selectMasterFile fallback chain, readFile / readFileBySFI chunked
// reads, activeAuthenticate, and error branches without NFC hardware.
//
// The _handleReadBinaryStatus / _handleReadBinaryError / _reduceMaxRead /
// _trimOverread groups below drive the READ BINARY retry machinery directly
// via scripted status words - none of that needs real BAC/PACE crypto.
// initSessionViaBAC/PACE, on the other hand, need a chip that actually
// completes the mutual-authentication handshake (RND.IFD/K.IFD are generated
// randomly inside it), so those two tests reuse the existing fake crypto
// chips from bac_session_test.dart / pace_flow_test.dart rather than
// duplicating that simulation here.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';
import 'package:vcmrtd/src/lds/tlv.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/proto/mrtd_api.dart';

import 'bac_session_test.dart' show FakeBacChip;
import 'fake_com_provider.dart';
import 'pace_flow_test.dart' show CapturingEcdhChip;

/// Splits [file] into the exact sequence of response chunks (each with a
/// trailing 9000) that readFileBySFI/_readBinary would request: an initial
/// [peekLen]-byte peek, then successive [maxRead]-byte chunks for the rest.
/// Used to script a FakeComProvider matching the real read pattern.
List<Uint8List> _chunkFile(Uint8List file, {int peekLen = 8, int maxRead = 256}) {
  final out = <Uint8List>[];
  var offset = 0;
  final peekEnd = offset + peekLen > file.length ? file.length : offset + peekLen;
  out.add(Uint8List.fromList([...file.sublist(offset, peekEnd), 0x90, 0x00]));
  offset = peekEnd;
  while (offset < file.length) {
    final end = offset + maxRead > file.length ? file.length : offset + maxRead;
    out.add(Uint8List.fromList([...file.sublist(offset, end), 0x90, 0x00]));
    offset = end;
  }
  return out;
}

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

    test('readFileBySFI resumes large-file progress after a reconnect instead of restarting', () async {
      // 604-byte file: 4-byte BER header (tag + long-form length) + 600-byte
      // value, chunked at the default 256-byte max read into
      // [peek(8), rest1(256), rest2(256), rest3(84)].
      final value = Uint8List.fromList(List.generate(600, (i) => i & 0xFF));
      final file = TLV.encode(0x60, value);
      final chunks = _chunkFile(file);
      expect(chunks.length, 4);

      // First attempt: connection drops after the first "rest" chunk (the
      // FakeComProvider throws ComProviderError once its queue runs dry,
      // simulating the tag moving out of range).
      final com1 = FakeComProvider([chunks[0], chunks[1]]);
      final api1 = MrtdApi(com1);
      final state = MrtdFileReadState();
      await expectLater(api1.readFileBySFI(0x02, state: state), throwsA(isA<ComProviderError>()));

      // The header and first rest chunk already made it into the shared
      // state and should not need to be re-fetched.
      expect(state.hasHeader, true);
      expect(state.content.length, 256);

      // Second attempt: new connection/session (new MrtdApi), same cached
      // state. Only a small re-select read plus the two still-missing rest
      // chunks are needed to finish - not a full re-read from offset 0.
      final com2 = FakeComProvider([chunks[0], chunks[2], chunks[3]]);
      final api2 = MrtdApi(com2);
      final raw = await api2.readFileBySFI(0x02, state: state);

      expect(raw, file);
      // 1 re-select read + 2 remaining chunks = 3 commands (a full re-read
      // would have needed 4: peek + all 3 rest chunks).
      expect(com2.sent.length, 3);
    });

    test('readFileBySFI without a state param behaves exactly as before (no resume across calls)', () async {
      final fullValue = "00112233445566778899".parseHex();
      final file = Uint8List.fromList([0x60, 0x0A, ...fullValue]);
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final chunk2 = Uint8List.fromList([...file.sublist(8, 12), 0x90, 0x00]);
      final com = FakeComProvider([chunk1, chunk2]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x01);
      expect(raw, file);
      expect(com.sent.length, 2);
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

    test('MrtdApiError.toString formats the message', () {
      expect(MrtdApiError('boom').toString(), 'MRTDApiError: boom');
    });
  });

  group('initSessionViaBAC / initSessionViaPACE', () {
    // ICAO 9303 p11 Appendix D.3 vectors - same as bac_session_test.dart.
    final rndIcc = '4608F91988702212'.parseHex();
    final kicc = '0B4F80323EB3191CB04970CB4052790B'.parseHex();

    test('initSessionViaBAC completes a full handshake and sets up secure messaging', () async {
      final key = DBAKey('L898902C<', DateTime(1969, 8, 6), DateTime(1994, 6, 23));
      final chip = FakeBacChip(kenc: key.encKey, kmac: key.macKey, rndIcc: rndIcc, kicc: kicc);
      final api = MrtdApi(chip);

      expect(api.icc.sm, isNull);
      await api.initSessionViaBAC(key);
      expect(api.icc.sm, isNotNull);
    });

    Future<void> initSessionViaPaceEcdhGmHandshake() async {
      final efCardAccess = EfCardAccess.fromBytes("31143012060A04007F0007020204020202010202010D".parseHex());
      final protocol = efCardAccess.paceInfo!.protocol;
      final dba = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);
      final chip = CapturingEcdhChip(dbaKey: dba, protocol: protocol, paramId: 13);
      final api = MrtdApi(chip);

      expect(api.icc.sm, isNull);
      await api.initSessionViaPACE(dba, efCardAccess);
      expect(api.icc.sm, isNotNull);
    }

    test(
      'initSessionViaPACE completes a full ECDH-GM handshake and sets up secure messaging',
      initSessionViaPaceEcdhGmHandshake,
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // --------------------------------------------------------------------------
  // _readBinary status/error handling and _reduceMaxRead, driven directly
  // through readFileBySFI with scripted status words. None of these need a
  // real BAC/PACE session - MrtdApi's SM layer isn't involved in framing.
  // --------------------------------------------------------------------------
  group('_readBinary status word handling', () {
    /// Builds a short-form BER-TLV file: tag 0x60, 1-byte length, [valueLen]
    /// content bytes (0x00, 0x01, 0x02, ...).
    Uint8List buildFile(int valueLen) {
      final value = Uint8List.fromList(List.generate(valueLen, (i) => i & 0xFF));
      return Uint8List.fromList([0x60, valueLen, ...value]);
    }

    test('sw1SuccessWithRemainingBytes (0x61xx) is treated as a normal chunk', () async {
      final file = buildFile(20); // header(2) + 20 value bytes = 22 bytes total
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]); // peek: header + 6 value bytes
      final rest = Uint8List.fromList([...file.sublist(8), 0x61, 0x05]); // remaining 14 bytes, SW=61xx

      final com = FakeComProvider([chunk1, rest]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x01);
      expect(raw, file);
    });

    test('unexpectedEOF (0x6282) reduces max read but keeps the partial data received', () async {
      final file = buildFile(20);
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      // First "rest" response under-delivers (6 of the 14 remaining bytes)
      // with SW=6282 (unexpectedEOF); the rest arrives normally after that.
      final restA = Uint8List.fromList([...file.sublist(8, 14), 0x62, 0x82]);
      final restB = Uint8List.fromList([...file.sublist(14), 0x90, 0x00]);

      final com = FakeComProvider([chunk1, restA, restB]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x02);
      expect(raw, file);
    });

    test('possibleCorruptedData (0x6281) is logged but the data is kept', () async {
      final file = buildFile(20);
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final rest = Uint8List.fromList([...file.sublist(8), 0x62, 0x81]);

      final com = FakeComProvider([chunk1, rest]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x03);
      expect(raw, file);
    });

    test('an error status word with data attached is logged/re-init-ed but the data is still kept', () async {
      final file = buildFile(20);
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      // 0x6982 securityStatusNotSatisfied: isError() is true, but since data
      // is attached ICC._readBinary does not throw - MrtdApi must still fold
      // it in (and no _reinitSession is configured, so the call is a no-op).
      final rest = Uint8List.fromList([...file.sublist(8), 0x69, 0x82]);

      final com = FakeComProvider([chunk1, rest]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x04);
      expect(raw, file);
    });

    test('a success response with no data logs a warning and retries the same offset', () async {
      final file = buildFile(9); // header(2) + 9 value bytes; remaining after peek = 3
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      // Success with an empty data field: length isn't decremented, so the
      // loop retries the same read - which then finds the fake's queue
      // empty and throws.
      final emptyOk = "9000".parseHex();

      final com = FakeComProvider([chunk1, emptyOk]);
      final api = MrtdApi(com);
      await expectLater(api.readFileBySFI(0x05), throwsA(isA<ComProviderError>()));
    });

    test('a chunk larger than requested is trimmed to the declared file length', () async {
      final file = buildFile(10); // header(2) + 10 value bytes = 12 bytes; remaining after peek = 4
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      // Some passports pad with extra bytes beyond the declared length - here
      // 2 junk bytes beyond the last 4 real ones.
      final overread = Uint8List.fromList([...file.sublist(8), 0xDE, 0xAD, 0x90, 0x00]);

      final com = FakeComProvider([chunk1, overread]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x06);
      expect(raw, file);
    });

    test('sw1WrongLengthWithExactLength (0x6Cxx) sets max read to the indicated exact length', () async {
      final file = buildFile(7); // header(2) + 7 value bytes; remaining after peek = 1
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final wrongLen = Uint8List.fromList([0x6C, 0x05]); // "should have asked for 5 bytes", no data
      final finalChunk = Uint8List.fromList([...file.sublist(8), 0x90, 0x00]);

      final com = FakeComProvider([chunk1, wrongLen, finalChunk]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x07);
      expect(raw, file);
    });

    test('repeated wrongLength (0x6700) errors walk max read all the way down to 1 byte, then succeed', () async {
      final file = buildFile(7); // header(2) + 7 value bytes; remaining after peek = 1
      final chunk1 = Uint8List.fromList([...file.sublist(0, 8), 0x90, 0x00]);
      final wrongLength = "6700".parseHex(); // no data -> ICCError, and _maxRead != 1 each time until it bottoms out
      // 256 -> 224 -> 160 -> 128 -> 96 -> 64 -> 32 -> 16 -> 8 -> 1 is 9 reductions.
      final finalChunk = Uint8List.fromList([...file.sublist(8), 0x90, 0x00]);

      final com = FakeComProvider([chunk1, ...List.generate(9, (_) => wrongLength), finalChunk]);
      final api = MrtdApi(com);
      final raw = await api.readFileBySFI(0x08);
      expect(raw, file);
      expect(com.sent.length, 11);
    });
  });
}
