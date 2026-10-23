import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_text_reader.dart';

void main() {
  group('fractionsOfUpright', () {
    test('divides by the frame as it is when it needs no quarter turn', () {
      final fractions = fractionsOfUpright(
        [const Rect.fromLTRB(40, 30, 120, 60)],
        width: 400,
        height: 300,
        rotation: 180,
      );
      expect(fractions, [const Rect.fromLTRB(0.1, 0.1, 0.3, 0.2)]);
    });

    test('swaps width and height for a frame turned a quarter', () {
      final fractions = fractionsOfUpright(
        [const Rect.fromLTRB(30, 40, 60, 120)],
        width: 400,
        height: 300,
        rotation: 90,
      );
      expect(fractions, [const Rect.fromLTRB(0.1, 0.1, 0.2, 0.3)]);
    });
  });

  test('nv21FromLuma drops the row padding and adds neutral chroma', () {
    final luma = Uint8List.fromList([1, 2, 0, 3, 4, 0]);
    expect(nv21FromLuma(luma, width: 2, height: 2, bytesPerRow: 3), [1, 2, 3, 4, 128, 128]);
  });
}
