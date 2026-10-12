import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A picture of a document taken with the camera, and where the on-screen
/// document frame lay in the camera's live preview when it was taken - so the
/// picture can be cut down to the document instead of the whole camera view.
class DocumentPicture {
  const DocumentPicture({required this.jpeg, required this.frame, required this.previewAspectRatio});

  /// The camera's picture, as it took it (JPEG, EXIF orientation included).
  final Uint8List jpeg;

  /// The document frame, as fractions of the upright preview's width and
  /// height.
  final Rect frame;

  /// The upright preview's width / height.
  final double previewAspectRatio;

  /// How far [cropIn] widens the frame on every side, as a fraction of the
  /// frame's own size: a document is never placed exactly inside it, and the
  /// picture's field of view is only derived from the preview's.
  static const frameMargin = 0.08;

  /// Where [frame] lies in [preview], both in screen coordinates, as
  /// fractions of [preview] - clamped to it.
  static Rect frameInPreview(Rect frame, Rect preview) {
    final visible = frame.intersect(preview);
    final f = visible.isEmpty ? preview : visible;
    return Rect.fromLTRB(
      ((f.left - preview.left) / preview.width).clamp(0.0, 1.0),
      ((f.top - preview.top) / preview.height).clamp(0.0, 1.0),
      ((f.right - preview.left) / preview.width).clamp(0.0, 1.0),
      ((f.bottom - preview.top) / preview.height).clamp(0.0, 1.0),
    );
  }

  /// The part of the upright picture, [width] x [height] pixels, to keep:
  /// [frame] widened by [frameMargin], mapped from the preview onto the
  /// picture.
  ///
  /// The preview and the picture can differ in aspect ratio (a 16:9 stream,
  /// a 4:3 photo). Both are taken as the largest centred crop of the same
  /// 4:3-or-narrower sensor, so they share its long side: along it the
  /// fractions carry over as they are, across it they scale about the centre
  /// by the ratio of the two short sides.
  Rect cropIn(int width, int height) {
    double shortOverLong(double w, double h) => math.min(w, h) / math.max(w, h);
    final previewShortOverLong = shortOverLong(previewAspectRatio, 1);
    final pictureShortOverLong = shortOverLong(width.toDouble(), height.toDouble());
    final scale = previewShortOverLong / pictureShortOverLong;
    double across(double f) => (0.5 + (f - 0.5) * scale).clamp(0.0, 1.0);

    final portrait = height >= width;
    final mapped = portrait
        ? Rect.fromLTRB(across(frame.left), frame.top, across(frame.right), frame.bottom)
        : Rect.fromLTRB(frame.left, across(frame.top), frame.right, across(frame.bottom));
    final widened = Rect.fromLTRB(
      (mapped.left - mapped.width * frameMargin).clamp(0.0, 1.0),
      (mapped.top - mapped.height * frameMargin).clamp(0.0, 1.0),
      (mapped.right + mapped.width * frameMargin).clamp(0.0, 1.0),
      (mapped.bottom + mapped.height * frameMargin).clamp(0.0, 1.0),
    );
    return Rect.fromLTRB(
      (widened.left * width).floorToDouble(),
      (widened.top * height).floorToDouble(),
      (widened.right * width).ceilToDouble(),
      (widened.bottom * height).ceilToDouble(),
    );
  }
}
