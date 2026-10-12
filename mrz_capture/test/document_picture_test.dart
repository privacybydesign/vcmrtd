import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';

DocumentPicture _picture(Rect frame, {double previewAspectRatio = 9 / 16}) =>
    DocumentPicture(jpeg: Uint8List(0), frame: frame, previewAspectRatio: previewAspectRatio);

void main() {
  group('DocumentPicture.frameInPreview', () {
    test('gives the frame as fractions of the preview', () {
      final frame = DocumentPicture.frameInPreview(
        const Rect.fromLTWH(20, 300, 360, 200),
        const Rect.fromLTWH(0, 100, 400, 800),
      );
      expect(frame, const Rect.fromLTRB(0.05, 0.25, 0.95, 0.5));
    });

    test('clamps a frame reaching past the preview to it', () {
      final frame = DocumentPicture.frameInPreview(
        const Rect.fromLTWH(-40, 0, 480, 200),
        const Rect.fromLTWH(0, 100, 400, 800),
      );
      expect(frame, const Rect.fromLTRB(0, 0, 1, 0.125));
    });
  });

  group('DocumentPicture.cropIn', () {
    test('a picture shaped like the preview keeps the frame, widened by the margin on every side', () {
      // 900x1600 is 9:16, like the preview.
      final crop = _picture(const Rect.fromLTRB(0.1, 0.4, 0.9, 0.6)).cropIn(900, 1600);
      const m = DocumentPicture.frameMargin;
      expect(crop.left, closeTo((0.1 - 0.8 * m) * 900, 1));
      expect(crop.right, closeTo((0.9 + 0.8 * m) * 900, 1));
      expect(crop.top, closeTo((0.4 - 0.2 * m) * 1600, 1));
      expect(crop.bottom, closeTo((0.6 + 0.2 * m) * 1600, 1));
    });

    test('a 3:4 photo taken while a 9:16 preview showed shares the long side and narrows across it', () {
      // The 9:16 preview covers the middle 75% of a 3:4 photo's width.
      final crop = _picture(const Rect.fromLTRB(0, 0.4, 1, 0.6)).cropIn(1200, 1600);
      const m = DocumentPicture.frameMargin;
      expect(crop.left, closeTo((0.125 - 0.75 * m) * 1200, 1));
      expect(crop.right, closeTo((0.875 + 0.75 * m) * 1200, 1));
      expect(crop.top, closeTo((0.4 - 0.2 * m) * 1600, 1));
    });

    test('never reaches outside the picture', () {
      final crop = _picture(const Rect.fromLTRB(0, 0, 1, 1)).cropIn(900, 1600);
      expect(crop, const Rect.fromLTRB(0, 0, 900, 1600));
    });

    test('a landscape picture maps across its short, vertical side', () {
      final crop = _picture(const Rect.fromLTRB(0.4, 0, 0.6, 1)).cropIn(1600, 1200);
      const m = DocumentPicture.frameMargin;
      expect(crop.top, closeTo((0.125 - 0.75 * m) * 1200, 1));
      expect(crop.bottom, closeTo((0.875 + 0.75 * m) * 1200, 1));
      expect(crop.left, closeTo((0.4 - 0.2 * m) * 1600, 1));
    });
  });
}
