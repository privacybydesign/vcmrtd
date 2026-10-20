import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

// None of these were measured on a device yet: collect the signals of real
// documents, prints and screens before letting [DocumentMaterial.medium] decide anything.

/// The middle of the photo: the document without its outline or the table around it.
const _inspectedShare = 0.7;

const _tileSize = 256;
const _flatTiles = 6;
const _minTileBrightness = 30;
const _maxTileBrightness = 245;

/// Periods, in pixels of the full-resolution photo, a screen's pixels, their
/// moiré or a halftone screen repeat at. Text and the document's layout repeat slower.
const _minPeriod = 2.5;
const _maxPeriod = 40.0;

/// Frequencies this close to an axis are left out: the document's edges and
/// lines of text pile up there.
const _axisBins = 2;

/// The camera's JPEG works in blocks of 8 by 8 pixels, and its compression shows at their frequencies.
const _jpegBlock = 8;

const _peakBins = 3;
const _innerRingBins = 5;
const _outerRingBins = 15;

const _textureSigma = 1.5;
const _fringeFineSigma = 1.0;
const _fringeCoarseSigma = 8.0;

const _colourSampleWidth = 800;
const _saturationPercentile = 0.95;
const _blackPercentile = 0.01;
const _shineBrightness = 250;
const _shineMaxSaturation = 40;

/// Noise alone scores up to about 3 over 6 tiles (simulated). On a Galaxy at
/// full resolution a real Dutch ID card scored 2.8 to 9.4, the same card on a
/// laptop screen 6.8 to 21.7 - and on a phone screen 2.6 to 5.7: its pixels
/// are too fine to find.
const _patternPeak = 10.0;

/// What the photo looks like it was taken of.
enum DocumentMedium {
  /// None of the signs of a reproduction: not proof of a genuine document.
  physical,

  /// A screen's pixel grid or a print's halftone screen was found.
  reproduction,
}

/// Signals of what a document in a photo is made of. A genuine document is
/// plastic, or paper that is often laminated; a reproduction is a print on
/// plain paper or a picture on a screen.
class DocumentMaterial {
  const DocumentMaterial({
    required this.periodicPeak,
    required this.colourFringing,
    required this.fineTexture,
    required this.saturation,
    required this.blackLevel,
    required this.shine,
    required this.inspectedWidth,
    required this.inspectedHeight,
    required this.tiles,
  });

  /// How far the strongest isolated spike in the spectrum of the flattest
  /// parts stands above its surroundings (a few for no spike, thousands for
  /// a clean pattern): a screen's pixel grid, its moiré or a print's halftone screen.
  final double periodicPeak;

  /// Fine colour variation over fine brightness variation in the flattest
  /// parts: moiré and halftone rosettes are coloured, sensor noise hardly is.
  final double colourFringing;

  /// Fine brightness variation in the flattest parts relative to their
  /// brightness: paper fibres and ink dots; plastic is smooth.
  final double fineTexture;

  /// The 95th percentile saturation, 0 to 1: a print loses colour.
  final double saturation;

  /// The 1st percentile brightness, 0 to 1: a screen's black glows.
  final double blackLevel;

  /// The share of nearly white, colourless pixels: shine off plastic,
  /// laminate or a screen's glass; plain paper is matte.
  final double shine;

  /// The part of the photo inspected, in pixels, and the tiles of it the
  /// patterns were looked for in: fewer tiles, a noisier [periodicPeak].
  final int inspectedWidth;
  final int inspectedHeight;
  final int tiles;

  /// Only [periodicPeak] decides: on a real Dutch ID card the other signals
  /// looked like a print (pale, grainy, matte), so they're only logged until
  /// they're measured on prints too.
  DocumentMedium get medium => periodicPeak >= _patternPeak ? DocumentMedium.reproduction : DocumentMedium.physical;

  /// One line to collect from a device's log: `key=value` pairs, so
  /// photos of real documents and reproductions can be compared.
  @override
  String toString() => [
    'medium=${medium.name}',
    'size=${inspectedWidth}x$inspectedHeight',
    'tiles=$tiles',
    'periodicPeak=${periodicPeak.toStringAsFixed(2)}',
    'colourFringing=${colourFringing.toStringAsFixed(3)}',
    'fineTexture=${fineTexture.toStringAsFixed(4)}',
    'saturation=${saturation.toStringAsFixed(3)}',
    'blackLevel=${blackLevel.toStringAsFixed(3)}',
    'shine=${shine.toStringAsFixed(4)}',
  ].join(' ');
}

/// Inspects [photo]: the full-resolution, upright photo of the document,
/// before it's scaled down or compressed - both wipe out the fine patterns
/// this looks for.
DocumentMaterial inspectDocumentMaterial(img.Image photo) {
  final bgr = _toMat(photo);
  final inner = bgr.region(
    cv.Rect(
      (bgr.cols * (1 - _inspectedShare) / 2).round(),
      (bgr.rows * (1 - _inspectedShare) / 2).round(),
      (bgr.cols * _inspectedShare).round(),
      (bgr.rows * _inspectedShare).round(),
    ),
  );
  try {
    return inspectDocumentMat(inner);
  } finally {
    inner.dispose();
    bgr.dispose();
  }
}

/// [inspectDocumentMaterial] on an 8-bit BGR [document], all of it inspected.
DocumentMaterial inspectDocumentMat(cv.Mat document) {
  if (document.rows < _tileSize || document.cols < _tileSize) {
    throw ArgumentError('a ${document.cols}x${document.rows} document is too small to inspect');
  }
  final gray = cv.cvtColor(document, cv.COLOR_BGR2GRAY);
  final ycrcb = cv.cvtColor(document, cv.COLOR_BGR2YCrCb);
  final tiles = _flattestTiles(gray);
  try {
    final colour = _colourSignals(document);
    return DocumentMaterial(
      periodicPeak: _periodicPeak(gray, tiles),
      colourFringing: _median([for (final tile in tiles) _onRegion(ycrcb, tile, _colourFringing)]),
      fineTexture: _median([for (final tile in tiles) _onRegion(gray, tile, _fineTexture)]),
      saturation: colour.saturation,
      blackLevel: colour.blackLevel,
      shine: colour.shine,
      inspectedWidth: document.cols,
      inspectedHeight: document.rows,
      tiles: tiles.length,
    );
  } finally {
    gray.dispose();
    ycrcb.dispose();
  }
}

/// [inspect] on the [rect] of [mat], a view released as soon as it's inspected.
T _onRegion<T>(cv.Mat mat, cv.Rect rect, T Function(cv.Mat region) inspect) {
  final region = mat.region(rect);
  try {
    return inspect(region);
  } finally {
    region.dispose();
  }
}

/// Copies the photo's pixels once and lets OpenCV turn them to BGR: a
/// full-resolution photo is tens of megabytes.
cv.Mat _toMat(img.Image photo) {
  final rgb = photo.numChannels == 3 && photo.bitsPerChannel == 8 && photo.format == img.Format.uint8
      ? photo
      : photo.convert(numChannels: 3, format: img.Format.uint8);
  final mat = cv.Mat.create(rows: rgb.height, cols: rgb.width, type: cv.MatType.CV_8UC3);
  final bytes = rgb.toUint8List();
  final rowBytes = rgb.width * 3;
  final data = mat.data;
  if (rgb.rowStride == rowBytes) {
    data.setAll(0, bytes);
  } else {
    for (var y = 0; y < rgb.height; y++) {
      data.setRange(y * rowBytes, (y + 1) * rowBytes, bytes, y * rgb.rowStride);
    }
  }
  cv.cvtColor(mat, cv.COLOR_RGB2BGR, dst: mat);
  return mat;
}

/// Tiles with the least detail: the raster of a screen or print is
/// everywhere, a genuine document's print isn't.
List<cv.Rect> _flattestTiles(cv.Mat gray) {
  const size = _tileSize;
  final laplacian = cv.laplacian(gray, cv.MatType.CV_16S);
  final candidates = <(double, cv.Rect)>[];
  for (var y = 0; y + size <= gray.rows; y += size) {
    for (var x = 0; x + size <= gray.cols; x += size) {
      final rect = cv.Rect(x, y, size, size);
      final brightness = _onRegion(gray, rect, (tile) => cv.mean(tile).val1);
      if (brightness < _minTileBrightness || brightness > _maxTileBrightness) continue;
      final (_, detail) = _onRegion(laplacian, rect, cv.meanStdDev);
      candidates.add((detail.val1, rect));
    }
  }
  laplacian.dispose();
  candidates.sort((a, b) => a.$1.compareTo(b.$1));
  final flattest = [for (final (_, rect) in candidates.take(_flatTiles)) rect];
  return flattest.isEmpty ? [cv.Rect(0, 0, size, size)] : flattest;
}

/// Over the tiles' averaged power spectrum, so noise evens out and a
/// pattern that's in every tile stands out.
double _periodicPeak(cv.Mat gray, List<cv.Rect> tiles) {
  final n = tiles.first.width;
  final window = _hann(n);
  final power = cv.Mat.zeros(n, n, cv.MatType.CV_32FC1);
  for (final tile in tiles) {
    final tilePower = _onRegion(gray, tile, (region) => _power(region, window));
    cv.add(power, tilePower, dst: power);
    tilePower.dispose();
  }

  final peak = cv.boxFilter(power, -1, (_peakBins, _peakBins), normalize: false);
  final inner = cv.boxFilter(power, -1, (_innerRingBins, _innerRingBins), normalize: false);
  final outer = cv.boxFilter(power, -1, (_outerRingBins, _outerRingBins), normalize: false);
  final peaks = _floats(peak);
  final inners = _floats(inner);
  final outers = _floats(outer);
  const ringBins = _outerRingBins * _outerRingBins - _innerRingBins * _innerRingBins;

  final minRadius = n / _maxPeriod;
  final maxRadius = n / _minPeriod;
  final block = n / _jpegBlock;
  bool nearBlockFrequency(int f) => (f.abs() + _peakBins ~/ 2) % block <= 2 * (_peakBins ~/ 2);
  var best = 0.0;
  // A real image's spectrum is symmetric: half of it says everything.
  for (var v = _axisBins + 1; v <= n ~/ 2; v++) {
    for (var x = 0; x < n; x++) {
      final u = x <= n ~/ 2 ? x : x - n;
      if (u.abs() <= _axisBins) continue;
      final radius = math.sqrt(u * u + v * v);
      if (radius < minRadius || radius > maxRadius) continue;
      if (nearBlockFrequency(u) && nearBlockFrequency(v)) continue;
      final i = v * n + x;
      final ring = (outers[i] - inners[i]) / ringBins;
      if (ring <= 0) continue;
      best = math.max(best, peaks[i] / (_peakBins * _peakBins) / ring);
    }
  }

  for (final mat in [power, peak, inner, outer]) {
    mat.dispose();
  }
  return best;
}

cv.Mat _power(cv.Mat tile, Float64List window) {
  final n = tile.rows;
  final samples = tile.convertTo(cv.MatType.CV_32FC1);
  final values = _floats(samples);
  final mean = cv.mean(samples).val1;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      values[y * n + x] = (values[y * n + x] - mean) * window[y] * window[x];
    }
  }

  final spectrum = cv.dft(samples, flags: cv.DFT_COMPLEX_OUTPUT);
  final parts = cv.split(spectrum);
  final amplitude = cv.magnitude(parts[0], parts[1]);
  final power = cv.multiply(amplitude, amplitude);
  for (final mat in [samples, spectrum, amplitude]) {
    mat.dispose();
  }
  parts.dispose();
  return power;
}

Float64List _hann(int n) =>
    Float64List.fromList([for (var i = 0; i < n; i++) 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))]);

/// A view on a continuous one-channel float [mat]'s values.
Float32List _floats(cv.Mat mat) {
  final data = mat.data;
  return data.buffer.asFloat32List(data.offsetInBytes, mat.total);
}

double _fineTexture(cv.Mat tile) {
  final samples = tile.convertTo(cv.MatType.CV_32FC1);
  final smooth = cv.gaussianBlur(samples, (0, 0), _textureSigma);
  final fine = cv.subtract(samples, smooth);
  final (_, deviation) = cv.meanStdDev(fine);
  final brightness = cv.mean(samples).val1;
  for (final mat in [samples, smooth, fine]) {
    mat.dispose();
  }
  return brightness <= 0 ? 0 : deviation.val1 / brightness;
}

double _colourFringing(cv.Mat tile) {
  final samples = tile.convertTo(cv.MatType.CV_32FC3);
  final fine = cv.gaussianBlur(samples, (0, 0), _fringeFineSigma);
  final coarse = cv.gaussianBlur(samples, (0, 0), _fringeCoarseSigma);
  final band = cv.subtract(fine, coarse);
  final (_, deviation) = cv.meanStdDev(band);
  for (final mat in [samples, fine, coarse, band]) {
    mat.dispose();
  }
  final luma = deviation.val1;
  final chroma = math.sqrt(deviation.val2 * deviation.val2 + deviation.val3 * deviation.val3);
  return luma <= 0 ? 0 : chroma / luma;
}

({double saturation, double blackLevel, double shine}) _colourSignals(cv.Mat document) {
  final scale = math.min(1.0, _colourSampleWidth / document.cols);
  final small = cv.resize(document, (
    math.max(1, (document.cols * scale).round()),
    math.max(1, (document.rows * scale).round()),
  ), interpolation: cv.INTER_AREA);
  final hsv = cv.cvtColor(small, cv.COLOR_BGR2HSV);
  small.dispose();
  final pixels = hsv.data;
  final saturations = List.filled(256, 0);
  final values = List.filled(256, 0);
  var shining = 0;
  for (var i = 0; i < pixels.length; i += 3) {
    final s = pixels[i + 1];
    final v = pixels[i + 2];
    saturations[s]++;
    values[v]++;
    if (v >= _shineBrightness && s <= _shineMaxSaturation) shining++;
  }
  final count = pixels.length ~/ 3;
  final result = (
    saturation: _percentile(saturations, count, _saturationPercentile) / 255,
    blackLevel: _percentile(values, count, _blackPercentile) / 255,
    shine: shining / count,
  );
  hsv.dispose();
  return result;
}

int _percentile(List<int> histogram, int count, double share) {
  final below = math.min(count - 1, (count * share).floor());
  var seen = 0;
  for (var b = 0; b < histogram.length; b++) {
    seen += histogram[b];
    if (seen > below) return b;
  }
  return histogram.length - 1;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}
