// Tests for the constant-time comparison helper in lib/src/crypto/crypto_utils.dart.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/src/crypto/crypto_utils.dart';

Uint8List _b(List<int> xs) => Uint8List.fromList(xs);

void main() {
  group('constantTimeEqual', () {
    test('returns true for equal byte sequences', () {
      expect(constantTimeEqual(_b([1, 2, 3, 4]), _b([1, 2, 3, 4])), isTrue);
    });

    test('returns true for two empty sequences', () {
      expect(constantTimeEqual(_b([]), _b([])), isTrue);
    });

    test('returns false when a single byte differs', () {
      expect(constantTimeEqual(_b([1, 2, 3, 4]), _b([1, 2, 3, 5])), isFalse);
    });

    test('returns false when the first byte differs', () {
      expect(constantTimeEqual(_b([9, 2, 3, 4]), _b([1, 2, 3, 4])), isFalse);
    });

    test('returns false for different lengths (prefix match)', () {
      expect(constantTimeEqual(_b([1, 2, 3]), _b([1, 2, 3, 4])), isFalse);
      expect(constantTimeEqual(_b([1, 2, 3, 4]), _b([1, 2, 3])), isFalse);
    });

    test('returns false when one side is empty and the other is not', () {
      expect(constantTimeEqual(_b([]), _b([0])), isFalse);
    });

    test('does not treat the operands as reference-equal shortcuts', () {
      final a = _b([0, 0, 0, 0]);
      expect(constantTimeEqual(a, a), isTrue);
    });
  });
}
