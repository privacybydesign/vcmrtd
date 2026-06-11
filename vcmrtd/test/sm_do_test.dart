// NEW tests for the static SM data-object builders in
// lib/src/proto/iso7816/sm.dart (do85/do87/do97/do99/do8E and empty/padding branches).

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/proto/iso7816/sm.dart';

void main() {
  group('do85', () {
    test('encodes BER-TLV with tag 0x85', () {
      final out = SecureMessaging.do85('AABBCC'.parseHex());
      expect(out, '8503AABBCC'.parseHex());
    });

    test('returns empty for empty data (_buildDO empty branch)', () {
      expect(SecureMessaging.do85(Uint8List(0)), Uint8List(0));
    });
  });

  group('do87', () {
    test('prepends 0x01 padding-indicator when data is padded', () {
      final out = SecureMessaging.do87('AABB'.parseHex());
      // tag 87, len 03, 01 || data
      expect(out, '870301AABB'.parseHex());
    });

    test('prepends 0x02 indicator when dataIsPadded=false', () {
      final out = SecureMessaging.do87('AABB'.parseHex(), dataIsPadded: false);
      expect(out, '870302AABB'.parseHex());
    });

    test('returns empty for empty data (early-return branch)', () {
      expect(SecureMessaging.do87(Uint8List(0)), Uint8List(0));
    });
  });

  group('do8E', () {
    test('encodes MAC with tag 0x8E', () {
      final out = SecureMessaging.do8E('BF8B92D635FF24F8'.parseHex());
      expect(out, '8E08BF8B92D635FF24F8'.parseHex());
    });
  });

  group('do97', () {
    test('encodes a small Le directly', () {
      expect(SecureMessaging.do97(0x04), '970104'.parseHex());
    });

    test('ne == 256 encodes as single 0x00 byte', () {
      // _buildDO(tagDO97, Uint8List(1)) => 97 01 00
      expect(SecureMessaging.do97(256), '970100'.parseHex());
    });

    test('ne == 65536 encodes as two 0x00 bytes', () {
      // _buildDO(tagDO97, Uint8List(2)) => 97 02 0000
      expect(SecureMessaging.do97(65536), '9702 0000'.replaceAll(' ', '').parseHex());
    });

    test('two-byte Le is encoded big-endian', () {
      expect(SecureMessaging.do97(0x0112), '9702 0112'.replaceAll(' ', '').parseHex());
    });
  });

  group('do99', () {
    test('encodes status word value', () {
      expect(SecureMessaging.do99(0x9000), '9902 9000'.replaceAll(' ', '').parseHex());
    });
  });
}
