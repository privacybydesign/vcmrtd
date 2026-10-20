import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/src/mrz_zone_detector.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

const _width = 600;
const _height = 400;

/// A light document with two lines of dark glyphs from [top].
cv.Mat _document({required int top, int lines = 2}) {
  final mat = cv.Mat.fromScalar(_height, _width, cv.MatType.CV_8UC1, cv.Scalar.all(230));
  for (var line = 0; line < lines; line++) {
    final y = top + line * 30;
    for (var x = 30; x < _width - 30; x += 12) {
      mat.region(cv.Rect(x, y, 8, 20)).setTo(cv.Scalar.all(30));
    }
  }
  return mat;
}

void main() {
  test('finds two lines of characters near the bottom', () {
    final zone = detectMrzZone(_document(top: 300));

    expect(zone.top, lessThanOrEqualTo(300 / _height));
    expect(zone.top + zone.height, greaterThanOrEqualTo(340 / _height));
    expect(zone.top, greaterThan(0.70), reason: 'not the fallback zone');
  });

  test('falls back to the bottom of a blank document', () {
    final zone = detectMrzZone(cv.Mat.fromScalar(_height, _width, cv.MatType.CV_8UC1, cv.Scalar.all(230)));

    expect(zone, (left: 0.02, top: 0.70, width: 0.96, height: 0.28));
  });
}
