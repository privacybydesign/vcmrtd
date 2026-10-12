import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

// The document photo is read by people and software at the relying party, and,
// unlike an MRZ, it has no check digits that reject a bad read: whatever the
// camera sees when the user takes it is what gets sent. So the preview frames are
// checked for the three things that make printed text unreadable - a reflection
// washing part of it out, too little light, and blur - and the photo can only be
// taken once they pass.
//
// The thresholds are starting points: glare's comes from the MRZ scanner in the
// Yivi app (measured on the MRZ strip only), the darkness and sharpness ones are
// not measured on devices yet.

/// What keeps a camera frame from giving a readable document photo.
enum DocumentPhotoIssue { glare, tooDark, blurry }

/// Pixels at or above this brightness count as clipped: a reflection.
const clippedBrightness = 250;

/// A tile of the document with more than this share of clipped pixels has a
/// reflection on it.
const glareTileShare = 0.10;

/// The document is split into this grid of tiles for glare: a reflection usually
/// covers part of it, which a measurement over the whole document would average
/// away.
const glareTileColumns = 8;
const glareTileRows = 5;

/// Below this mean brightness (0-255) the document is too dark to read.
const tooDarkMeanBrightness = 60;

/// Below this variance of the Laplacian the document is blurred: sharp printed
/// text has strong edges, which a blur smooths out.
const minSharpness = 60.0;

/// The frame is sampled down to at most this many pixels across the document
/// before it is checked: enough to tell sharp text from blurred.
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
}

/// Samples [region] of [frame] into an upright [DocumentSample] at most
/// [maxWidth] pixels wide.
///
/// [rotation] is the clockwise rotation in degrees that turns the frame upright,
/// and [region] is the document frame as fractions of the upright frame's width
/// and height.
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
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final uy = (top + (y + 0.5) * step).floor().clamp(0, uprightHeight - 1);
    for (var x = 0; x < width; x++) {
      final ux = (left + (x + 0.5) * step).floor().clamp(0, uprightWidth - 1);
      // Upright (ux, uy) back to the sensor frame, undoing the clockwise rotation.
      final (sx, sy) = switch (rotation) {
        90 => (uy, frame.height - 1 - ux),
        180 => (frame.width - 1 - ux, frame.height - 1 - uy),
        270 => (frame.width - 1 - uy, ux),
        _ => (ux, uy),
      };
      pixels[y * width + x] = frame.brightnessAt(sx, sy);
    }
  }
  return DocumentSample(pixels, width, height);
}

/// [sampleDocument] and [assessDocument] on a background isolate, so checking
/// a frame never holds up the UI.
Future<DocumentPhotoIssue?> assessFrameInBackground(LumaFrame frame, {required int rotation, required Rect region}) =>
    Isolate.run(() => assessDocument(sampleDocument(frame, rotation: rotation, region: region)));

/// The issue that most keeps [sample] from being readable, or null when it has
/// none. Darkness comes first: a dark frame is noisy, which hides both a
/// reflection and a blur.
DocumentPhotoIssue? assessDocument(DocumentSample sample) {
  if (meanBrightness(sample) < tooDarkMeanBrightness) return DocumentPhotoIssue.tooDark;
  if (hasGlare(sample)) return DocumentPhotoIssue.glare;
  if (sharpness(sample) < minSharpness) return DocumentPhotoIssue.blurry;
  return null;
}

double meanBrightness(DocumentSample sample) {
  var sum = 0;
  for (final p in sample.pixels) {
    sum += p;
  }
  return sample.pixels.isEmpty ? 0 : sum / sample.pixels.length;
}

/// Whether a tile of [sample] has more than [glareTileShare] clipped pixels.
bool hasGlare(DocumentSample sample) {
  final columns = glareTileColumns.clamp(1, sample.width);
  final rows = glareTileRows.clamp(1, sample.height);
  final clipped = List.filled(columns * rows, 0);
  final counted = List.filled(columns * rows, 0);
  for (var y = 0; y < sample.height; y++) {
    final row = y * rows ~/ sample.height;
    for (var x = 0; x < sample.width; x++) {
      final tile = row * columns + x * columns ~/ sample.width;
      counted[tile]++;
      if (sample.pixels[y * sample.width + x] >= clippedBrightness) clipped[tile]++;
    }
  }
  for (var t = 0; t < clipped.length; t++) {
    if (counted[t] > 0 && clipped[t] / counted[t] > glareTileShare) return true;
  }
  return false;
}

/// The variance of the Laplacian over [sample]: high for sharp edges, low once
/// a blur smooths them out.
double sharpness(DocumentSample sample) {
  final w = sample.width;
  final h = sample.height;
  if (w < 3 || h < 3) return 0;
  final p = sample.pixels;
  var sum = 0.0;
  var sumOfSquares = 0.0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final laplacian = p[i - w] + p[i + w] + p[i - 1] + p[i + 1] - 4 * p[i];
      sum += laplacian;
      sumOfSquares += laplacian * laplacian;
    }
  }
  final n = (w - 2) * (h - 2);
  final mean = sum / n;
  return sumOfSquares / n - mean * mean;
}

/// Decides, from the issues of the latest preview frames, which issue to show and
/// whether the photo may be taken. An issue shows once [_framesToAgree] of the
/// last [_windowFrames] frames had it, and the photo may be taken once that many
/// had none: a single frame does not flip it, so the hint does not flicker while
/// the document moves.
class DocumentPhotoQuality {
  static const _windowFrames = 3;
  static const _framesToAgree = 2;

  final _recent = <DocumentPhotoIssue?>[];
  DocumentPhotoIssue? _issue;
  var _clear = false;

  /// The issue to tell the user about, if any.
  DocumentPhotoIssue? get issue => _issue;

  /// Whether the latest frames were readable.
  bool get clear => _clear;

  /// Records the issue of the latest frame (null: none) and returns whether
  /// [issue] or [clear] changed.
  bool update(DocumentPhotoIssue? frameIssue) {
    _recent.add(frameIssue);
    if (_recent.length > _windowFrames) _recent.removeAt(0);
    final before = (_issue, _clear);
    for (final candidate in _recent.toSet()) {
      if (_recent.where((i) => i == candidate).length < _framesToAgree) continue;
      _issue = candidate;
      _clear = candidate == null;
    }
    return before != (_issue, _clear);
  }

  /// Forgets the frames seen so far. Call this whenever the camera (re)opens.
  void reset() {
    _recent.clear();
    _issue = null;
    _clear = false;
  }
}
