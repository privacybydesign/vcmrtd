import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/text_skew.dart';
import 'package:image/image.dart' as img;

import 'text_page.dart';

double skewOf(img.Image image) {
  final grey = greyMat(image);
  try {
    return textSkew(grey);
  } finally {
    grey.dispose();
  }
}

void main() {
  test('finds level text level', () {
    expect(skewOf(textPage()), closeTo(0, 1));
  });

  test('finds text turned clockwise as needing that turn anticlockwise', () {
    expect(skewOf(img.copyRotate(textPage(), angle: 20)), closeTo(20, 1));
    expect(skewOf(img.copyRotate(textPage(), angle: -35)), closeTo(-35, 1));
  });

  test('finds sideways text off a quarter turn by its tilt alone', () {
    expect(skewOf(img.copyRotate(textPage(), angle: 90)), closeTo(0, 1));
    expect(skewOf(img.copyRotate(textPage(), angle: 80)), closeTo(-10, 1));
  });

  test('leaves a photo without text as it is', () {
    expect(skewOf(img.Image(width: 600, height: 400)..clear(img.ColorRgb8(255, 255, 255))), 0);
  });

  test('cannot tell upside down from upright', () {
    expect(skewOf(img.copyRotate(textPage(), angle: 180)), closeTo(0, 1));
  });

  test('levelled keeps the corners of what it turns', () {
    final grey = greyMat(img.copyRotate(textPage(), angle: 20));
    final level = levelled(grey, skewOf(img.copyRotate(textPage(), angle: 20)));
    try {
      expect(level.cols, greaterThan(grey.cols));
      expect(level.rows, greaterThan(grey.rows));
      expect(textSkew(level), closeTo(0, 1));
    } finally {
      grey.dispose();
      level.dispose();
    }
  });
}
