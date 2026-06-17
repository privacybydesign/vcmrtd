// New unit tests for lib/src/extension/byte_reader.dart
// Covers readInt (various widths), readBytes, skip, peekByte, readRemaining,
// hasRemaining, isEOF/position/remaining and all RangeError bounds branches.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/src/extension/byte_reader.dart';

void main() {
  Uint8List bytes(List<int> b) => Uint8List.fromList(b);

  group('ByteReader.readInt', () {
    test('reads 1, 2, 3 and 4 byte big-endian integers in sequence', () {
      final r = ByteReader(bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A]));
      expect(r.readInt(1), 0x01);
      expect(r.readInt(2), 0x0203);
      expect(r.readInt(3), 0x040506);
      expect(r.readInt(4), 0x0708090A);
      expect(r.isEOF, isTrue);
    });

    test('throws RangeError when not enough bytes remain', () {
      final r = ByteReader(bytes([0x01]));
      expect(() => r.readInt(2), throwsRangeError);
      // offset must not have advanced on failure
      expect(r.position, 0);
    });
  });

  group('ByteReader.readBytes', () {
    test('returns the requested slice and advances offset', () {
      final r = ByteReader(bytes([0xAA, 0xBB, 0xCC, 0xDD]));
      expect(r.readBytes(2), bytes([0xAA, 0xBB]));
      expect(r.position, 2);
      expect(r.remaining, 2);
    });

    test('throws RangeError when length exceeds remaining', () {
      final r = ByteReader(bytes([0x01, 0x02]));
      expect(() => r.readBytes(3), throwsRangeError);
    });
  });

  group('ByteReader.skip', () {
    test('advances offset by length', () {
      final r = ByteReader(bytes([1, 2, 3, 4]));
      r.skip(2);
      expect(r.position, 2);
      expect(r.readInt(1), 3);
    });

    test('throws RangeError when skipping past the end', () {
      final r = ByteReader(bytes([1, 2]));
      expect(() => r.skip(5), throwsRangeError);
    });
  });

  group('ByteReader.peekByte', () {
    test('returns next byte without advancing', () {
      final r = ByteReader(bytes([0x42, 0x43]));
      expect(r.peekByte(), 0x42);
      expect(r.position, 0);
      expect(r.readInt(1), 0x42);
    });

    test('throws RangeError at EOF', () {
      final r = ByteReader(bytes([]));
      expect(() => r.peekByte(), throwsRangeError);
    });
  });

  group('ByteReader.readRemaining', () {
    test('returns all remaining bytes and reaches EOF', () {
      final r = ByteReader(bytes([1, 2, 3, 4]));
      r.skip(1);
      expect(r.readRemaining(), bytes([2, 3, 4]));
      expect(r.isEOF, isTrue);
      expect(r.remaining, 0);
    });

    test('returns empty list when already at EOF', () {
      final r = ByteReader(bytes([1]));
      r.skip(1);
      expect(r.readRemaining(), bytes([]));
    });
  });

  group('ByteReader.hasRemaining / state getters', () {
    test('hasRemaining reflects available bytes', () {
      final r = ByteReader(bytes([1, 2, 3]));
      expect(r.hasRemaining(3), isTrue);
      expect(r.hasRemaining(4), isFalse);
      r.skip(3);
      expect(r.hasRemaining(1), isFalse);
      expect(r.hasRemaining(0), isTrue);
    });

    test('isEOF is true for an empty buffer', () {
      expect(ByteReader(bytes([])).isEOF, isTrue);
    });
  });
}
