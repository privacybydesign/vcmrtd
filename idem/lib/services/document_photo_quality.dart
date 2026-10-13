import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:mrz_capture/mrz_capture.dart';

// The document photo is read by people and software at the relying party:
// whatever the camera sees when the user takes it is what gets sent. So every
// preview frame of the document capture step goes through two stages:
//
// 1. Is a document in the frame? Its outline - the edges where it meets the
//    surface it lies on - must lie along the frame drawn over the preview, so
//    not an empty table, nor a document half outside the frame or far smaller
//    than it. Without one, the frame is only checked for why: glare over it -
//    a reflection that big washes out the document's edges, so it would
//    otherwise pass for no document at all - too dark to see one, or none
//    there.
// 2. Is the photo of it good? Only once there is a document, and only on it,
//    inside its outline: glare, a reflection that clips nothing, tilt and
//    blur, and whether its text can be read at all, each on its own. One failing never keeps the others from being
//    measured, and each settles over the frames on its own
//    (DocumentPhotoQuality), so one flickering doesn't drag the others along.
//
// Every frame's pixels are checked, in order, on an isolate of its own
// (DocumentFrameChecker): a few milliseconds a frame. Reading the text takes
// longer than a frame lasts, so the text recognizer reads the latest frame
// whenever it's done with the last, and every frame is checked against its
// latest read (withReadability).
//
// Only the glare thresholds are measured on a device (for the MRZ, in the
// Yivi app, on an Android phone); the reflection one follows the open-source
// glare-score; the others are starting points. Whatever they get wrong, the
// photo can be taken anyway after a few seconds
// (documentPhotoQualityWaiveDelay), and the review still asks whether it's
// readable.

/// What keeps a camera frame from giving a good document photo. The first two
/// say why no document was found, as glare and reflection may too; the others
/// are found on a document.
enum DocumentPhotoIssue { noDocument, tooDark, glare, reflection, tilted, blurry, unreadable }

/// The checks made on a document once one is found, in the order their issues
/// are told: a reflection first, as it hides what's printed however sharp;
/// then tilt, which tilting away a reflection may overdo; then blur, as it
/// mostly lasts only while the phone moves; unreadable text last, as the
/// others say why it would be.
const documentChecks = [
  DocumentPhotoIssue.glare,
  DocumentPhotoIssue.reflection,
  DocumentPhotoIssue.tilted,
  DocumentPhotoIssue.blurry,
  DocumentPhotoIssue.unreadable,
];

/// The text on the document is readable when the text recognizer reads at
/// least this many lines of it: every side of an identity document has more.
const minReadableLines = 3;

/// A document's edges must lie from this far outside each side of the frame
/// to this far inside it, as fractions of the frame's size across that side.
/// Outside: less than the margin the photo keeps around the frame
/// ([DocumentPicture.frameMargin]), so a document found lies whole in the
/// photo. Inside: a document whose edges lie further in is far smaller than
/// the frame, and its print too small in the photo.
const edgeSearchOutside = 0.06;
const edgeSearchInside = 0.2;

/// They're looked for from this far outside, though: a document sticking out
/// of the frame further than [edgeSearchOutside] must have its edge seen
/// there, or the edge of its print, inside the frame, would pass for it.
const edgeSearchFar = 0.2;

/// Each side's edge is looked for in this many strips across it, side by
/// side over the middle [edgeSpan] of the side: a document's corners are
/// rounded. Each strip's brightness at each depth is the mean over the
/// strip's width: the document's edge runs along the whole strip and stands
/// out, while noise, print and a textured surface average away.
const edgeProfiles = 12;
const edgeSpan = 0.8;

/// An edge is a step in a strip's brightness of at least [minEdgeStep] (0-255) between
/// the means of [edgeWindow] pixels on either side of it, peaking there: no
/// step nearby is bigger. The [edgeGap] pixels right at the step are skipped:
/// the camera blurs it over a few pixels and sharpens it again, which leaves
/// a halo on either side. The surface outside must be plain next to it - its
/// pixels varying by at most [maxFlatRange], or [maxFlatShare] of the step on
/// a step that big - or a busy surface would pass for edges everywhere.
const minEdgeStep = 12;
const maxFlatRange = 24;
const maxFlatShare = 0.6;
const edgeWindow = 6;
const edgeGap = 3;

/// A side's edge is found when at least [minEdgeInliers] of its lines found
/// it on one straight line, within [edgeTolerance] pixels, turned at most
/// [maxEdgeSlope] from the side: the outermost such line, as the print inside
/// the document may make more.
const minEdgeInliers = 0.5;
const edgeTolerance = 3.0;
const maxEdgeSlope = 0.25;

/// With all four edges found, the document's width over its height must be
/// within this share of the frame's: no other edge passing for one of them.
const maxShapeError = 0.1;

/// The checks on the document are made this far (a fraction of its size)
/// inside its edges: right at them lies the surface, or a highlight on the
/// document's rim.
const documentInset = 0.03;

/// Pixels at or above this brightness count as clipped: a reflection.
const clippedBrightness = 250;

/// The document is split into this grid of tiles for glare and reflection: a
/// reflection usually covers part of it, which a measurement over the whole
/// document would average away. Each tile is about a few characters in size.
const glareColumns = 16;
const glareRows = 10;

/// A tile with more than this share of clipped pixels has glare on it. The
/// Yivi app's MRZ scanner, whose tiles of an MRZ line are about the size of
/// these, uses 10%; this is stricter, as print anywhere on the document must
/// stay readable. Measured there on a Galaxy S9: the worst tile of a clean MRZ
/// had no clipped pixels at all, while 15 of 16 frames with a reflection on it
/// had 21% to 57% in theirs.
const glareTileShare = 0.05;

/// A reflection just short of clipping - a camera that keeps its highlights,
/// as iPhones do - is told the way the open-source glare-score does: pixels at
/// or above [nearClippedBrightness] in more than [glareTileShare] of a tile,
/// standing out at least [reflectionContrast] above the document's paper (the
/// median of its tiles' brightest parts, [paperPercentile]). Not over its
/// paper, the whole document is just brightly lit.
const nearClippedBrightness = 240;
const reflectionContrast = 15;

/// The document lies tilted - facing the camera at an angle, its far side
/// smaller - when opposite edges differ in angle by more than this: a
/// document lying flat under the phone has them parallel. Loose enough for
/// the slight tilt the glare hint asks for.
const maxConvergenceDegrees = 8.0;

/// The blur grid: text only covers part of the document, which a measurement
/// over the whole would average away.
const tileColumns = 8;
const tileRows = 5;

/// Below this variance of the Laplacian, over the sharpest quarter of the
/// tiles, the document is blurred: sharp print has strong edges, which a blur
/// smooths out.
const minSharpness = 60.0;

/// Without a document, the frame is too dark when even its brighter part -
/// the brightness [paperPercentile] of its pixels stay below - is darker than
/// this (0-255).
const tooDarkPaperBrightness = 60;
const paperPercentile = 0.9;

/// The frame is sampled down to at most this many pixels across before it is
/// checked: enough to tell sharp print from blurred.
const sampleWidth = 640;

/// The brightness of a camera preview frame as it comes from the sensor:
/// [width] x [height] pixels, [bytesPerRow] bytes per row.
class LumaFrame {
  /// A frame whose first plane is its brightness: Android's YUV420 and NV21.
  const LumaFrame.luma({required this.bytes, required this.width, required this.height, required this.bytesPerRow})
    : _bgra = false;

  /// A BGRA8888 frame, as iOS streams them.
  const LumaFrame.bgra({required this.bytes, required this.width, required this.height, required this.bytesPerRow})
    : _bgra = true;

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool _bgra;

  /// Whether this is a BGRA8888 frame rather than its brightness alone.
  bool get isBgra => _bgra;

  /// The brightness of the pixel at ([x], [y]) in the sensor frame.
  int brightnessAt(int x, int y) {
    if (!_bgra) return bytes[y * bytesPerRow + x];
    final i = y * bytesPerRow + x * 4;
    // BT.601 luma, in fixed point.
    return (bytes[i] * 29 + bytes[i + 1] * 150 + bytes[i + 2] * 77) >> 8;
  }
}

/// A small upright grayscale image of the document, [width] x [height].
class DocumentSample {
  const DocumentSample(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;

  /// The part of this sample within [area], in its pixels.
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

/// Samples [region] of [frame] into an upright [DocumentSample] at most
/// [maxWidth] pixels wide.
///
/// [rotation] is the clockwise rotation in degrees that turns the frame upright,
/// and [region] is the document frame as fractions of the upright frame's width
/// and height. Each sample pixel averages the frame pixels it covers (a few of
/// them, at most 3 x 3): the sensor's noise would otherwise pass for sharp edges.
DocumentSample sampleDocument(
  LumaFrame frame, {
  required int rotation,
  required Rect region,
  int maxWidth = sampleWidth,
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
  // The upright columns and rows each sample pixel's taps read, worked out
  // once rather than for every pixel.
  final columns = Int32List.fromList([
    for (var x = 0; x < width; x++)
      for (var tx = 0; tx < taps; tx++) (left + (x + (tx + 0.5) / taps) * step).floor().clamp(0, uprightWidth - 1),
  ]);
  final rows = Int32List.fromList([
    for (var y = 0; y < height; y++)
      for (var ty = 0; ty < taps; ty++) (top + (y + (ty + 0.5) / taps) * step).floor().clamp(0, uprightHeight - 1),
  ]);
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var sum = 0;
      for (var ty = 0; ty < taps; ty++) {
        final uy = rows[y * taps + ty];
        for (var tx = 0; tx < taps; tx++) {
          final ux = columns[x * taps + tx];
          // Upright (ux, uy) back to the sensor frame, undoing the clockwise rotation.
          sum += switch (rotation) {
            90 => frame.brightnessAt(uy, frame.height - 1 - ux),
            180 => frame.brightnessAt(frame.width - 1 - ux, frame.height - 1 - uy),
            270 => frame.brightnessAt(frame.width - 1 - uy, ux),
            _ => frame.brightnessAt(ux, uy),
          };
        }
      }
      pixels[y * width + x] = sum ~/ (taps * taps);
    }
  }
  return DocumentSample(pixels, width, height);
}

/// The issues of a preview [frame] with the frame drawn over the preview at
/// [region], as fractions of the upright frame's width and height: samples the
/// frame and the margin around it ([sampleDocument]) and checks it
/// ([documentPhotoIssues]). [DocumentFrameChecker] runs it off the UI isolate.
Set<DocumentPhotoIssue> checkFrame(LumaFrame frame, {required int rotation, required Rect region}) {
  final (sample, inSample) = sampleFrame(frame, rotation: rotation, region: region);
  return documentPhotoIssues(sample, frame: inSample);
}

/// The sample [checkFrame] checks: the frame at [region] and the margin
/// around it, and where the frame lies in it, in its pixels.
(DocumentSample, Rect) sampleFrame(LumaFrame frame, {required int rotation, required Rect region}) {
  const margin = edgeSearchFar;
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

/// The issues of [sample], with the frame drawn over the preview at [frame]
/// in its pixels.
///
/// Without a document ([findDocument]) there is nothing to check but why:
/// glare or a reflection inside the frame, which washes out the document's
/// edges (with [DocumentPhotoIssue.noDocument]); [DocumentPhotoIssue.tooDark]
/// to see one; or [DocumentPhotoIssue.noDocument] there. With one, each of [documentChecks] is made on its own, on the
/// document alone.
Set<DocumentPhotoIssue> documentPhotoIssues(DocumentSample sample, {required Rect frame}) {
  final outline = findDocument(sample, frame);
  if (outline == null) {
    final inFrame = sample.crop(frame.deflateBy(frame.width * documentInset, frame.height * documentInset));
    if (hasGlare(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.glare};
    if (hasReflection(inFrame)) return {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.reflection};
    return {
      paperBrightness(sample) < tooDarkPaperBrightness ? DocumentPhotoIssue.tooDark : DocumentPhotoIssue.noDocument,
    };
  }
  final area = outline.area;
  final document = sample.crop(area.deflateBy(area.width * documentInset, area.height * documentInset));
  // Its edges show, but its print may not.
  if (paperBrightness(document) < tooDarkPaperBrightness) return {DocumentPhotoIssue.tooDark};
  return {
    if (hasGlare(document)) DocumentPhotoIssue.glare,
    if (hasReflection(document)) DocumentPhotoIssue.reflection,
    if (outline.tilted) DocumentPhotoIssue.tilted,
    if (sharpness(document) < minSharpness) DocumentPhotoIssue.blurry,
  };
}

/// Whether the text recognizer could read the text of the document in the
/// frame at [region]: [lines] it read, boxes as fractions of the upright
/// frame's width and height, of which at least [minReadableLines] lie in the
/// frame.
bool textReadable(List<Rect> lines, Rect region) =>
    lines.where((line) => region.contains(line.center)).length >= minReadableLines;

/// [issues] of a frame ([checkFrame]), with [DocumentPhotoIssue.unreadable]
/// when a document was found but the latest read of its text was not
/// [readable].
Set<DocumentPhotoIssue> withReadability(Set<DocumentPhotoIssue> issues, {required bool readable}) {
  final noDocument = issues.contains(DocumentPhotoIssue.noDocument) || issues.contains(DocumentPhotoIssue.tooDark);
  return noDocument || readable ? issues : {...issues, DocumentPhotoIssue.unreadable};
}

extension on Rect {
  Rect deflateBy(double dx, double dy) => Rect.fromLTRB(left + dx, top + dy, right - dx, bottom - dy);
}

/// One edge of the document, found along a side of the frame: its depth
/// inside that side (negative: outside it), in pixels, is [offset] +
/// [slope] x the position along the side.
typedef Edge = ({double slope, double offset});

/// The document found in a frame: where its edges lie, as far as they were
/// found ([top], [bottom], [left], [right]; null: not found, one at most), and
/// the [area] they enclose, in the sample's pixels.
class DocumentOutline {
  const DocumentOutline({
    required this.area,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final Rect area;
  final Edge? top;
  final Edge? bottom;
  final Edge? left;
  final Edge? right;

  /// Whether opposite edges, where both were found, differ in angle by more
  /// than [maxConvergenceDegrees]. Each edge's angle is its turn clockwise
  /// from the side of the frame it lies along: equal for all four on a
  /// document that is only turned flat on the table.
  bool get tilted {
    double angle(Edge edge, {required bool clockwise}) =>
        math.atan(clockwise ? edge.slope : -edge.slope) * 180 / math.pi;
    bool apart(Edge? a, Edge? b, {required bool aClockwise}) =>
        a != null &&
        b != null &&
        (angle(a, clockwise: aClockwise) - angle(b, clockwise: !aClockwise)).abs() > maxConvergenceDegrees;
    return apart(top, bottom, aClockwise: true) || apart(right, left, aClockwise: true);
  }
}

enum _Side { top, bottom, left, right }

/// Finds the document in [sample] whose edges lie along [frame] (see
/// [edgeSearchOutside]); null when there is none.
///
/// One edge may go unfound - a passport's page above the photographed one
/// meets it in a fold rather than an edge - and lies where the frame's shape
/// puts it, which must then be along its side of the frame too.
DocumentOutline? findDocument(DocumentSample sample, Rect frame) {
  final edges = {for (final side in _Side.values) side: _findEdge(sample, frame, side)};
  final found = _outline(edges, frame);
  if (found != null || edges.values.any((edge) => edge == null)) return found;
  // Four edges that don't make the document's shape: one is something else -
  // a line of print, a fold - and the other three may.
  for (final side in _Side.values) {
    final outline = _outline({...edges, side: null}, frame);
    if (outline != null) return outline;
  }
  return null;
}

/// The document whose [edges] these are, if they lie along [frame] and, all
/// four found, make its shape.
DocumentOutline? _outline(Map<_Side, Edge?> edges, Rect frame) {
  if (edges.values.where((edge) => edge == null).length > 1) return null;

  // Where each edge lies in the middle of its side, in the sample's pixels.
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
      position - side >= -size * edgeSearchInside && position - side <= size * edgeSearchOutside;
  final inFrame =
      along(-top, -frame.top, frame.height) &&
      along(bottom, frame.bottom, frame.height) &&
      along(-left, -frame.left, frame.width) &&
      along(right, frame.right, frame.width);
  if (!inFrame) return null;
  if (edges.values.every((edge) => edge != null) &&
      (((right - left) / (bottom - top)) / ratio - 1).abs() > maxShapeError) {
    return null;
  }
  return DocumentOutline(
    area: Rect.fromLTRB(left, top, right, bottom),
    top: edges[_Side.top],
    bottom: edges[_Side.bottom],
    left: edges[_Side.left],
    right: edges[_Side.right],
  );
}

/// The edge of the document along [side] of [frame] in [sample], or null when
/// none is found there.
Edge? _findEdge(DocumentSample sample, Rect frame, _Side side) {
  final horizontal = side == _Side.top || side == _Side.bottom;
  final length = horizontal ? frame.width : frame.height;
  final across = horizontal ? frame.height : frame.width;
  final start = (horizontal ? frame.left : frame.top) + length * (1 - edgeSpan) / 2;
  final outside = (across * edgeSearchFar).round();
  final inside = (across * edgeSearchInside).round();
  const reach = edgeGap + edgeWindow;

  final strip = length * edgeSpan / edgeProfiles;
  // The mean brightness at [depth] inside the side over the strip from
  // [from] to [to] along it.
  int at(int from, int to, int depth) {
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

  final centre = start + length * edgeSpan / 2;
  final points = <_EdgePoint>[];
  final profile = List.filled(outside + inside + 2 * reach + 1, 0);
  // Running sums of the profile, for the means of its windows.
  final sums = List.filled(profile.length + 1, 0);
  int sum(int from, int to) => sums[to] - sums[from];
  for (var p = 0; p < edgeProfiles; p++) {
    final from = (start + strip * p).round();
    final to = math.max(from + 1, (start + strip * (p + 1)).round());
    final along = (from + to) ~/ 2;
    for (var i = 0; i < profile.length; i++) {
      profile[i] = at(from, to, i - outside - reach);
      sums[i + 1] = sums[i] + profile[i];
    }
    final steps = [
      for (var d = -outside; d <= inside; d++)
        (sum(d + outside + reach + edgeGap, d + outside + 2 * reach) -
                sum(d + outside, d + outside + reach - edgeGap)) /
            edgeWindow,
    ];
    for (var j = 0; j < steps.length; j++) {
      final step = steps[j].abs();
      if (step < minEdgeStep) continue;
      var peak = true;
      for (var k = math.max(0, j - edgeGap); k <= math.min(steps.length - 1, j + edgeGap) && peak; k++) {
        // On a tie, the outermost depth is the peak.
        peak = k == j || steps[k].abs() < step || (steps[k].abs() == step && k > j);
      }
      if (!peak) continue;
      final out = profile.sublist(j, j + edgeWindow);
      if (out.reduce(math.max) - out.reduce(math.min) > math.max(maxFlatRange, step * maxFlatShare)) continue;
      points.add((profile: p, along: along - centre, depth: (j - outside).toDouble(), rising: steps[j] > 0));
    }
  }
  final edge = _fitEdge(points);
  return edge == null ? null : (slope: edge.slope, offset: edge.offset - edge.slope * centre);
}

/// A step found along one of a side's lines across it, [profile]: [along]
/// the side from its middle, at [depth] inside it, [rising] in brightness
/// going in.
typedef _EdgePoint = ({int profile, double along, double depth, bool rising});

/// The outermost straight line through at least [minEdgeInliers] of the
/// [edgeProfiles], each with a point within [edgeTolerance] of it, all
/// stepping the same way; refitted to those points. Null when there is none.
Edge? _fitEdge(List<_EdgePoint> points) {
  final needed = (edgeProfiles * minEdgeInliers).ceil();
  // The profiles with a point within edgeTolerance of the line.
  int support(List<_EdgePoint> on) => on.map((point) => point.profile).toSet().length;

  ({double slope, double offset, int support})? best;
  for (final rising in [true, false]) {
    final candidates = [
      for (final point in points)
        if (point.rising == rising) point,
    ];
    if (support(candidates) < needed) continue;
    for (var s = -maxEdgeSlope; s <= maxEdgeSlope + 1e-9; s += 0.01) {
      final offsets = [for (final point in candidates) (point.depth - s * point.along, point.profile)]
        ..sort((a, b) => a.$1.compareTo(b.$1));
      var from = 0;
      for (var to = 0; to < offsets.length; to++) {
        while (offsets[to].$1 - offsets[from].$1 > 2 * edgeTolerance) {
          from++;
        }
        final profiles = {for (var i = from; i <= to; i++) offsets[i].$2}.length;
        if (profiles < needed) continue;
        final offset = (offsets[from].$1 + offsets[to].$1) / 2;
        final current = best;
        // Outermost first; of lines about as far out, the one most profiles lie on.
        if (current == null ||
            offset < current.offset - 2 * edgeTolerance ||
            (offset <= current.offset + 2 * edgeTolerance && profiles > current.support)) {
          best = (slope: s, offset: offset, support: profiles);
        }
      }
    }
  }
  if (best == null) return null;

  // Refitted to the points on it, least squares.
  Edge edge = (slope: best.slope, offset: best.offset);
  for (var pass = 0; pass < 2; pass++) {
    final fit = edge;
    final inliers = [
      for (final point in points)
        if ((point.depth - (fit.offset + fit.slope * point.along)).abs() <= edgeTolerance) point,
    ];
    if (support(inliers) < needed) return pass == 0 ? null : fit;
    final n = inliers.length;
    final meanA = inliers.map((p) => p.along).reduce((a, b) => a + b) / n;
    final meanD = inliers.map((p) => p.depth).reduce((a, b) => a + b) / n;
    var covariance = 0.0;
    var variance = 0.0;
    for (final point in inliers) {
      covariance += (point.along - meanA) * (point.depth - meanD);
      variance += (point.along - meanA) * (point.along - meanA);
    }
    final slope = variance == 0 ? 0.0 : (covariance / variance).clamp(-maxEdgeSlope, maxEdgeSlope);
    edge = (slope: slope, offset: meanD - slope * meanA);
  }
  return edge;
}

/// Checks preview frames ([checkFrame]) on a background isolate of its own,
/// every one in the order they come, so checking never holds up the UI and no
/// frame is skipped. One isolate for all of them: spawning one per frame
/// would cost more than the check.
class DocumentFrameChecker {
  DocumentFrameChecker._(this._isolate, this._replies, this._requests);

  final Isolate _isolate;
  final ReceivePort _replies;
  final SendPort _requests;
  final _pending = Queue<Completer<Set<DocumentPhotoIssue>>>();

  /// Starts the isolate.
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

  /// [checkFrame] on the isolate. The frame's bytes are handed over without
  /// being copied again there.
  Future<Set<DocumentPhotoIssue>> check(
    LumaFrame frame, {
    required int rotation,
    required Rect region,
    String? dumpTo,
  }) {
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
      dumpTo: dumpTo,
    ));
    return pending.future;
  }

  /// Stops the isolate; frames still being checked fail.
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
        final (sample, inSample) = sampleFrame(
          frame,
          rotation: r.rotation,
          region: Rect.fromLTRB(r.region.$1, r.region.$2, r.region.$3, r.region.$4),
        );
        final issues = documentPhotoIssues(sample, frame: inSample);
        final dumpTo = r.dumpTo;
        if (dumpTo != null) _dump(dumpTo, sample, inSample, issues);
        replies.send(issues);
      } catch (e) {
        replies.send('$e');
      }
    });
  }
}

/// Writes [sample] to [path] as a grayscale PGM image, with where the frame
/// lies in it and the [issues] found in a comment, to check the detection
/// against real camera frames.
void _dump(String path, DocumentSample sample, Rect frame, Set<DocumentPhotoIssue> issues) {
  final header =
      'P5\n'
      '# frame ${frame.left} ${frame.top} ${frame.right} ${frame.bottom}\n'
      '# issues ${issues.map((issue) => issue.name).join(' ')}\n'
      '${sample.width} ${sample.height}\n255\n';
  File(path).writeAsBytesSync([...ascii.encode(header), ...sample.pixels]);
}

/// A frame to check, as [DocumentFrameChecker] sends it to its isolate.
typedef _FrameRequest = ({
  TransferableTypedData bytes,
  int width,
  int height,
  int bytesPerRow,
  bool bgra,
  int rotation,
  (double, double, double, double) region,
  String? dumpTo,
});

/// The brightness [paperPercentile] of [sample]'s pixels stay below: that of
/// its paper, not its text.
int paperBrightness(DocumentSample sample) {
  if (sample.pixels.isEmpty) return 0;
  final histogram = List.filled(256, 0);
  for (final p in sample.pixels) {
    histogram[p]++;
  }
  final below = (sample.pixels.length * paperPercentile).floor();
  var seen = 0;
  for (var b = 0; b < 256; b++) {
    seen += histogram[b];
    if (seen > below) return b;
  }
  return 255;
}

/// The histogram of each tile of [document] in a [glareColumns] x [glareRows]
/// grid: how many of its pixels have each of the 256 brightness levels.
List<List<int>> _tileHistograms(DocumentSample document) {
  final columns = math.max(1, math.min(glareColumns, document.width));
  final rows = math.max(1, math.min(glareRows, document.height));
  final histograms = List.generate(columns * rows, (_) => List.filled(256, 0));
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

/// The brightness [share] of the pixels in [histogram] stay below.
int _percentile(List<int> histogram, double share) {
  final count = histogram.reduce((a, b) => a + b);
  final below = math.min(count - 1, (count * share).floor());
  var seen = 0;
  for (var b = 0; b < 256; b++) {
    seen += histogram[b];
    if (seen > below) return b;
  }
  return 255;
}

/// Whether the tile of [histogram] has more than [glareTileShare] pixels at
/// or above [brightness].
bool _glaring(List<int> histogram, [int brightness = clippedBrightness]) {
  var bright = 0;
  for (var b = brightness; b < 256; b++) {
    bright += histogram[b];
  }
  return bright / histogram.reduce((a, b) => a + b) > glareTileShare;
}

/// Whether a tile of [document] has more than [glareTileShare] clipped pixels.
bool hasGlare(DocumentSample document) => _tileHistograms(document).any(_glaring);

/// Whether a reflection just short of clipping lies on part of [document]
/// (see [nearClippedBrightness]): only where there is no glare, which
/// [hasGlare] tells already.
bool hasReflection(DocumentSample document) {
  final histograms = _tileHistograms(document);
  if (histograms.isEmpty) return false;
  final papers = [for (final histogram in histograms) _percentile(histogram, paperPercentile)]..sort();
  if (papers[papers.length ~/ 2] > nearClippedBrightness - reflectionContrast) return false;
  return histograms.any((histogram) => !_glaring(histogram) && _glaring(histogram, nearClippedBrightness));
}

/// The variance of the Laplacian over [sample]'s sharpest quarter of tiles:
/// high for sharp edges, low once a blur smooths them out. Only the sharpest
/// tiles count, where text is printed: a document's plain background has no
/// edges to blur, and how much of it there is says nothing about focus. Nor
/// does glare: the edge of a reflection is no sign of focus, so no pixel next
/// to a clipped one counts.
double sharpness(DocumentSample sample) {
  final w = sample.width;
  final h = sample.height;
  if (w < 3 || h < 3) return 0;
  final columns = tileColumns.clamp(1, w - 2);
  final rows = tileRows.clamp(1, h - 2);
  final sums = List.filled(columns * rows, 0.0);
  final sumsOfSquares = List.filled(columns * rows, 0.0);
  final counts = List.filled(columns * rows, 0);
  final p = sample.pixels;
  for (var y = 1; y < h - 1; y++) {
    final row = (y - 1) * rows ~/ (h - 2);
    for (var x = 1; x < w - 1; x++) {
      final tile = row * columns + (x - 1) * columns ~/ (w - 2);
      final i = y * w + x;
      if (math.max(math.max(p[i], math.max(p[i - 1], p[i + 1])), math.max(p[i - w], p[i + w])) >= clippedBrightness) {
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
  // Glare over the whole document: nothing to tell focus by, and glare says enough.
  if (variances.isEmpty) return double.infinity;
  final sharpest = variances.take(math.max(1, variances.length ~/ 4));
  return sharpest.reduce((a, b) => a + b) / sharpest.length;
}

/// Decides, from the issues of the latest preview frames, which issue to show
/// and whether the photo may be taken.
///
/// Whether there is a document, and each of [documentChecks], settles on its
/// own: once [framesToAgree] of its last [windowFrames] frames agree - about
/// a fifth of a second of a 30 fps preview - so a few frames never flip it
/// and the hint doesn't flicker while the document moves. A check only counts frames with a document, and starts afresh once
/// the document is gone: a new placement is measured anew. The photo may be
/// taken once the document is there and every check has settled on passing.
class DocumentPhotoQuality {
  static const windowFrames = 9;
  static const framesToAgree = 6;

  /// Why the latest frames had no document, each, or null when they had one:
  /// glare or a reflection over the frame, too dark, or none there.
  final _presence = <DocumentPhotoIssue?>[];
  var _documentFound = false;
  DocumentPhotoIssue? _absence;

  /// Whether each check failed, on the latest frames with a document.
  final _results = {for (final check in documentChecks) check: <bool>[]};
  final _failing = <DocumentPhotoIssue>{};

  /// The issue to tell the user about, if any.
  DocumentPhotoIssue? get issue {
    if (!_documentFound) return _absence;
    for (final check in documentChecks) {
      if (_failing.contains(check)) return check;
    }
    return null;
  }

  /// Whether the latest frames were readable.
  bool get clear =>
      _documentFound &&
      _failing.isEmpty &&
      documentChecks.every((check) => _results[check]!.where((failed) => !failed).length >= framesToAgree);

  /// Records the issues of the latest frame (see [documentPhotoIssues]) and
  /// returns whether [issue] or [clear] changed.
  bool update(Set<DocumentPhotoIssue> frameIssues) {
    final before = (issue, clear);
    // Without a document, glare over the frame is why, before the rest.
    final absence = frameIssues.contains(DocumentPhotoIssue.tooDark)
        ? DocumentPhotoIssue.tooDark
        : !frameIssues.contains(DocumentPhotoIssue.noDocument)
        ? null
        : frameIssues.contains(DocumentPhotoIssue.glare)
        ? DocumentPhotoIssue.glare
        : frameIssues.contains(DocumentPhotoIssue.reflection)
        ? DocumentPhotoIssue.reflection
        : DocumentPhotoIssue.noDocument;
    _push(_presence, absence);
    for (final candidate in _presence.toSet()) {
      if (_presence.where((a) => a == candidate).length < framesToAgree) continue;
      final wasFound = _documentFound;
      _documentFound = candidate == null;
      _absence = candidate;
      if (wasFound && !_documentFound) {
        for (final results in _results.values) {
          results.clear();
        }
        _failing.clear();
      }
    }
    if (absence == null) {
      for (final check in documentChecks) {
        final results = _push(_results[check]!, frameIssues.contains(check));
        final failed = results.where((f) => f).length;
        if (failed >= framesToAgree) {
          _failing.add(check);
        } else if (results.length - failed >= framesToAgree) {
          _failing.remove(check);
        }
      }
    }
    return before != (issue, clear);
  }

  /// Adds [value] to [window], dropping its oldest beyond [windowFrames].
  static List<T> _push<T>(List<T> window, T value) {
    window.add(value);
    if (window.length > windowFrames) window.removeAt(0);
    return window;
  }

  /// Forgets the frames seen so far. Call this whenever the camera (re)opens.
  void reset() {
    _presence.clear();
    _documentFound = false;
    _absence = null;
    for (final results in _results.values) {
      results.clear();
    }
    _failing.clear();
  }
}
