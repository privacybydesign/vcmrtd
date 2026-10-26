import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Where the MRZ lies in an upright crop of the document, as fractions of it.
typedef MrzZone = ({double left, double top, double width, double height});

const _targetHeight = 600;
const _bandHeight = 70;
const _minBandDensity = 0.10;
const _bandCutoff = 0.25;
const _smoothing = 5;
const _zoneLeft = 0.02;
const _zoneWidth = 0.96;

/// Contrast is the grey levels' standard deviation: the lower, the harder
/// CLAHE has to bring out the text.
const _lowContrast = 20;
const _mediumContrast = 35;
const _lowContrastClipLimit = 10.0;
const _mediumContrastClipLimit = 6.0;
const _clipLimit = 3.0;
const _claheTiles = (4, 4);

/// The band is looked for below this share of the crop's height.
const _bandSearchStart = 0.45;
const _bandPad = 0.15;
const _minZoneHeight = 0.08;
const _maxZoneHeight = 0.45;

/// The bounds a merged block of characters keeps to, to be the MRZ.
const _maxBlockArea = 0.40;
const _minBlockArea = 0.05;
const _maxBlockHeight = 0.35;
const _minBlockHeightPixels = 15;
const _minBlockCenterY = 0.4;
const _minBlockAspect = 2.5;
const _minBlockWidth = 0.25;
const _blockBorder = 0.05;
const _blockPadX = 0.08;
const _blockPadY = 0.20;

/// The bottom of the crop, where the MRZ is when it can't be found.
const MrzZone _fallbackZone = (left: _zoneLeft, top: 0.70, width: _zoneWidth, height: 0.28);

/// Finds the MRZ in [gray] (8-bit, one channel) by its dense band of dark
/// characters, first as the densest band of rows, then as a wide contour.
MrzZone detectMrzZone(cv.Mat gray) {
  final scale = _targetHeight / gray.rows;
  final resized = cv.resize(gray, (math.max(1, (gray.cols * scale).toInt()), _targetHeight));
  final (_, stddev) = cv.meanStdDev(resized);
  final contrast = stddev.val1;
  cv.normalize(resized, resized, alpha: 0, beta: 255, normType: cv.NORM_MINMAX, dtype: cv.MatType.CV_8U);
  final clipLimit = switch (contrast) {
    < _lowContrast => _lowContrastClipLimit,
    < _mediumContrast => _mediumContrastClipLimit,
    _ => _clipLimit,
  };
  final equalized = cv.CLAHE(clipLimit, _claheTiles).apply(resized);
  final blurred = cv.gaussianBlur(equalized, (3, 3), 0);

  // Dark text on a bright background, then the vertical edges of its letters.
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (15, 7));
  final blackhat = cv.morphologyEx(blurred, cv.MORPH_BLACKHAT, kernel);
  final gradient = cv.sobel(blackhat, cv.MatType.CV_32F, 1, 0, ksize: -1);
  final edges = cv.convertScaleAbs(gradient);
  cv.normalize(edges, edges, alpha: 0, beta: 255, normType: cv.NORM_MINMAX, dtype: cv.MatType.CV_8U);
  final lines = cv.morphologyEx(edges, cv.MORPH_CLOSE, kernel);
  final (_, thresh) = cv.threshold(lines, 0, 255, cv.THRESH_BINARY | cv.THRESH_OTSU);

  for (final mat in [resized, equalized, blurred, kernel, blackhat, gradient, edges, lines]) {
    mat.dispose();
  }

  try {
    return _densestBand(thresh) ?? _widestContour(thresh) ?? _fallbackZone;
  } finally {
    thresh.dispose();
  }
}

/// The densest band of rows in the bottom half, about an MRZ's height.
MrzZone? _densestBand(cv.Mat thresh) {
  final h = thresh.rows;
  final searchStart = (h * _bandSearchStart).toInt();
  final bottom = thresh.rowRange(searchStart, h);
  final rowSums = cv.reduce(bottom, 1, cv.REDUCE_AVG, dtype: cv.MatType.CV_64F);
  final bh = bottom.rows;
  final density = [for (var y = 0; y < bh; y++) rowSums.at<double>(y, 0) / 255];
  bottom.dispose();
  rowSums.dispose();

  final smoothed = List.generate(bh, (y) {
    var total = 0.0;
    var count = 0;
    for (var yy = math.max(0, y - _smoothing); yy <= math.min(bh - 1, y + _smoothing); yy++) {
      total += density[yy];
      count++;
    }

    return total / count;
  });

  var bestScore = 0.0;
  var bestStart = 0;
  for (var y = 0; y <= bh - _bandHeight; y++) {
    var score = 0.0;
    for (var dy = 0; dy < _bandHeight; dy++) {
      score += smoothed[y + dy];
    }
    score /= _bandHeight;
    if (score > bestScore) {
      bestScore = score;
      bestStart = y;
    }
  }

  if (bestScore < _minBandDensity) return null;

  final (bandTop, bandBottom) = _expandBand(smoothed, bestStart, bestScore * _bandCutoff);
  final pad = ((bandBottom - bandTop) * _bandPad).toInt();
  final top = math.max(0, bandTop + searchStart - pad);
  final bottomRow = math.min(h - 1, bandBottom + searchStart + pad);
  final height = (bottomRow - top) / h;
  if (height < _minZoneHeight || height > _maxZoneHeight) return null;

  return (left: _zoneLeft, top: top / h, width: _zoneWidth, height: height);
}

(int, int) _expandBand(List<double> smoothed, int start, double cutoff) {
  var top = start;
  var bottom = math.min(start + _bandHeight, smoothed.length - 1);
  for (var y = start - 1; y >= 0; y--) {
    if (smoothed[y] < cutoff) break;
    top = y;
  }

  for (var y = start + _bandHeight; y < smoothed.length; y++) {
    if (smoothed[y] < cutoff) break;
    bottom = y;
  }

  return (top, bottom);
}

/// Merges the characters into blocks and takes the lowest wide one.
MrzZone? _widestContour(cv.Mat thresh) {
  final w = thresh.cols;
  final h = thresh.rows;
  var blocks = thresh.clone();
  void apply(cv.Mat Function(cv.Mat src, cv.Mat kernel) op, (int, int) size) {
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, size);
    final next = op(blocks, kernel);
    kernel.dispose();
    blocks.dispose();
    blocks = next;
  }

  apply((src, k) => cv.morphologyEx(src, cv.MORPH_CLOSE, k), (9, 9));
  apply((src, k) => cv.erode(src, k, iterations: 2), (1, 15));
  apply((src, k) => cv.erode(src, k), (5, 1));
  apply((src, k) => cv.morphologyEx(src, cv.MORPH_CLOSE, k), (31, 1));
  apply((src, k) => cv.morphologyEx(src, cv.MORPH_CLOSE, k), (1, 21));
  apply((src, k) => cv.dilate(src, k, iterations: 4), (31, 5));

  final border = (w * _blockBorder).toInt();
  if (border > 0) {
    for (final side in [cv.Rect(0, 0, border, h), cv.Rect(w - border, 0, border, h)]) {
      blocks.region(side).setTo(cv.Scalar.all(0));
    }
  }

  final (contours, hierarchy) = cv.findContours(blocks, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
  blocks.dispose();
  hierarchy.dispose();
  final sorted = contours.toList()..sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

  MrzZone? best;
  var bestCenterY = 0.0;
  for (final contour in sorted) {
    final rect = cv.boundingRect(contour);
    final aspect = rect.width / rect.height;
    final areaShare = rect.width * rect.height / (w * h);
    final centerY = (rect.y + rect.height / 2) / h;
    if (areaShare > _maxBlockArea || rect.height / h > _maxBlockHeight || centerY < _minBlockCenterY) continue;
    final wideBlock = aspect > _minBlockAspect && rect.width / w > _minBlockWidth;
    if (!(wideBlock && rect.height > _minBlockHeightPixels && areaShare > _minBlockArea && centerY > bestCenterY)) {
      continue;
    }

    final padX = (rect.width * _blockPadX).toInt();
    final padY = (rect.height * _blockPadY).toInt();
    final left = math.max(rect.x - padX, 0) / w;
    final top = math.max(rect.y - padY, 0) / h;
    final right = math.min(rect.x + rect.width + padX, w) / w;
    final bottom = math.min(rect.y + rect.height + padY, h) / h;
    best = (left: left, top: top, width: right - left, height: bottom - top);
    bestCenterY = centerY;
  }
  contours.dispose();

  return best;
}
