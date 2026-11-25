import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Text lines need less detail than reading them.
const _skewHeight = 300;
const _coarseStep = 3.0;
const _fineSpan = 1.5;
const _fineStep = 0.5;

/// How much more a tilt must line the text up than the nearest quarter turn
/// before it counts: on specimen documents a real tilt scored at least 1.5
/// times as much, a level one at most 1.1.
const _minGain = 1.3;

/// [image]'s brightness, 8-bit and one channel.
cv.Mat greyMat(img.Image image) {
  final rgb = image.numChannels == 3 ? image : image.convert(numChannels: 3);
  final colour = cv.Mat.create(rows: rgb.height, cols: rgb.width, type: cv.MatType.CV_8UC3);
  colour.data.setAll(0, rgb.getBytes(order: img.ChannelOrder.rgb));
  try {
    return cv.cvtColor(colour, cv.COLOR_RGB2GRAY);
  } finally {
    colour.dispose();
  }
}

/// How far the lines of text in [grey] are tilted off the nearest quarter
/// turn, in degrees from -45 to 45, as [cv.getRotationMatrix2D] takes them:
/// rotating by it levels them, or stands them straight up. At the right
/// angle every line falls on its own rows, so the row sums of a text mask
/// alternate between full and empty and their variance peaks. 0 when no
/// angle lines them up clearly better than the quarter turn (nothing to read,
/// or level already). Text lines look the same half a turn round, so it says
/// nothing about upside down. Ported from irmamobile's F-Droid MRZ scanner.
double textSkew(cv.Mat grey) {
  final width = (grey.cols * _skewHeight / grey.rows).round().clamp(1, 1 << 16);
  final small = cv.resize(grey, (width, _skewHeight), interpolation: cv.INTER_AREA);
  cv.normalize(small, small, alpha: 0, beta: 255, normType: cv.NORM_MINMAX, dtype: cv.MatType.CV_8U);
  final blurred = cv.gaussianBlur(small, (3, 3), 0);
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (9, 5));
  final blackhat = cv.morphologyEx(blurred, cv.MORPH_BLACKHAT, kernel);
  final (_, mask) = cv.threshold(blackhat, 0, 255, cv.THRESH_BINARY | cv.THRESH_OTSU);
  for (final mat in [small, blurred, kernel, blackhat]) {
    mat.dispose();
  }

  try {
    var best = 0.0;
    var bestScore = -1.0;
    void score(double angle) {
      final variance = _rowVariance(mask, angle);
      if (variance > bestScore) {
        bestScore = variance;
        best = angle;
      }
    }

    for (var angle = -90.0; angle < 90; angle += _coarseStep) {
      score(angle);
    }
    final coarse = best;
    for (var angle = coarse - _fineSpan; angle <= coarse + _fineSpan; angle += _fineStep) {
      score(angle);
    }

    // The photo is read in every quarter turn anyway.
    final quarter = (best / 90).round() * 90.0;
    return bestScore >= _minGain * _rowVariance(mask, quarter) ? best - quarter : 0;
  } finally {
    mask.dispose();
  }
}

/// [grey] rotated by [skew] (see [textSkew]) onto a canvas large enough to
/// keep its corners, the edge pixels repeated into the new ones.
cv.Mat levelled(cv.Mat grey, double skew) {
  final rotation = cv.getRotationMatrix2D(cv.Point2f(grey.cols / 2, grey.rows / 2), skew, 1);
  final cos = rotation.at<double>(0, 0).abs();
  final sin = rotation.at<double>(0, 1).abs();
  final width = (grey.rows * sin + grey.cols * cos).round();
  final height = (grey.rows * cos + grey.cols * sin).round();
  rotation.set<double>(0, 2, rotation.at<double>(0, 2) + (width - grey.cols) / 2);
  rotation.set<double>(1, 2, rotation.at<double>(1, 2) + (height - grey.rows) / 2);
  try {
    return cv.warpAffine(grey, rotation, (width, height), borderMode: cv.BORDER_REPLICATE);
  } finally {
    rotation.dispose();
  }
}

double _rowVariance(cv.Mat mask, double angle) {
  final rotation = cv.getRotationMatrix2D(cv.Point2f(mask.cols / 2, mask.rows / 2), angle, 1);
  final rotated = cv.warpAffine(
    mask,
    rotation,
    (mask.cols, mask.rows),
    flags: cv.INTER_NEAREST,
    borderValue: cv.Scalar.all(0),
  );
  final rowSums = cv.reduce(rotated, 1, cv.REDUCE_SUM, dtype: cv.MatType.CV_64F);
  final (_, stddev) = cv.meanStdDev(rowSums);
  for (final mat in [rotation, rotated, rowSums]) {
    mat.dispose();
  }

  return stddev.val1 * stddev.val1;
}
