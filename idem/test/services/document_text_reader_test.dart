import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_text_reader.dart';
import 'package:image/image.dart' as img;

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

  test('quarterTurns turns a photo a quarter clockwise, then anticlockwise', () {
    // White on the left, black on the right.
    final photo = img.Image(width: 32, height: 16);
    for (final pixel in photo) {
      final white = pixel.x < 16 ? 255 : 0;
      pixel.setRgb(white, white, white);
    }

    final turned = quarterTurns(Uint8List.fromList(img.encodeJpg(photo))).map(img.decodeJpg).toList();

    expect([for (final t in turned) (t!.width, t.height)], [(16, 32), (16, 32)]);
    int brightness(img.Image image, int y) => image.getPixel(8, y).r.toInt();
    expect(brightness(turned[0]!, 4), greaterThan(200), reason: 'clockwise: the left comes on top');
    expect(brightness(turned[1]!, 4), lessThan(50), reason: 'anticlockwise: the right comes on top');
  });

  test('nv21FromLuma drops the row padding and adds neutral chroma', () {
    final luma = Uint8List.fromList([1, 2, 0, 3, 4, 0]);
    expect(nv21FromLuma(luma, width: 2, height: 2, bytesPerRow: 3), [1, 2, 3, 4, 128, 128]);
  });
}
