import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/services/document_portrait.dart';

/// A face the detector finds at 128 x 128, as in face_verification's tests, in grey.
Uint8List _greyFace() {
  const size = 128;
  final face = img.Image(width: size, height: size);
  img.fill(face, color: img.ColorRgb8(200, 180, 160));
  img.fillCircle(face, x: 64, y: 64, radius: 38, color: img.ColorRgb8(220, 190, 170));
  img.fillCircle(face, x: 51, y: 54, radius: 5, color: img.ColorRgb8(30, 30, 30));
  img.fillCircle(face, x: 77, y: 54, radius: 5, color: img.ColorRgb8(30, 30, 30));
  img.fillCircle(face, x: 64, y: 70, radius: 4, color: img.ColorRgb8(180, 150, 130));
  img.fillRect(face, x1: 54, y1: 84, x2: 74, y2: 90, color: img.ColorRgb8(150, 80, 80));
  return Uint8List.fromList([for (final pixel in face) pixel.luminance.toInt()]);
}

DocumentPortrait _at(Rect box) => (box: box, score: 0.7);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds the face in a grey document image, none on a blank one', () async {
    final finder = portraitFinder(await loadFaceModels());
    addTearDown(finder.close);

    final portrait = findPortrait(finder, _greyFace(), 128, 128);
    expect(portrait, isNotNull);
    expect(portrait!.box.contains(const Offset(0.5, 0.5)), isTrue);
    expect(findPortrait(finder, Uint8List(128 * 128)..fillRange(0, 128 * 128, 200), 128, 128), isNull);
  });

  test('a portrait is in place anywhere on the document, neither tiny nor filling it', () {
    expect(portraitInPlace(_at(const Rect.fromLTRB(0.1, 0.3, 0.3, 0.6))), isTrue);
    expect(portraitInPlace(_at(const Rect.fromLTRB(0.6, 0.3, 0.8, 0.6))), isTrue, reason: 'right half');
    expect(portraitInPlace(null), isFalse);
    expect(portraitInPlace(_at(const Rect.fromLTRB(0.1, 0.3, 0.15, 0.35))), isFalse, reason: 'tiny');
    expect(portraitInPlace(_at(const Rect.fromLTRB(0.0, 0.05, 0.5, 0.95))), isFalse, reason: 'fills it');
  });
}
