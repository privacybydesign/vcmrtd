import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/services/document_material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

const _size = 1024;

/// Slowly changing colours, like a document's printed background.
List<double> _background(int x, int y) => [
  150 + 40 * math.sin(x / 300),
  170 + 30 * math.cos(y / 250),
  140 + 50 * math.sin((x + y) / 400),
];

cv.Mat _image(List<double> Function(int x, int y) colour, {required double noise}) {
  final random = math.Random(1);
  double gauss() => math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble());
  final mat = cv.Mat.create(rows: _size, cols: _size, type: cv.MatType.CV_8UC3);
  final data = mat.data;
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final c = colour(x, y);
      final n = noise * gauss();
      for (var ch = 0; ch < 3; ch++) {
        data[(y * _size + x) * 3 + ch] = (c[ch] + n).round().clamp(0, 255);
      }
    }
  }
  return mat;
}

/// Turned a few degrees, as a phone never lines up with what it films.
(double, double) _turned(int x, int y, {double degrees = 5}) {
  final a = degrees * math.pi / 180;
  return (x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a));
}

List<double> _screen(int x, int y) {
  const pitch = 4.5;
  final (u, v) = _turned(x, y);
  final column = (u / pitch) % 1;
  final gap = (v / pitch) % 1 > 0.75;
  final c = _background(x, y);
  if (gap) return [c[0] * 0.3, c[1] * 0.3, c[2] * 0.3];
  // BGR: the red, green and blue subpixels side by side.
  final lit = column < 1 / 3 ? 2 : (column < 2 / 3 ? 1 : 0);
  return [for (var ch = 0; ch < 3; ch++) ch == lit ? math.min(255.0, c[ch] * 2.2) : c[ch] * 0.5];
}

double _darkness(List<double> colour) => 1 - (colour[0] + colour[1] + colour[2]) / 3 / 255;

/// A laser print: one ink in a halftone screen of dots.
List<double> _halftonePrint(int x, int y) {
  const pitch = 6.0;
  final (u, v) = _turned(x, y, degrees: 45);
  final du = (u / pitch) % 1 - 0.5;
  final dv = (v / pitch) % 1 - 0.5;
  final inked = du * du + dv * dv < _darkness(_background(x, y)) * 0.4;
  return inked ? [60, 60, 70] : [235, 235, 230];
}

bool _shining(int x, int y) => math.pow(x - 700, 2) + math.pow(y - 300, 2) < 30 * 30;

List<double> _plastic(int x, int y) => _shining(x, y) ? [255, 255, 255] : _background(x, y);

/// Through the camera's JPEG, as the document photo step gets it.
img.Image _jpeg(cv.Mat bgr) {
  final image = img.Image.fromBytes(
    width: bgr.cols,
    height: bgr.rows,
    bytes: bgr.data.buffer,
    bytesOffset: bgr.data.offsetInBytes,
    order: img.ChannelOrder.bgr,
  );
  return img.decodeJpg(img.encodeJpg(image, quality: 90))!;
}

void main() {
  test('a plastic document shows no reproduction', () {
    final material = inspectDocumentMat(_image(_plastic, noise: 2));

    expect(material.medium, DocumentMedium.physical);
    expect(material.periodicPeak, lessThan(4));
  });

  test("sensor noise and the camera's JPEG blocks don't pass for a pattern", () {
    final material = inspectDocumentMaterial(_jpeg(_image(_plastic, noise: 6)));

    expect(material.medium, DocumentMedium.physical);
    expect(material.periodicPeak, lessThan(4));
  });

  test("a screen's pixel grid is found", () {
    final material = inspectDocumentMaterial(_jpeg(_image(_screen, noise: 2)));

    expect(material.medium, DocumentMedium.reproduction);
  });

  test("a laser print's halftone screen is found", () {
    final material = inspectDocumentMaterial(_jpeg(_image(_halftonePrint, noise: 2)));

    expect(material.medium, DocumentMedium.reproduction);
  });

  group('as measured on a Galaxy', () {
    DocumentMaterial measured({
      required double periodicPeak,
      required double fineTexture,
      required double saturation,
    }) => DocumentMaterial(
      periodicPeak: periodicPeak,
      colourFringing: 0.2,
      fineTexture: fineTexture,
      saturation: saturation,
      blackLevel: 0.2,
      shine: 0,
      inspectedWidth: 1533,
      inspectedHeight: 967,
      tiles: 6,
    );

    test('a real Dutch ID card, pale, grainy and matte as it is, is physical', () {
      for (final (peak, texture, saturation) in [(4.10, 0.0291, 0.361), (9.35, 0.0276, 0.247), (5.62, 0.0389, 0.263)]) {
        expect(
          measured(periodicPeak: peak, fineTexture: texture, saturation: saturation).medium,
          DocumentMedium.physical,
        );
      }
    });

    test('the same card on a laptop screen is a reproduction', () {
      for (final peak in [21.68, 15.15, 10.22, 12.66, 17.70]) {
        expect(measured(periodicPeak: peak, fineTexture: 0.13, saturation: 0.18).medium, DocumentMedium.reproduction);
      }
    });
  });
}
