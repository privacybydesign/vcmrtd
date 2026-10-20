import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:mrz_capture/src/tesseract_image.dart';

const _width = 600;
const _height = 400;

/// NV21 of a document with two MRZ lines at the bottom, in [paper] and [ink];
/// with [sideways] the sensor holds it turned a quarter anticlockwise.
OcrFrame _frame({int paper = 230, int ink = 30, bool sideways = false}) {
  final upright = Uint8List(_width * _height)..fillRange(0, _width * _height, paper);
  for (final top in [300, 330]) {
    for (var y = top; y < top + 20; y++) {
      for (var x = 30; x < _width - 30; x++) {
        if (x % 12 < 8) upright[y * _width + x] = ink;
      }
    }
  }
  final (width, height) = sideways ? (_height, _width) : (_width, _height);
  final bytes = Uint8List(width * height * 3 ~/ 2)..fillRange(width * height, width * height * 3 ~/ 2, 128);
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final i = sideways ? (_width - 1 - x) * width + y : y * width + x;
      bytes[i] = upright[y * _width + x];
    }
  }
  return OcrFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: width,
    rotation: sideways ? 90 : 0,
    roiLeft: 0,
    roiTop: 0,
    roiWidth: 1,
    roiHeight: 1,
    isNv21: true,
  );
}

int _mean(TesseractImage image) => image.pixels.reduce((a, b) => a + b) ~/ image.pixels.length;

void main() {
  test('cuts out the MRZ with a white border', () {
    final image = tesseractImage(_frame());

    expect(image.pixels.length, image.width * image.height);
    expect(image.height, lessThan(_height ~/ 2), reason: 'only the MRZ band is kept');
    expect(image.pixels.sublist(0, image.width), everyElement(255));
    expect(image.pixels.sublist(image.pixels.length - image.width), everyElement(255));
  });

  test('turns light text on a dark background into dark text on white', () {
    final image = tesseractImage(_frame(paper: 30, ink: 230));

    expect(_mean(image), greaterThan(110));
  });

  test('turns a sideways frame upright', () {
    final upright = tesseractImage(_frame());
    final sideways = tesseractImage(_frame(sideways: true));

    expect((sideways.width, sideways.height), (upright.width, upright.height));
    expect(sideways.pixels, upright.pixels);
  });
}
