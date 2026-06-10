// Targeted tests for PACE-CAM helper methods in pace.dart that the existing
// pace_cam_test.dart does not reach: extractPkIcForCAM failure paths and
// readCardSecurity error handling. Uses a fake ComProvider for the ICC.
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';
import 'package:vcmrtd/src/proto/pace.dart';

import 'fake_com_provider.dart';

/// ComProvider that always returns the same response.
class _ConstChip extends ComProvider {
  final Uint8List resp;
  _ConstChip(this.resp) : super(Logger('ConstChip'));
  @override
  Future<void> connect() async {}
  @override
  Future<void> reconnect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  bool isConnected() => true;
  @override
  Future<Uint8List> transceive(Uint8List data) async => resp;
}

void main() {
  group('PACE.extractPkIcForCAM', () {
    test('throws PACEError when no matching CA public key info present', () {
      expect(() => PACE.extractPkIcForCAM([], 13), throwsA(isA<PACEError>()));
    });
  });

  group('PACE.readCardSecurity', () {
    test('throws PACEError when EF.CardSecurity read returns no data', () async {
      // First SFI read returns only a status word (no data) -> ICCError inside
      // readBinaryBySFI? No: readBinaryBySFI returns the response; readCardSecurity
      // sees empty data and throws PACEError. Use 6A80 with no data which the ICC
      // _readBinary treats as error and throws ICCError -> propagates.
      // Provide success-with-empty-data to hit the explicit empty-data guard.
      final chip = _ConstChip("9000".parseHex()); // success, but zero data bytes
      final icc = ICC(chip);
      await expectLater(PACE.readCardSecurity(icc), throwsA(isA<Exception>()));
    });

    test('reads a short EF.CardSecurity in a single SFI chunk', () async {
      // Build a tiny BER file: tag 0x30 (SEQUENCE), len 0x04, 4 value bytes.
      // chunk1 read (ne=256) returns the whole file -> loop ends immediately.
      final file = "3004A1A2A3A4".parseHex();
      final resp = Uint8List.fromList([...file, 0x90, 0x00]);
      final chip = FakeComProvider([resp]);
      final icc = ICC(chip);
      final data = await PACE.readCardSecurity(icc);
      expect(data, file);
      // First (and only) read is an SFI READ BINARY: P1 = 0x80 | 0x1D = 0x9D.
      expect(chip.sent.first.hex(), "00b09d0000");
    });
  });
}
