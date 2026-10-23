import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'camera_viewfinder.dart';
import 'mrz_zone_detector.dart';

/// 8-bit grey pixels, one byte per pixel, rows without padding.
typedef TesseractImage = ({Uint8List pixels, int width, int height});

const _borderWidth = 10;
const _darkMean = 110;

const _rotations = {90: cv.ROTATE_90_CLOCKWISE, 180: cv.ROTATE_180, 270: cv.ROTATE_90_COUNTERCLOCKWISE};

/// What Tesseract reads of an NV21 [frame]: its MRZ, upright, stretched to
/// full contrast as dark text on white, with a white border.
TesseractImage tesseractImage(OcrFrame frame) {
  final luma = cv.Mat.create(rows: frame.height, cols: frame.width, type: cv.MatType.CV_8UC1);
  final data = luma.data;
  for (var y = 0; y < frame.height; y++) {
    data.setRange(y * frame.width, (y + 1) * frame.width, frame.bytes, y * frame.bytesPerRow);
  }

  final roi = frame.sensorRoi;
  final x = roi.x.clamp(0, frame.width - 1);
  final y = roi.y.clamp(0, frame.height - 1);
  final inFrame = luma.region(cv.Rect(x, y, roi.w.clamp(1, frame.width - x), roi.h.clamp(1, frame.height - y)));
  final rotation = _rotations[frame.rotation];
  final upright = rotation == null ? inFrame.clone() : cv.rotate(inFrame, rotation);
  inFrame.dispose();
  luma.dispose();

  final zone = detectMrzZone(upright);
  final zoneLeft = (zone.left * upright.cols).toInt().clamp(0, upright.cols - 1);
  final zoneTop = (zone.top * upright.rows).toInt().clamp(0, upright.rows - 1);
  final zoneRight = ((zone.left + zone.width) * upright.cols).toInt().clamp(zoneLeft + 1, upright.cols);
  final zoneBottom = ((zone.top + zone.height) * upright.rows).toInt().clamp(zoneTop + 1, upright.rows);
  final mrz = upright.region(cv.Rect(zoneLeft, zoneTop, zoneRight - zoneLeft, zoneBottom - zoneTop)).clone();
  upright.dispose();

  cv.normalize(mrz, mrz, alpha: 0, beta: 255, normType: cv.NORM_MINMAX);
  if (cv.mean(mrz).val1 < _darkMean) cv.bitwiseNOT(mrz, dst: mrz);
  final bordered = cv.copyMakeBorder(
    mrz,
    _borderWidth,
    _borderWidth,
    _borderWidth,
    _borderWidth,
    cv.BORDER_CONSTANT,
    value: cv.Scalar.all(255),
  );
  mrz.dispose();

  try {
    return (pixels: Uint8List.fromList(bordered.data), width: bordered.cols, height: bordered.rows);
  } finally {
    bordered.dispose();
  }
}
