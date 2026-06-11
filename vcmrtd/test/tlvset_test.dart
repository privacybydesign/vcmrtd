// New unit tests for lib/src/lds/tlvSet.dart
// Covers TLVSet decode (multiple entries, decode-error break path), add,
// toBytes, length, at() bounds error, and the `all` getter.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/tlv.dart';
import 'package:vcmrtd/src/lds/tlvSet.dart';

void main() {
  group('TLVSet.decode', () {
    test('decodes multiple consecutive TLVs', () {
      // Two simple TLVs: tag 0x80 len 1 val 0xAA ; tag 0x81 len 2 val 0xBBCC
      final data = '8001AA8102BBCC'.parseHex();
      final set = TLVSet.decode(encodedData: data);

      expect(set.length, 2);
      expect(set.at(index: 0).tag, 0x80);
      expect(set.at(index: 0).value, 'AA'.parseHex());
      expect(set.at(index: 1).tag, 0x81);
      expect(set.at(index: 1).value, 'BBCC'.parseHex());
    });

    test('round-trips through toBytes', () {
      final data = '8001AA8102BBCC'.parseHex();
      final set = TLVSet.decode(encodedData: data);
      expect(set.toBytes(), data);
    });

    test('stops decoding at the first malformed entry (break path)', () {
      // First TLV is valid (tag 0x80 len 1 val 0x11). Then a truncated TLV
      // (tag 0x82 declares length 5 but only 1 byte follows) -> decode throws,
      // loop catches and breaks, leaving just the first entry.
      final data = '8001118205AA'.parseHex();
      final set = TLVSet.decode(encodedData: data);

      expect(set.length, 1);
      expect(set.at(index: 0).tag, 0x80);
      expect(set.at(index: 0).value, '11'.parseHex());
    });

    test('empty input yields an empty set', () {
      final set = TLVSet.decode(encodedData: Uint8List(0));
      expect(set.length, 0);
      expect(set.toBytes(), Uint8List(0));
    });
  });

  group('TLVSet construction and mutation', () {
    test('default constructor starts empty and add appends', () {
      final set = TLVSet();
      expect(set.length, 0);

      set.add(TLV(0x80, '0102'.parseHex()));
      set.add(TLV(0x81, '03'.parseHex()));

      expect(set.length, 2);
      expect(set.all.length, 2);
      expect(set.all[1].tag, 0x81);
    });

    test('constructor accepts an initial tlv list', () {
      final set = TLVSet(tlvs: [TLV(0x80, '00'.parseHex())]);
      expect(set.length, 1);
      expect(set.at(index: 0).tag, 0x80);
    });
  });

  group('TLVSet.at bounds', () {
    test('throws TLVError on negative index', () {
      final set = TLVSet(tlvs: [TLV(0x80, '00'.parseHex())]);
      expect(() => set.at(index: -1), throwsA(isA<TLVError>()));
    });

    test('throws TLVError when index >= length', () {
      final set = TLVSet(tlvs: [TLV(0x80, '00'.parseHex())]);
      expect(() => set.at(index: 1), throwsA(isA<TLVError>()));
    });
  });

  group('TLVSetrror', () {
    test('toString returns the message', () {
      expect(TLVSetrror('oops').toString(), 'oops');
    });
  });
}
