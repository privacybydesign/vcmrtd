import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:mrz_capture/mrz_capture.dart';

// Only the glare thresholds were measured on a device; the rest are starting points.

enum DocumentPhotoIssue { noDocument, tooDark, glare, reflection, tilted, blurry, unreadable }

/// In the order their hints are shown.
const _documentChecks = [
  DocumentPhotoIssue.glare,
  DocumentPhotoIssue.reflection,
  DocumentPhotoIssue.tilted,
  DocumentPhotoIssue.blurry,
  DocumentPhotoIssue.unreadable,
];

const _minReadableLines = 3;

/// Fractions of the frame's size. [_edgeSearchOutside] stays below
/// [DocumentPicture.frameMargin] so the document is whole in the photo.
const _edgeSearchOutside = 0.06;
const _edgeSearchInside = 0.2;
const _edgeSearchFar = 0.2;
const _edgeProfiles = 12;
const _edgeSpan = 0.8;

const _minEdgeStep = 12;
const _maxFlatRange = 24;
const _maxFlatShare = 0.6;
const _edgeWindow = 6;
const _edgeGap = 3;
const _minEdgeInliers = 0.5;
const _edgeTolerance = 3.0;
const _maxEdgeSlope = 0.25;
const _maxShapeError = 0.1;
const _documentInset = 0.03;

const _clippedBrightness = 250;
const _glareColumns = 16;
const _glareRows = 10;

/// Measured on a Galaxy S9: clean tiles had no clipped pixels, tiles with a
/// reflection 21% to 57%.
const _glareTileShare = 0.05;

/// For reflections that don't clip (iPhones keep highlights).
const _nearClippedBrightness = 240;
const _reflectionContrast = 15;

/// Loose enough for the slight tilt the glare hint asks for.
const _maxConvergenceDegrees = 8.0;

const _tileColumns = 8;
const _tileRows = 5;
const _minSharpness = 60.0;

const _tooDarkPaperBrightness = 60;
const _paperPercentile = 0.9;

const _sampleWidth = 640;

const _brightnessLevels = 256;

/// ITU-R BT.601 luma weights for blue, green and red, scaled to 256.
const _lumaBlue = 29;
const _lumaGreen = 150;
const _lumaRed = 77;

const _bgraBytesPerPixel = 4;

class LumaFrame {
  /// Android's YUV420/NV21: the first plane is brightness.
  const LumaFrame.luma({required this.bytes, required this.width, required this.height, required this.bytesPerRow})
    : isBgra = false;

  const LumaFrame.bgra({required this.bytes, required this.width, required this.height, required this.bytesPerRow})
    : isBgra = true;

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool isBgra;

  int brightnessAt(int x, int y) {
    if (!isBgra) return bytes[y * bytesPerRow + x];
    final i = y * bytesPerRow + x * _bgraBytesPerPixel;
    return (bytes[i] * _lumaBlue + bytes[i + 1] * _lumaGreen + bytes[i + 2] * _lumaRed) >> 8;
  }
}

class DocumentSample {
  const DocumentSample(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;

  DocumentSample crop(Rect area) {
    final left = area.left.round().clamp(0, width);
    final top = area.top.round().clamp(0, height);
    final w = (area.right.round().clamp(0, width) - left).clamp(0, width);
    final h = (area.bottom.round().clamp(0, height) - top).clamp(0, height);
    final cropped = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      cropped.setRange(y * w, (y + 1) * w, pixels, (top + y) * width + left);
    }

    return DocumentSample(cropped, w, h);
  }
}

/// [rotation] turns the frame upright (clockwise degrees); [region] is in
/// fractions of the upright frame. Each pixel averages up to 3x3 frame pixels
/// so sensor noise doesn't pass for sharpness.
DocumentSample sampleDocument(
  LumaFrame frame, {
  required int rotation,
  required Rect region,
  int maxWidth = _sampleWidth,
}) {
  final sideways = rotation % 180 != 0;
  final uprightWidth = sideways ? frame.height : frame.width;
  final uprightHeight = sideways ? frame.width : frame.height;
  final left = region.left * uprightWidth;
  final top = region.top * uprightHeight;
  final regionWidth = region.width * uprightWidth;
  final regionHeight = region.height * uprightHeight;

  final width = regionWidth.round().clamp(1, maxWidth);
  final step = regionWidth / width;
  final height = (regionHeight / step).round().clamp(1, 1 << 16);
  final taps = step.floor().clamp(1, 3);
  final columns = _tapPositions(width, taps, left, step, uprightWidth);
  final rows = _tapPositions(height, taps, top, step, uprightHeight);
  final brightnessAt = _uprightBrightness(frame, rotation);
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      pixels[y * width + x] = _average(brightnessAt, columns, rows, x, y, taps);
    }
  }

  return DocumentSample(pixels, width, height);
}

Int32List _tapPositions(int count, int taps, double origin, double step, int size) => Int32List.fromList([
  for (var i = 0; i < count; i++)
    for (var t = 0; t < taps; t++) (origin + (i + (t + 0.5) / taps) * step).floor().clamp(0, size - 1),
]);

int Function(int x, int y) _uprightBrightness(LumaFrame frame, int rotation) => switch (rotation) {
  90 => (x, y) => frame.brightnessAt(y, frame.height - 1 - x),
  180 => (x, y) => frame.brightnessAt(frame.width - 1 - x, frame.height - 1 - y),
  270 => (x, y) => frame.brightnessAt(frame.width - 1 - y, x),
  _ => frame.brightnessAt,
};

int _average(int Function(int x, int y) brightnessAt, Int32List columns, Int32List rows, int x, int y, int taps) {
  var sum = 0;
  for (var ty = 0; ty < taps; ty++) {
    final uy = rows[y * taps + ty];
    for (var tx = 0; tx < taps; tx++) {
      sum += brightnessAt(columns[x * taps + tx], uy);
    }
  }

  return sum ~/ (taps * taps);
}

Set<DocumentPhotoIssue> checkFrame(LumaFrame frame, {required int rotation, required Rect region}) {
  final (sample, inSample) = _sampleFrame(frame, rotation: rotation, region: region);
  return documentPhotoIssues(sample, frame: inSample);
}

(DocumentSample, Rect) _sampleFrame(LumaFrame frame, {required int rotation, required Rect region}) {
  const margin = _edgeSearchFar;
  final sampled = Rect.fromLTRB(
    (region.left - region.width * margin).clamp(0.0, 1.0),
    (region.top - region.height * margin).clamp(0.0, 1.0),
    (region.right + region.width * margin).clamp(0.0, 1.0),
    (region.bottom + region.height * margin).clamp(0.0, 1.0),
  );
  final sample = sampleDocument(frame, rotation: rotation, region: sampled);
  final scaleX = sample.width / sampled.width;
  final scaleY = sample.height / sampled.height;

  return (
    sample,
    Rect.fromLTRB(
      (region.left - sampled.left) * scaleX,
      (region.top - sampled.top) * scaleY,
      (region.right - sampled.left) * scaleX,
      (region.bottom - sampled.top) * scaleY,
    ),
  );
}

Set<DocumentPhotoIssue> documentPhotoIssues(DocumentSample sample, {required Rect frame}) {
  final outline = _findDocument(sample, frame);
  if (outline == null) {
    final inFrame = sample.crop(frame.deflateBy(frame.width * _documentInset, frame.height * _documentInset));
    if (_hasGlare(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.glare};
    if (_hasReflection(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.reflection};
    return {
      _paperBrightness(sample) < _tooDarkPaperBrightness ? DocumentPhotoIssue.tooDark : DocumentPhotoIssue.noDocument,
    };
  }

  final area = outline.area;
  final document = sample.crop(area.deflateBy(area.width * _documentInset, area.height * _documentInset));
  if (_paperBrightness(document) < _tooDarkPaperBrightness) return {DocumentPhotoIssue.tooDark};
  return {
    if (_hasGlare(document)) DocumentPhotoIssue.glare,
    if (_hasReflection(document)) DocumentPhotoIssue.reflection,
    if (outline.tilted) DocumentPhotoIssue.tilted,
    if (_sharpness(document) < _minSharpness) DocumentPhotoIssue.blurry,
  };
}

bool textReadable(List<Rect> lines, Rect region) =>
    lines.where((line) => region.contains(line.center)).length >= _minReadableLines;

/// Adds [DocumentPhotoIssue.unreadable] to the issues of a frame whose text was not readable.
Set<DocumentPhotoIssue> withUnreadable(Set<DocumentPhotoIssue> issues) {
  final noDocument = issues.contains(DocumentPhotoIssue.noDocument) || issues.contains(DocumentPhotoIssue.tooDark);
  return noDocument ? issues : {...issues, DocumentPhotoIssue.unreadable};
}

extension on Rect {
  Rect deflateBy(double dx, double dy) => Rect.fromLTRB(left + dx, top + dy, right - dx, bottom - dy);
}

/// Depth inside the frame's side (negative: outside) = offset + slope * position along it.
typedef _Edge = ({double slope, double offset});

class _DocumentOutline {
  const _DocumentOutline({
    required this.area,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final Rect area;
  final _Edge? top;
  final _Edge? bottom;
  final _Edge? left;
  final _Edge? right;

  bool get tilted {
    // Opposite sides measure depth from opposite directions: parallel edges have opposite slopes.
    double degrees(_Edge edge) => math.atan(edge.slope) * 180 / math.pi;
    bool converge(_Edge? a, _Edge? b) =>
        a != null && b != null && (degrees(a) + degrees(b)).abs() > _maxConvergenceDegrees;
    return converge(top, bottom) || converge(right, left);
  }
}

enum _Side { top, bottom, left, right }

/// One edge may be missing (a passport's fold); it's then placed by the frame's aspect ratio.
_DocumentOutline? _findDocument(DocumentSample sample, Rect frame) {
  final edges = {for (final side in _Side.values) side: _findEdge(sample, frame, side)};
  final found = _outline(edges, frame);
  if (found != null || edges.values.any((edge) => edge == null)) return found;
  // Wrong shape: one edge may be print or a fold, so try three.
  for (final side in _Side.values) {
    final outline = _outline({...edges, side: null}, frame);
    if (outline != null) return outline;
  }

  return null;
}

_DocumentOutline? _outline(Map<_Side, _Edge?> edges, Rect frame) {
  if (edges.values.where((edge) => edge == null).length > 1) return null;

  double? middle(_Side side) {
    final edge = edges[side];
    if (edge == null) return null;
    final along = side == _Side.top || side == _Side.bottom ? frame.center.dx : frame.center.dy;
    final depth = edge.offset + edge.slope * along;
    return switch (side) {
      _Side.top => frame.top + depth,
      _Side.bottom => frame.bottom - depth,
      _Side.left => frame.left + depth,
      _Side.right => frame.right - depth,
    };
  }

  final ratio = frame.width / frame.height;
  var top = middle(_Side.top);
  var bottom = middle(_Side.bottom);
  var left = middle(_Side.left);
  var right = middle(_Side.right);
  top ??= bottom! - (right! - left!) / ratio;
  bottom ??= top + (right! - left!) / ratio;
  left ??= right! - (bottom - top) * ratio;
  right ??= left + (bottom - top) * ratio;

  bool along(double position, double side, double size) =>
      position - side >= -size * _edgeSearchInside && position - side <= size * _edgeSearchOutside;
  final inFrame =
      along(-top, -frame.top, frame.height) &&
      along(bottom, frame.bottom, frame.height) &&
      along(-left, -frame.left, frame.width) &&
      along(right, frame.right, frame.width);
  if (!inFrame) return null;
  if (edges.values.every((edge) => edge != null) &&
      (((right - left) / (bottom - top)) / ratio - 1).abs() > _maxShapeError) {
    return null;
  }

  return _DocumentOutline(
    area: Rect.fromLTRB(left, top, right, bottom),
    top: edges[_Side.top],
    bottom: edges[_Side.bottom],
    left: edges[_Side.left],
    right: edges[_Side.right],
  );
}

_Edge? _findEdge(DocumentSample sample, Rect frame, _Side side) {
  final horizontal = side == _Side.top || side == _Side.bottom;
  final length = horizontal ? frame.width : frame.height;
  final across = horizontal ? frame.height : frame.width;
  final start = (horizontal ? frame.left : frame.top) + length * (1 - _edgeSpan) / 2;
  final outside = (across * _edgeSearchFar).round();
  final inside = (across * _edgeSearchInside).round();
  const reach = _edgeGap + _edgeWindow;

  final strip = length * _edgeSpan / _edgeProfiles;
  final centre = start + length * _edgeSpan / 2;
  final points = <_EdgePoint>[];
  for (var p = 0; p < _edgeProfiles; p++) {
    final from = (start + strip * p).round();
    final to = math.max(from + 1, (start + strip * (p + 1)).round());
    final along = (from + to) ~/ 2;
    final profile = [
      for (var depth = -outside - reach; depth <= inside + reach; depth++)
        _stripBrightness(sample, frame, side, from, to, depth),
    ];
    final steps = _steps(profile, outside, inside);
    for (var j = 0; j < steps.length; j++) {
      if (_isEdge(steps, profile, j)) {
        points.add((profile: p, along: along - centre, depth: (j - outside).toDouble(), rising: steps[j] > 0));
      }
    }
  }

  final edge = _fitEdge(points);
  return edge == null ? null : (slope: edge.slope, offset: edge.offset - edge.slope * centre);
}

int _stripBrightness(DocumentSample sample, Rect frame, _Side side, int from, int to, int depth) {
  var sum = 0;
  for (var a = from; a < to; a++) {
    final (x, y) = switch (side) {
      _Side.top => (a, frame.top.round() + depth),
      _Side.bottom => (a, frame.bottom.round() - 1 - depth),
      _Side.left => (frame.left.round() + depth, a),
      _Side.right => (frame.right.round() - 1 - depth, a),
    };
    sum += sample.pixels[y.clamp(0, sample.height - 1) * sample.width + x.clamp(0, sample.width - 1)];
  }

  return sum ~/ (to - from);
}

List<double> _steps(List<int> profile, int outside, int inside) {
  const reach = _edgeGap + _edgeWindow;
  final sums = List.filled(profile.length + 1, 0);
  for (var i = 0; i < profile.length; i++) {
    sums[i + 1] = sums[i] + profile[i];
  }

  int sum(int from, int to) => sums[to] - sums[from];
  return [
    for (var d = -outside; d <= inside; d++)
      (sum(d + outside + reach + _edgeGap, d + outside + 2 * reach) -
              sum(d + outside, d + outside + reach - _edgeGap)) /
          _edgeWindow,
  ];
}

bool _isEdge(List<double> steps, List<int> profile, int j) {
  final step = steps[j].abs();
  if (step < _minEdgeStep || !_isPeak(steps, j)) return false;
  final out = profile.sublist(j, j + _edgeWindow);
  return out.reduce(math.max) - out.reduce(math.min) <= math.max(_maxFlatRange, step * _maxFlatShare);
}

bool _isPeak(List<double> steps, int j) {
  final step = steps[j].abs();
  for (var k = math.max(0, j - _edgeGap); k <= math.min(steps.length - 1, j + _edgeGap); k++) {
    final other = steps[k].abs();
    if (other > step || (other == step && k < j)) return false;
  }

  return true;
}

typedef _EdgePoint = ({int profile, double along, double depth, bool rising});

typedef _Line = ({double slope, double offset, int support});

int _support(List<_EdgePoint> points) => points.map((point) => point.profile).toSet().length;

/// The outermost line most strips agree on, refitted by least squares.
_Edge? _fitEdge(List<_EdgePoint> points) {
  final needed = (_edgeProfiles * _minEdgeInliers).ceil();
  _Line? best;
  for (final rising in [true, false]) {
    final candidates = [
      for (final point in points)
        if (point.rising == rising) point,
    ];
    if (_support(candidates) < needed) continue;
    for (var s = -_maxEdgeSlope; s <= _maxEdgeSlope + 1e-9; s += 0.01) {
      best = _outermostLine(candidates, s, needed, best);
    }
  }

  if (best == null) return null;
  return _refit(points, (slope: best.slope, offset: best.offset), needed);
}

_Line? _outermostLine(List<_EdgePoint> candidates, double slope, int needed, _Line? best) {
  final offsets = [for (final point in candidates) (point.depth - slope * point.along, point.profile)]
    ..sort((a, b) => a.$1.compareTo(b.$1));
  var from = 0;
  for (var to = 0; to < offsets.length; to++) {
    while (offsets[to].$1 - offsets[from].$1 > 2 * _edgeTolerance) {
      from++;
    }
    final profiles = {for (var i = from; i <= to; i++) offsets[i].$2}.length;
    final offset = (offsets[from].$1 + offsets[to].$1) / 2;
    if (profiles >= needed && _beats(offset, profiles, best)) best = (slope: slope, offset: offset, support: profiles);
  }

  return best;
}

bool _beats(double offset, int support, _Line? best) =>
    best == null ||
    offset < best.offset - 2 * _edgeTolerance ||
    (offset <= best.offset + 2 * _edgeTolerance && support > best.support);

_Edge? _refit(List<_EdgePoint> points, _Edge edge, int needed) {
  var fit = edge;
  for (var pass = 0; pass < 2; pass++) {
    final line = fit;
    final inliers = [
      for (final point in points)
        if ((point.depth - (line.offset + line.slope * point.along)).abs() <= _edgeTolerance) point,
    ];
    if (_support(inliers) < needed) return pass == 0 ? null : line;
    fit = _leastSquares(inliers);
  }

  return fit;
}

_Edge _leastSquares(List<_EdgePoint> points) {
  final n = points.length;
  final meanA = points.map((p) => p.along).reduce((a, b) => a + b) / n;
  final meanD = points.map((p) => p.depth).reduce((a, b) => a + b) / n;
  var covariance = 0.0;
  var variance = 0.0;
  for (final point in points) {
    covariance += (point.along - meanA) * (point.depth - meanD);
    variance += (point.along - meanA) * (point.along - meanA);
  }
  final slope = variance == 0 ? 0.0 : (covariance / variance).clamp(-_maxEdgeSlope, _maxEdgeSlope);

  return (slope: slope, offset: meanD - slope * meanA);
}

class DocumentFrameChecker {
  DocumentFrameChecker._(this._isolate, this._replies, this._requests);

  final Isolate _isolate;
  final ReceivePort _replies;
  final SendPort _requests;
  final _pending = Queue<Completer<Set<DocumentPhotoIssue>>>();

  /// Like the MRZ scanner's OCR, frames that arrive while one is checked are skipped.
  bool get busy => _pending.isNotEmpty;

  static Future<DocumentFrameChecker> start() async {
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_serve, replies.sendPort);
    final ready = Completer<SendPort>();
    late final DocumentFrameChecker checker;
    replies.listen((reply) {
      if (reply is SendPort) return ready.complete(reply);
      final pending = checker._pending.removeFirst();
      if (reply is Set<DocumentPhotoIssue>) {
        pending.complete(reply);
      } else {
        pending.completeError(StateError('$reply'));
      }
    });
    return checker = DocumentFrameChecker._(isolate, replies, await ready.future);
  }

  Future<Set<DocumentPhotoIssue>> check(LumaFrame frame, {required int rotation, required Rect region}) {
    final pending = Completer<Set<DocumentPhotoIssue>>();
    _pending.add(pending);
    _requests.send((
      bytes: TransferableTypedData.fromList([frame.bytes]),
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      bgra: frame.isBgra,
      rotation: rotation,
      region: (region.left, region.top, region.right, region.bottom),
    ));

    return pending.future;
  }

  void close() {
    _replies.close();
    _isolate.kill(priority: Isolate.immediate);
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(StateError('closed'));
    }
  }

  static void _serve(SendPort replies) {
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((request) {
      try {
        final r = request as _FrameRequest;
        final bytes = r.bytes.materialize().asUint8List();
        final frame = r.bgra
            ? LumaFrame.bgra(bytes: bytes, width: r.width, height: r.height, bytesPerRow: r.bytesPerRow)
            : LumaFrame.luma(bytes: bytes, width: r.width, height: r.height, bytesPerRow: r.bytesPerRow);
        replies.send(
          checkFrame(
            frame,
            rotation: r.rotation,
            region: Rect.fromLTRB(r.region.$1, r.region.$2, r.region.$3, r.region.$4),
          ),
        );
      } catch (e) {
        replies.send('$e');
      }
    });
  }
}

typedef _FrameRequest = ({
  TransferableTypedData bytes,
  int width,
  int height,
  int bytesPerRow,
  bool bgra,
  int rotation,
  (double, double, double, double) region,
});

int _paperBrightness(DocumentSample sample) {
  if (sample.pixels.isEmpty) return 0;
  final histogram = List.filled(_brightnessLevels, 0);
  for (final p in sample.pixels) {
    histogram[p]++;
  }

  final below = (sample.pixels.length * _paperPercentile).floor();
  var seen = 0;
  for (var b = 0; b < _brightnessLevels; b++) {
    seen += histogram[b];
    if (seen > below) return b;
  }

  return _brightnessLevels - 1;
}

List<List<int>> _tileHistograms(DocumentSample document) {
  final columns = math.max(1, math.min(_glareColumns, document.width));
  final rows = math.max(1, math.min(_glareRows, document.height));
  final histograms = List.generate(columns * rows, (_) => List.filled(_brightnessLevels, 0));
  for (var y = 0; y < document.height; y++) {
    final row = y * rows ~/ document.height * columns;
    final offset = y * document.width;
    for (var x = 0; x < document.width; x++) {
      histograms[row + x * columns ~/ document.width][document.pixels[offset + x]]++;
    }
  }

  return [
    for (final histogram in histograms)
      if (histogram.any((count) => count > 0)) histogram,
  ];
}

int _percentile(List<int> histogram, double share) {
  final count = histogram.reduce((a, b) => a + b);
  final below = math.min(count - 1, (count * share).floor());
  var seen = 0;
  for (var b = 0; b < _brightnessLevels; b++) {
    seen += histogram[b];
    if (seen > below) return b;
  }

  return _brightnessLevels - 1;
}

bool _glaring(List<int> histogram, [int brightness = _clippedBrightness]) {
  var bright = 0;
  for (var b = brightness; b < _brightnessLevels; b++) {
    bright += histogram[b];
  }

  return bright / histogram.reduce((a, b) => a + b) > _glareTileShare;
}

bool _hasGlare(DocumentSample document) => _tileHistograms(document).any(_glaring);

bool _hasReflection(DocumentSample document) {
  final histograms = _tileHistograms(document);
  if (histograms.isEmpty) return false;
  final papers = [for (final histogram in histograms) _percentile(histogram, _paperPercentile)]..sort();
  if (papers[papers.length ~/ 2] > _nearClippedBrightness - _reflectionContrast) return false;
  return histograms.any((histogram) => !_glaring(histogram) && _glaring(histogram, _nearClippedBrightness));
}

/// Laplacian variance over the sharpest quarter of tiles. Pixels next to
/// clipped ones are skipped: a reflection's edge says nothing about focus.
double _sharpness(DocumentSample sample) {
  final w = sample.width;
  final h = sample.height;
  if (w < 3 || h < 3) return 0;
  final columns = _tileColumns.clamp(1, w - 2);
  final rows = _tileRows.clamp(1, h - 2);
  final sums = List.filled(columns * rows, 0.0);
  final sumsOfSquares = List.filled(columns * rows, 0.0);
  final counts = List.filled(columns * rows, 0);
  final p = sample.pixels;
  for (var y = 1; y < h - 1; y++) {
    final row = (y - 1) * rows ~/ (h - 2);
    for (var x = 1; x < w - 1; x++) {
      final tile = row * columns + (x - 1) * columns ~/ (w - 2);
      final i = y * w + x;
      if (math.max(math.max(p[i], math.max(p[i - 1], p[i + 1])), math.max(p[i - w], p[i + w])) >= _clippedBrightness) {
        continue;
      }

      final laplacian = p[i - w] + p[i + w] + p[i - 1] + p[i + 1] - 4 * p[i];
      sums[tile] += laplacian;
      sumsOfSquares[tile] += laplacian * laplacian;
      counts[tile]++;
    }
  }

  final variances = [
    for (var t = 0; t < counts.length; t++)
      if (counts[t] > 0) sumsOfSquares[t] / counts[t] - (sums[t] / counts[t]) * (sums[t] / counts[t]),
  ]..sort((a, b) => b.compareTo(a));
  if (variances.isEmpty) return double.infinity;
  final sharpest = variances.take(math.max(1, variances.length ~/ 4));
  return sharpest.reduce((a, b) => a + b) / sharpest.length;
}

/// Each check settles once [framesToAgree] of the last [windowFrames] frames
/// agree, so the hint doesn't flicker.
class DocumentPhotoQuality {
  static const windowFrames = 9;
  static const framesToAgree = 6;

  /// Null for frames with a document.
  final _presence = <DocumentPhotoIssue?>[];
  var _documentFound = false;
  DocumentPhotoIssue? _absence;

  final _results = {for (final check in _documentChecks) check: <bool>[]};
  final _failing = <DocumentPhotoIssue>{};

  DocumentPhotoIssue? get issue {
    if (!_documentFound) return _absence;
    for (final check in _documentChecks) {
      if (_failing.contains(check)) return check;
    }
    return null;
  }

  bool get clear =>
      _documentFound &&
      _failing.isEmpty &&
      _documentChecks.every((check) => _results[check]!.where((failed) => !failed).length >= framesToAgree);

  /// Returns whether [issue] or [clear] changed.
  bool update(Set<DocumentPhotoIssue> frameIssues) {
    final before = (issue, clear);
    final absence = _absenceIn(frameIssues);
    _push(_presence, absence);
    _settlePresence();
    if (absence == null) _settleChecks(frameIssues);

    return before != (issue, clear);
  }

  static DocumentPhotoIssue? _absenceIn(Set<DocumentPhotoIssue> frameIssues) {
    if (frameIssues.contains(DocumentPhotoIssue.tooDark)) return DocumentPhotoIssue.tooDark;
    if (!frameIssues.contains(DocumentPhotoIssue.noDocument)) return null;
    if (frameIssues.contains(DocumentPhotoIssue.glare)) return DocumentPhotoIssue.glare;
    if (frameIssues.contains(DocumentPhotoIssue.reflection)) return DocumentPhotoIssue.reflection;
    return DocumentPhotoIssue.noDocument;
  }

  void _settlePresence() {
    for (final candidate in _presence.toSet()) {
      if (_presence.where((a) => a == candidate).length < framesToAgree) continue;
      final wasFound = _documentFound;
      _documentFound = candidate == null;
      _absence = candidate;
      if (wasFound && !_documentFound) _clearChecks();
    }
  }

  void _settleChecks(Set<DocumentPhotoIssue> frameIssues) {
    for (final check in _documentChecks) {
      final results = _push(_results[check]!, frameIssues.contains(check));
      final failed = results.where((f) => f).length;
      if (failed >= framesToAgree) {
        _failing.add(check);
      } else if (results.length - failed >= framesToAgree) {
        _failing.remove(check);
      }
    }
  }

  void _clearChecks() {
    for (final results in _results.values) {
      results.clear();
    }
    _failing.clear();
  }

  static List<T> _push<T>(List<T> window, T value) {
    window.add(value);
    if (window.length > windowFrames) window.removeAt(0);
    return window;
  }

  void reset() {
    _presence.clear();
    _documentFound = false;
    _absence = null;
    _clearChecks();
  }
}
