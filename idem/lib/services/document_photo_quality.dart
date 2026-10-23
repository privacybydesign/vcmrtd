import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:idem/services/document_liveness.dart';
import 'package:idem/services/document_portrait.dart';
import 'package:mrz_capture/mrz_capture.dart';

// Only the glare thresholds were measured on a device; the rest are starting points.

enum DocumentPhotoIssue {
  noDocument,
  tooDark,

  /// The side with the photo shows no portrait.
  noPortrait,

  /// The side with the MRZ doesn't show its long lines low on the document.
  noMrz,
  glare,
  reflection,
  tilted,
  blurry,
  unreadable,
}

/// In the order their hints are shown.
const _documentChecks = [
  DocumentPhotoIssue.noPortrait,
  DocumentPhotoIssue.noMrz,
  DocumentPhotoIssue.glare,
  DocumentPhotoIssue.reflection,
  DocumentPhotoIssue.tilted,
  DocumentPhotoIssue.blurry,
  DocumentPhotoIssue.unreadable,
];

const _minReadableLines = 3;

/// An MRZ is two or three lines of text across the document, in its lower part.
const _minMrzLines = 2;
const _minMrzLineWidth = 0.6;
const _mrzBelow = 0.5;

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
const _edgeSlopeStep = 0.01;
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
const _maxSampleHeight = 1 << 16;

const _brightnessLevels = 256;

/// ITU-R BT.601 luma weights for blue, green and red, scaled to 256.
const _lumaBlue = 29;
const _lumaGreen = 150;
const _lumaRed = 77;

const _bgraBytesPerPixel = 4;

class LumaFrame {
  /// Android's YUV420/NV21: the first plane is brightness; [u] and [v], at
  /// half its resolution, the colour - grey without them.
  const LumaFrame.luma({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    this.u,
    this.v,
    this.chromaBytesPerRow = 0,
    this.chromaPixelStride = 1,
  }) : isBgra = false;

  const LumaFrame.bgra({required this.bytes, required this.width, required this.height, required this.bytesPerRow})
    : isBgra = true,
      u = null,
      v = null,
      chromaBytesPerRow = 0,
      chromaPixelStride = 1;

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool isBgra;
  final Uint8List? u;
  final Uint8List? v;
  final int chromaBytesPerRow;
  final int chromaPixelStride;

  /// Blue and red difference (YCbCr), 128 for grey.
  (int, int) chromaAt(int x, int y) {
    if (isBgra) {
      final i = y * bytesPerRow + x * _bgraBytesPerPixel;
      final (b, g, r) = (bytes[i], bytes[i + 1], bytes[i + 2]);
      return (128 + ((-43 * r - 85 * g + 128 * b) >> 8), 128 + ((128 * r - 107 * g - 21 * b) >> 8));
    }
    final u = this.u;
    final v = this.v;
    if (u == null || v == null) return (128, 128);
    final i = (y >> 1) * chromaBytesPerRow + (x >> 1) * chromaPixelStride;
    return (u[math.min(i, u.length - 1)], v[math.min(i, v.length - 1)]);
  }

  int brightnessAt(int x, int y) {
    if (!isBgra) return bytes[y * bytesPerRow + x];
    final i = y * bytesPerRow + x * _bgraBytesPerPixel;
    return (bytes[i] * _lumaBlue + bytes[i + 1] * _lumaGreen + bytes[i + 2] * _lumaRed) >> 8;
  }
}

/// A BGRA [frame] with every so many pixels left out, its longer side at
/// least [maxLongEdge] but under twice it: a full-resolution iOS frame is
/// too much for text recognition and the checks to keep up with.
LumaFrame shrunkBgra(LumaFrame frame, {required int maxLongEdge}) {
  final step = math.max(frame.width, frame.height) ~/ maxLongEdge;
  if (!frame.isBgra || step <= 1) return frame;
  final width = frame.width ~/ step;
  final height = frame.height ~/ step;
  final pixels = Uint32List(width * height);
  // Read four bytes at a time, which needs them to start on a whole pixel.
  var bytes = frame.bytes;
  if (bytes.offsetInBytes % _bgraBytesPerPixel != 0) bytes = Uint8List.fromList(bytes);
  final source = bytes.buffer.asUint32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ _bgraBytesPerPixel);
  final pixelsPerRow = frame.bytesPerRow ~/ _bgraBytesPerPixel;
  for (var y = 0; y < height; y++) {
    final from = y * step * pixelsPerRow;
    for (var x = 0; x < width; x++) {
      pixels[y * width + x] = source[from + x * step];
    }
  }
  return LumaFrame.bgra(
    bytes: pixels.buffer.asUint8List(),
    width: width,
    height: height,
    bytesPerRow: width * _bgraBytesPerPixel,
  );
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
  final height = (regionHeight / step).round().clamp(1, _maxSampleHeight);
  final taps = step.floor().clamp(1, 3);
  final columns = _tapPositions(width, taps, left, step, uprightWidth);
  final rows = _tapPositions(height, taps, top, step, uprightHeight);
  // Each upright tap as its byte offset in the frame, so the loop below only adds and reads.
  final (columnOffsets, rowOffsets) = _frameOffsets(frame, rotation, columns, rows);
  final bytes = frame.bytes;
  final bgra = frame.isBgra;
  final tapCount = taps * taps;
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final rowTaps = y * taps;
    for (var x = 0; x < width; x++) {
      final columnTaps = x * taps;
      var sum = 0;
      for (var ty = 0; ty < taps; ty++) {
        final rowOffset = rowOffsets[rowTaps + ty];
        for (var tx = 0; tx < taps; tx++) {
          final i = columnOffsets[columnTaps + tx] + rowOffset;
          sum += bgra ? (bytes[i] * _lumaBlue + bytes[i + 1] * _lumaGreen + bytes[i + 2] * _lumaRed) >> 8 : bytes[i];
        }
      }
      pixels[y * width + x] = sum ~/ tapCount;
    }
  }

  return DocumentSample(pixels, width, height);
}

Int32List _tapPositions(int count, int taps, double origin, double step, int size) => Int32List.fromList([
  for (var i = 0; i < count; i++)
    for (var t = 0; t < taps; t++) (origin + (i + (t + 0.5) / taps) * step).floor().clamp(0, size - 1),
]);

/// Where the upright [columns] and [rows] are in [frame]'s bytes: a pixel's
/// offset is its column's plus its row's, as [_uprightBrightness] maps them.
(Int32List, Int32List) _frameOffsets(LumaFrame frame, int rotation, Int32List columns, Int32List rows) {
  final pixel = frame.isBgra ? _bgraBytesPerPixel : 1;
  final row = frame.bytesPerRow;
  final (int Function(int) column, int Function(int) upright) = switch (rotation) {
    90 => ((x) => (frame.height - 1 - x) * row, (y) => y * pixel),
    180 => ((x) => (frame.width - 1 - x) * pixel, (y) => (frame.height - 1 - y) * row),
    270 => ((x) => x * row, (y) => (frame.width - 1 - y) * pixel),
    _ => ((x) => x * pixel, (y) => y * row),
  };
  return (
    Int32List.fromList([for (final x in columns) column(x)]),
    Int32List.fromList([for (final y in rows) upright(y)]),
  );
}

int Function(int x, int y) _uprightBrightness(LumaFrame frame, int rotation) => switch (rotation) {
  90 => (x, y) => frame.brightnessAt(y, frame.height - 1 - x),
  180 => (x, y) => frame.brightnessAt(frame.width - 1 - x, frame.height - 1 - y),
  270 => (x, y) => frame.brightnessAt(frame.width - 1 - y, x),
  _ => frame.brightnessAt,
};

Set<DocumentPhotoIssue> checkFrame(LumaFrame frame, {required int rotation, required Rect region}) =>
    inspectFrame(frame, rotation: rotation, region: region).issues;

/// [checkFrame], and the document found, for the portrait to be looked for on.
FrameInspection inspectFrame(LumaFrame frame, {required int rotation, required Rect region}) {
  final (sample, inSample) = _sampleFrame(frame, rotation: rotation, region: region);
  final outline = _findDocument(sample, inSample);
  return (issues: _issues(sample, inSample, outline), document: outline == null ? null : sample.crop(outline.area));
}

typedef FrameInspection = ({Set<DocumentPhotoIssue> issues, DocumentSample? document});

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

(int, int) Function(int x, int y) _uprightChroma(LumaFrame frame, int rotation) => switch (rotation) {
  90 => (x, y) => frame.chromaAt(y, frame.height - 1 - x),
  180 => (x, y) => frame.chromaAt(frame.width - 1 - x, frame.height - 1 - y),
  270 => (x, y) => frame.chromaAt(frame.width - 1 - y, x),
  _ => frame.chromaAt,
};

const _signatureTaps = 3;

/// The document lies inside the frame drawn over the preview, not on its edge.
const _signatureInset = 0.08;

/// The document in [frame] for [DocumentLiveness]: cheap enough for every
/// frame, and taken in the frame drawn over the preview ([region], fractions
/// of the upright frame) so a frame whose document the torch's glare hides
/// still counts.
FrameSignature frameSignature(LumaFrame frame, {required int rotation, required Rect region}) {
  final inner = region.deflateBy(region.width * _signatureInset, region.height * _signatureInset);
  final brightnessAt = _uprightBrightness(frame, rotation);
  final chromaAt = _uprightChroma(frame, rotation);
  final uprightWidth = rotation % 180 == 0 ? frame.width : frame.height;
  final uprightHeight = rotation % 180 == 0 ? frame.height : frame.width;
  const cells = signatureColumns * signatureRows;
  final luma = Float32List(cells);
  final cb = Float32List(cells);
  final cr = Float32List(cells);
  for (var row = 0; row < signatureRows; row++) {
    for (var column = 0; column < signatureColumns; column++) {
      final cell = row * signatureColumns + column;
      var lumaSum = 0;
      var cbSum = 0;
      var crSum = 0;
      for (var ty = 0; ty < _signatureTaps; ty++) {
        for (var tx = 0; tx < _signatureTaps; tx++) {
          final fx = inner.left + (column + (tx + 0.5) / _signatureTaps) / signatureColumns * inner.width;
          final fy = inner.top + (row + (ty + 0.5) / _signatureTaps) / signatureRows * inner.height;
          final ux = (fx * uprightWidth).toInt().clamp(0, uprightWidth - 1);
          final uy = (fy * uprightHeight).toInt().clamp(0, uprightHeight - 1);
          lumaSum += brightnessAt(ux, uy);
          final (b, r) = chromaAt(ux, uy);
          cbSum += b;
          crSum += r;
        }
      }
      const taps = _signatureTaps * _signatureTaps;
      luma[cell] = lumaSum / taps;
      cb[cell] = cbSum / taps;
      cr[cell] = crSum / taps;
    }
  }

  return FrameSignature(
    luma: luma,
    cb: cb,
    cr: cr,
    bands: sensorBands(frame, rotation: rotation, region: inner),
  );
}

const _torchViewWidth = 240;

/// The document in [region] (fractions of the upright frame), grey and
/// small: what the torch test compares before and with the torch on.
DocumentView torchView(LumaFrame frame, {required int rotation, required Rect region}) {
  final inner = region.deflateBy(region.width * _signatureInset, region.height * _signatureInset);
  final sample = sampleDocument(frame, rotation: rotation, region: inner, maxWidth: _torchViewWidth);
  return (pixels: sample.pixels, width: sample.width, height: sample.height);
}

const _bandLength = 384;
const _bandTaps = 24;

/// The brightness of [region] (fractions of the upright frame) along the
/// frame's rows and along its columns as the sensor read them, not turned
/// upright: a rolling shutter reads the rows one after another, so a
/// flickering light shows as stripes along one of them (iOS's frames come
/// turned already, so it's the columns there).
SensorBands sensorBands(LumaFrame frame, {required int rotation, required Rect region}) {
  final sensor = _sensorRect(region, rotation);
  final left = (sensor.left * frame.width).floor().clamp(0, frame.width - 1);
  final right = (sensor.right * frame.width).ceil().clamp(left + 1, frame.width);
  final top = (sensor.top * frame.height).floor().clamp(0, frame.height - 1);
  final bottom = (sensor.bottom * frame.height).ceil().clamp(top + 1, frame.height);

  Float32List along(int from, int to, int acrossFrom, int acrossTo, int Function(int along, int across) brightnessAt) {
    final length = math.min(_bandLength, to - from);
    final band = Float32List(length);
    for (var i = 0; i < length; i++) {
      final start = from + (to - from) * i ~/ length;
      final end = math.max(start + 1, from + (to - from) * (i + 1) ~/ length);
      var sum = 0;
      for (var a = start; a < end; a++) {
        for (var t = 0; t < _bandTaps; t++) {
          sum += brightnessAt(a, acrossFrom + (acrossTo - acrossFrom) * (2 * t + 1) ~/ (2 * _bandTaps));
        }
      }
      band[i] = sum / ((end - start) * _bandTaps);
    }
    return band;
  }

  return (
    rows: along(top, bottom, left, right, (y, x) => frame.brightnessAt(x, y)),
    columns: along(left, right, top, bottom, frame.brightnessAt),
  );
}

/// [upright] (fractions of the upright frame) in fractions of the frame as
/// it came from the sensor, which [rotation] turns upright.
Rect _sensorRect(Rect upright, int rotation) => switch (rotation) {
  90 => Rect.fromLTRB(upright.top, 1 - upright.right, upright.bottom, 1 - upright.left),
  180 => Rect.fromLTRB(1 - upright.right, 1 - upright.bottom, 1 - upright.left, 1 - upright.top),
  270 => Rect.fromLTRB(1 - upright.bottom, upright.left, 1 - upright.top, upright.right),
  _ => upright,
};

Set<DocumentPhotoIssue> documentPhotoIssues(DocumentSample sample, {required Rect frame}) =>
    _issues(sample, frame, _findDocument(sample, frame));

Set<DocumentPhotoIssue> _issues(DocumentSample sample, Rect frame, _DocumentOutline? outline) {
  if (outline == null) {
    final inFrame = _tileHistograms(
      sample.crop(frame.deflateBy(frame.width * _documentInset, frame.height * _documentInset)),
    );
    if (_hasGlare(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.glare};
    if (_hasReflection(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.reflection};
    // The whole sample, not only the frame: a dark room, not a dark document.
    return {
      _paperBrightness([_histogram(sample)]) < _tooDarkPaperBrightness
          ? DocumentPhotoIssue.tooDark
          : DocumentPhotoIssue.noDocument,
    };
  }

  final area = outline.area;
  final document = sample.crop(area.deflateBy(area.width * _documentInset, area.height * _documentInset));
  // One pass over the document's pixels for the darkness, glare and reflection checks.
  final tiles = _tileHistograms(document);
  if (_paperBrightness(tiles) < _tooDarkPaperBrightness) return {DocumentPhotoIssue.tooDark};
  return {
    if (_hasGlare(tiles)) DocumentPhotoIssue.glare,
    if (_hasReflection(tiles)) DocumentPhotoIssue.reflection,
    if (outline.tilted) DocumentPhotoIssue.tilted,
    if (_sharpness(document) < _minSharpness) DocumentPhotoIssue.blurry,
  };
}

bool textReadable(List<Rect> lines, Rect region) =>
    lines.where((line) => region.contains(line.center)).length >= _minReadableLines;

/// The lines of text, in fractions of the upright frame, that lie across
/// [region] in its lower part: an MRZ's, found by where they are, not read.
int mrzLines(List<Rect> lines, Rect region) => _rows(lines)
    .where(
      (row) =>
          region.contains(row.center) &&
          row.width >= region.width * _minMrzLineWidth &&
          row.center.dy >= region.top + region.height * _mrzBelow,
    )
    .length;

/// Text recognition can split one line into pieces (an MRZ line at its runs
/// of fillers): pieces at the same height make one row.
List<Rect> _rows(List<Rect> lines) {
  final rows = <Rect>[];
  for (final line in [...lines]..sort((a, b) => a.center.dy.compareTo(b.center.dy))) {
    final last = rows.isEmpty ? null : rows.last;
    if (last != null && (line.center.dy - last.center.dy).abs() <= math.max(line.height, last.height) / 2) {
      rows.last = last.expandToInclude(line);
    } else {
      rows.add(line);
    }
  }
  return rows;
}

bool mrzLayout(List<Rect> lines, Rect region) => isMrzLayout(mrzLines(lines, region));

/// Whether [mrzLines] counted enough lines for an MRZ.
bool isMrzLayout(int mrzLines) => mrzLines >= _minMrzLines;

/// What a side of the document shows that tells it's that side of an identity document.
typedef SideContent = ({bool portrait, bool mrz});

/// Adds [DocumentPhotoIssue.unreadable] to the issues of a frame whose text was not readable.
Set<DocumentPhotoIssue> withUnreadable(Set<DocumentPhotoIssue> issues) =>
    _withIssue(issues, DocumentPhotoIssue.unreadable);

/// Adds [DocumentPhotoIssue.noPortrait] to the issues of a frame whose side with the photo shows none.
Set<DocumentPhotoIssue> withoutPortrait(Set<DocumentPhotoIssue> issues) =>
    _withIssue(issues, DocumentPhotoIssue.noPortrait);

/// Adds [DocumentPhotoIssue.noMrz] to the issues of a frame whose MRZ was not found.
Set<DocumentPhotoIssue> withoutMrz(Set<DocumentPhotoIssue> issues) => _withIssue(issues, DocumentPhotoIssue.noMrz);

Set<DocumentPhotoIssue> _withIssue(Set<DocumentPhotoIssue> issues, DocumentPhotoIssue issue) {
  final noDocument = issues.contains(DocumentPhotoIssue.noDocument) || issues.contains(DocumentPhotoIssue.tooDark);
  return noDocument ? issues : {...issues, issue};
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
    for (var s = -_maxEdgeSlope; s <= _maxEdgeSlope + 1e-9; s += _edgeSlopeStep) {
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

/// What [DocumentFrameChecker.check] found: the frame's issues, and - when
/// asked - the portrait on the document, which takes longer.
typedef FrameCheck = ({Future<Set<DocumentPhotoIssue>> issues, Future<DocumentPortrait?>? portrait});

const _closeRequest = 'close';

/// Checks preview frames on an isolate of its own. With face models a second
/// isolate looks for the portrait on the document the first one found, so
/// face detection, the slowest check, doesn't hold up the others - and gets
/// only that small grey document, not the frame.
class DocumentFrameChecker {
  DocumentFrameChecker._();

  final _ports = <ReceivePort>[];
  SendPort? _requests;
  SendPort? _portraitRequests;
  final _pending = Queue<Completer<Set<DocumentPhotoIssue>>>();
  final _portraitPending = Queue<Completer<DocumentPortrait?>>();

  /// Why no more frames can be checked: closed, or the isolate died.
  Object? _stopped;
  Object? _portraitStopped;

  /// Like the MRZ scanner's OCR, frames that arrive while one is checked are skipped.
  bool get busy => _pending.isNotEmpty;

  /// Closed, or its isolate died: it checks no more frames.
  bool get stopped => _stopped != null;

  /// Whether a [check] can look for the portrait too.
  bool get portraitFree =>
      _portraitRequests != null && _stopped == null && _portraitStopped == null && _portraitPending.isEmpty;

  /// With [faceModels] it can look for the portrait on the side with the
  /// photo; without them, or when they don't load, it can't.
  static Future<DocumentFrameChecker> start({FaceModels? faceModels}) async {
    final checker = DocumentFrameChecker._();
    final portraits = faceModels == null
        ? Future<SendPort?>.value()
        : checker
              ._spawn(_servePortraits, faceModels, onReply: checker._onPortrait, onStopped: checker._stopPortraits)
              .then<SendPort?>(
                (port) => port,
                onError: (Object e) {
                  checker._portraitStopped = e;
                  return null;
                },
              );
    try {
      final (requests, portraitRequests) = await (
        checker._spawn(_serve, null, onReply: checker._onIssues, onStopped: checker._stop),
        portraits,
      ).wait;
      checker
        .._requests = requests
        .._portraitRequests = portraitRequests;
      if (portraitRequests != null) requests.send(portraitRequests);
      return checker;
    } on ParallelWaitError<(SendPort?, SendPort?), (AsyncError?, AsyncError?)> catch (e) {
      final (requests, portraitRequests) = e.values;
      checker
        .._requests = requests
        .._portraitRequests = portraitRequests
        ..close();
      final error = e.errors.$1!;
      Error.throwWithStackTrace(error.error, error.stackTrace);
    }
  }

  /// Completes with the port [serve] takes requests on, or fails when it
  /// can't start; afterwards its replies go to [onReply], and to
  /// [onStopped] once it dies.
  Future<SendPort> _spawn<T>(
    void Function((SendPort, T)) serve,
    T setup, {
    required void Function(Object? reply) onReply,
    required void Function(Object reason) onStopped,
  }) async {
    final port = ReceivePort();
    // An uncaught error ([error, stack]) or the isolate's exit (null).
    final died = ReceivePort();
    _ports.addAll([port, died]);
    final ready = Completer<SendPort>();
    port.listen((message) {
      if (message is SendPort) return ready.complete(message);
      onReply(message);
    });
    died.listen((message) {
      port.close();
      died.close();
      final reason = StateError('the frame checker stopped: ${message is List ? message.first : 'exited'}');
      if (ready.isCompleted) {
        onStopped(reason);
      } else {
        ready.completeError(reason);
      }
    });
    try {
      await Isolate.spawn(serve, (port.sendPort, setup), onError: died.sendPort, onExit: died.sendPort);
    } catch (_) {
      port.close();
      died.close();
      rethrow;
    }
    return ready.future;
  }

  // A reply can come in after the isolate's death failed what was pending.
  void _onIssues(Object? reply) {
    if (_pending.isEmpty) return;
    final pending = _pending.removeFirst();
    switch (reply) {
      case Set<DocumentPhotoIssue> issues:
        pending.complete(issues);
      case (:String error):
        pending.completeError(StateError(error));
    }
  }

  void _onPortrait(Object? reply) {
    if (_portraitPending.isEmpty) return;
    final pending = _portraitPending.removeFirst();
    switch (reply) {
      case (:DocumentPortrait? portrait):
        pending.complete(portrait);
      case (:String error):
        pending.completeError(StateError(error));
    }
  }

  void _stop(Object reason) => _shutDown(reason);

  void _stopPortraits(Object reason) {
    _portraitStopped = reason;
    while (_portraitPending.isNotEmpty) {
      _portraitPending.removeFirst().completeError(reason);
    }
  }

  /// [portrait]: the side with the photo, which needs its portrait; only
  /// while [portraitFree].
  FrameCheck check(LumaFrame frame, {required int rotation, required Rect region, bool portrait = false}) {
    final stopped = _stopped;
    if (stopped != null) return (issues: Future.error(stopped), portrait: null);
    if (portrait && !portraitFree) throw StateError('the portrait is still being looked for');
    final issues = Completer<Set<DocumentPhotoIssue>>();
    _pending.add(issues);
    final portraitFound = portrait ? Completer<DocumentPortrait?>() : null;
    if (portraitFound != null) _portraitPending.add(portraitFound);
    TransferableTypedData? transferable(Uint8List? bytes) =>
        bytes == null ? null : TransferableTypedData.fromList([bytes]);
    _requests!.send((
      bytes: TransferableTypedData.fromList([frame.bytes]),
      u: transferable(frame.u),
      v: transferable(frame.v),
      chromaBytesPerRow: frame.chromaBytesPerRow,
      chromaPixelStride: frame.chromaPixelStride,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      bgra: frame.isBgra,
      rotation: rotation,
      region: (region.left, region.top, region.right, region.bottom),
      portrait: portrait,
    ));

    return (issues: issues.future, portrait: portraitFound?.future);
  }

  /// Lets both isolates finish the frame they're on and exit, the face
  /// models released.
  void close() => _shutDown(StateError('closed'));

  void _shutDown(Object reason) {
    if (_stopped != null) return;
    _stopped = reason;
    _requests?.send(_closeRequest);
    _portraitRequests?.send(_closeRequest);
    for (final port in _ports) {
      port.close();
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(reason);
    }
    _stopPortraits(reason);
  }

  static void _serve((SendPort, Null) setup) {
    final (replies, _) = setup;
    SendPort? portraits;
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((request) {
      switch (request) {
        case _closeRequest:
          requests.close();
        case SendPort port:
          portraits = port;
        case _FrameRequest r:
          DocumentSample? document;
          try {
            final inspection = inspectFrame(
              _frameOf(r),
              rotation: r.rotation,
              region: Rect.fromLTRB(r.region.$1, r.region.$2, r.region.$3, r.region.$4),
            );
            document = inspection.document;
            replies.send(inspection.issues);
          } catch (e) {
            replies.send((error: '$e'));
          } finally {
            // Every portrait asked for gets an answer, none when no document was found.
            if (r.portrait) {
              portraits?.send(
                document == null
                    ? null
                    : (
                        pixels: TransferableTypedData.fromList([document.pixels]),
                        width: document.width,
                        height: document.height,
                      ),
              );
            }
          }
      }
    });
  }

  static void _servePortraits((SendPort, FaceModels) setup) {
    final (replies, models) = setup;
    final finder = portraitFinder(models);
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((request) {
      if (request == _closeRequest) {
        requests.close();
        finder.close();
        return;
      }
      try {
        final document = request as _PortraitRequest?;
        replies.send((
          portrait: document == null
              ? null
              : findPortrait(finder, document.pixels.materialize().asUint8List(), document.width, document.height),
        ));
      } catch (e) {
        replies.send((error: '$e'));
      }
    });
  }

  static LumaFrame _frameOf(_FrameRequest r) {
    final bytes = r.bytes.materialize().asUint8List();
    return r.bgra
        ? LumaFrame.bgra(bytes: bytes, width: r.width, height: r.height, bytesPerRow: r.bytesPerRow)
        : LumaFrame.luma(
            bytes: bytes,
            width: r.width,
            height: r.height,
            bytesPerRow: r.bytesPerRow,
            u: r.u?.materialize().asUint8List(),
            v: r.v?.materialize().asUint8List(),
            chromaBytesPerRow: r.chromaBytesPerRow,
            chromaPixelStride: r.chromaPixelStride,
          );
  }
}

typedef _FrameRequest = ({
  TransferableTypedData bytes,
  TransferableTypedData? u,
  TransferableTypedData? v,
  int chromaBytesPerRow,
  int chromaPixelStride,
  int width,
  int height,
  int bytesPerRow,
  bool bgra,
  int rotation,
  (double, double, double, double) region,
  bool portrait,
});

typedef _PortraitRequest = ({TransferableTypedData pixels, int width, int height});

/// The paper's brightness over all of [histograms] together: the areas
/// [_tileHistograms] split a document into add up to the whole document.
int _paperBrightness(List<List<int>> histograms) {
  final total = List.filled(_brightnessLevels, 0);
  for (final histogram in histograms) {
    for (var b = 0; b < _brightnessLevels; b++) {
      total[b] += histogram[b];
    }
  }

  return _percentile(total, _paperPercentile);
}

List<int> _histogram(DocumentSample sample) {
  final histogram = List.filled(_brightnessLevels, 0);
  for (final p in sample.pixels) {
    histogram[p]++;
  }

  return histogram;
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

bool _hasGlare(List<List<int>> histograms) => histograms.any(_glaring);

bool _hasReflection(List<List<int>> histograms) {
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
