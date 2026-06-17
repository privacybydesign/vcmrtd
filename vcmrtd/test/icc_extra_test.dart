// NEW tests exercising lib/src/proto/iso7816/icc.dart with a fake ComProvider.
// These cover the command builders, response/error handling, and SM wrapping
// branches that the existing test-suite does not touch.

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/iso7816/iso7816.dart';
import 'package:vcmrtd/src/proto/iso7816/command_apdu.dart';
import 'package:vcmrtd/src/proto/iso7816/response_apdu.dart';

/// A fake [ComProvider] that records the raw command bytes sent and returns
/// queued canned response bytes (one per transceive call).
class FakeComProvider extends ComProvider {
  final List<Uint8List> sent = [];
  final List<Uint8List> _responses = [];
  bool _connected = false;
  int connectCount = 0;
  int reconnectCount = 0;
  int disconnectCount = 0;

  FakeComProvider() : super(Logger('fake.com'));

  void queue(String respHex) => _responses.add(respHex.parseHex());

  @override
  Future<void> connect() async {
    connectCount++;
    _connected = true;
  }

  @override
  Future<void> reconnect() async {
    reconnectCount++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _connected = false;
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(final Uint8List data) async {
    sent.add(data);
    if (_responses.isEmpty) {
      throw ComProviderError('no queued response');
    }
    return _responses.removeAt(0);
  }
}

void main() {
  late FakeComProvider com;
  late ICC icc;

  setUp(() {
    com = FakeComProvider();
    icc = ICC(com);
  });

  group('connection delegation', () {
    test('connect/disconnect/isConnected delegate to ComProvider', () async {
      expect(icc.isConnected(), isFalse);
      await icc.connect();
      expect(com.connectCount, 1);
      expect(icc.isConnected(), isTrue);
      await icc.disconnect();
      expect(com.disconnectCount, 1);
      expect(icc.isConnected(), isFalse);
    });
  });

  group('externalAuthenticate', () {
    test('builds command and returns data on success', () async {
      com.queue('CAFE9000');
      final out = await icc.externalAuthenticate(data: 'AABB'.parseHex(), ne: 2);
      expect(out, 'CAFE'.parseHex());
      // CLA=00 INS=82 P1=00 P2=00 Lc=02 data=AABB Le=02
      expect(com.sent.single, '0082000002AABB02'.parseHex());
    });

    test('throws ICCError on non-success status', () async {
      com.queue('6300');
      expect(
        () => icc.externalAuthenticate(data: 'AABB'.parseHex(), ne: 2),
        throwsA(isA<ICCError>().having((e) => e.sw, 'sw', StatusWord.authenticationFailed)),
      );
    });
  });

  group('PACE general authenticate steps', () {
    test('setAT success returns true and uses MSE ins', () async {
      com.queue('9000');
      final ok = await icc.setAT(data: '80010A'.parseHex());
      expect(ok, isTrue);
      final cmd = com.sent.single;
      expect(cmd[1], ISO7816_INS.MANAGE_SECURITY_ENVIRONMENT);
      expect(cmd[2], 0xC1);
      expect(cmd[3], 0xA4);
    });

    test('setAT throws on error', () async {
      com.queue('6A80');
      expect(() => icc.setAT(data: '00'.parseHex()), throwsA(isA<ICCError>()));
    });

    test('generalAuthenticatePACEstep1 returns data', () async {
      com.queue('7C0A8008001122334455669000');
      final out = await icc.generalAuthenticatePACEstep1(data: '7C00'.parseHex());
      expect(out, '7C0A800800112233445566'.parseHex());
      expect(com.sent.single[1], ISO7816_INS.GENERAL_AUTHENTICATE);
    });

    test('generalAuthenticatePACEstep1 throws on error', () async {
      com.queue('6982');
      expect(() => icc.generalAuthenticatePACEstep1(data: '7C00'.parseHex()), throwsA(isA<ICCError>()));
    });

    test('generalAuthenticatePACEstep2and3 success and error', () async {
      com.queue('7C0481029000');
      expect(await icc.generalAuthenticatePACEstep2and3(data: '7C00'.parseHex()), '7C048102'.parseHex());
      com.queue('6300');
      expect(() => icc.generalAuthenticatePACEstep2and3(data: '7C00'.parseHex()), throwsA(isA<ICCError>()));
    });

    test('generalAuthenticatePACEstep4 success and error', () async {
      com.queue('7C0486029000');
      expect(await icc.generalAuthenticatePACEstep4(data: '7C00'.parseHex()), '7C048602'.parseHex());
      com.queue('6F00');
      expect(() => icc.generalAuthenticatePACEstep4(data: '7C00'.parseHex()), throwsA(isA<ICCError>()));
    });
  });

  group('internalAuthenticate', () {
    test('success returns data with custom p1/p2', () async {
      com.queue('11229000');
      final out = await icc.internalAuthenticate(data: 'AB'.parseHex(), p1: 0x01, p2: 0x02, ne: 2);
      expect(out, '1122'.parseHex());
      final cmd = com.sent.single;
      expect(cmd[1], ISO7816_INS.INTERNAL_AUTHENTICATE);
      expect(cmd[2], 0x01);
      expect(cmd[3], 0x02);
    });

    test('throws on error', () async {
      com.queue('6A86');
      expect(() => icc.internalAuthenticate(data: 'AB'.parseHex(), ne: 2), throwsA(isA<ICCError>()));
    });
  });

  group('getChallenge', () {
    test('success returns challenge', () async {
      com.queue('00112233445566779000');
      final out = await icc.getChallenge(challengeLength: 8);
      expect(out, '0011223344556677'.parseHex());
      final cmd = com.sent.single;
      expect(cmd[1], ISO7816_INS.GET_CHALLENGE);
      // Le encoded as challengeLength
      expect(cmd.last, 0x08);
    });

    test('throws on error status', () async {
      com.queue('6700');
      expect(() => icc.getChallenge(challengeLength: 8), throwsA(isA<ICCError>()));
    });
  });

  group('readBinary', () {
    test('builds offset into P1/P2 and returns rapdu', () async {
      com.queue('DEADBEEF9000');
      final r = await icc.readBinary(offset: 0x0102, ne: 4);
      expect(r.data, 'DEADBEEF'.parseHex());
      final cmd = com.sent.single;
      expect(cmd[1], ISO7816_INS.READ_BINARY);
      expect(cmd[2], 0x01);
      expect(cmd[3], 0x02);
    });

    test('rejects offset > 32766', () {
      expect(() => icc.readBinary(offset: 32767, ne: 1), throwsArgumentError);
    });

    test('error status with no data throws ICCError', () async {
      com.queue('6987'); // SM data missing, no data
      expect(() => icc.readBinary(offset: 0, ne: 1), throwsA(isA<ICCError>()));
    });

    test('error status WITH data does not throw (returns rapdu)', () async {
      com.queue('AA6987'); // has data + error status -> branch returns rapdu
      final r = await icc.readBinary(offset: 0, ne: 1);
      expect(r.data, 'AA'.parseHex());
      expect(r.status, StatusWord.smDataMissing);
    });
  });

  group('readBinaryBySFI', () {
    test('success builds P1=sfi P2=offset', () async {
      com.queue('CC9000');
      final r = await icc.readBinaryBySFI(sfi: 0x81, offset: 0x05, ne: 1);
      expect(r.data, 'CC'.parseHex());
      final cmd = com.sent.single;
      expect(cmd[2], 0x81);
      expect(cmd[3], 0x05);
    });

    test('rejects offset > 255', () {
      expect(() => icc.readBinaryBySFI(sfi: 0x81, offset: 256, ne: 1), throwsArgumentError);
    });

    test('rejects SFI without high bit set', () {
      expect(() => icc.readBinaryBySFI(sfi: 0x01, offset: 0, ne: 1), throwsArgumentError);
    });
  });

  group('readBinaryExt', () {
    test('unwraps BER-TLV tag 0x53 payload', () async {
      // Response: 53 03 ABCDEF  + SW 9000
      com.queue('5303ABCDEF9000');
      final r = await icc.readBinaryExt(offset: 0x00, ne: 3);
      expect(r.data, 'ABCDEF'.parseHex());
      expect(com.sent.single[1], ISO7816_INS.READ_BINARY_EXT);
    });

    test('throws ICCError when returned tag is not 0x53', () async {
      com.queue('5403ABCDEF9000'); // tag 0x54 instead of 0x53
      expect(() => icc.readBinaryExt(offset: 0x00, ne: 3), throwsA(isA<ICCError>()));
    });
  });

  group('selectFile family', () {
    test('selectFile success returns data', () async {
      com.queue('6F009000');
      final out = await icc.selectFile(p1: 0x02, p2: 0x0C, data: '011E'.parseHex());
      expect(out, '6F00'.parseHex());
      expect(com.sent.single[1], ISO7816_INS.SELECT_FILE);
    });

    test('selectFile throws on error', () async {
      com.queue('6A82');
      expect(() => icc.selectFile(p1: 0, p2: 0), throwsA(isA<ICCError>()));
    });

    test('selectFileById sets P1=byID', () async {
      com.queue('9000');
      await icc.selectFileById(fileId: '3F00'.parseHex());
      expect(com.sent.single[2], ISO97816_SelectFileP1.byID);
    });

    test('selectChildDF sets P1=byChildDFID', () async {
      com.queue('9000');
      await icc.selectChildDF(childDF: '0102'.parseHex());
      expect(com.sent.single[2], ISO97816_SelectFileP1.byChildDFID);
    });

    test('selectEF sets P1=byEFID', () async {
      com.queue('9000');
      await icc.selectEF(efId: '0101'.parseHex());
      expect(com.sent.single[2], ISO97816_SelectFileP1.byEFID);
    });

    test('selectParentDF sets P1=parentDF', () async {
      com.queue('9000');
      await icc.selectParentDF();
      expect(com.sent.single[2], ISO97816_SelectFileP1.parentDF);
    });

    test('selectFileByDFName sets P1=byDFName', () async {
      com.queue('9000');
      await icc.selectFileByDFName(dfName: 'A0000002471001'.parseHex());
      expect(com.sent.single[2], ISO97816_SelectFileP1.byDFName);
    });

    test('selectFileByPath fromMF vs current DF', () async {
      com.queue('9000');
      await icc.selectFileByPath(path: '0102'.parseHex(), fromMF: true);
      expect(com.sent.single[2], ISO97816_SelectFileP1.byPathFromMF);

      com.queue('9000');
      await icc.selectFileByPath(path: '0102'.parseHex(), fromMF: false);
      expect(com.sent[1][2], ISO97816_SelectFileP1.byPath);
    });
  });

  group('SM wrapping in _transceive', () {
    test('when sm is null, command bytes are sent unmodified', () async {
      com.queue('9000');
      final expectedCmd = CommandAPDU(
        cla: 0x00,
        ins: ISO7816_INS.SELECT_FILE,
        p1: 0x02,
        p2: 0x0C,
        data: '011E'.parseHex(),
      );
      await icc.selectFile(p1: 0x02, p2: 0x0C, data: '011E'.parseHex());
      expect(com.sent.single, expectedCmd.toBytes());
      expect(icc.sm, isNull);
    });
  });
}
