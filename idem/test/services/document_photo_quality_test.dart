import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_photo_quality.dart';

/// A [width] x [height] sample, each pixel [pixel] of its position.
DocumentSample _sample(int width, int height, int Function(int x, int y) pixel) {
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      pixels[y * width + x] = pixel(x, y);
    }
  }
  return DocumentSample(pixels, width, height);
}

/// Dark "text" strokes on a light card: sharp, readable.
int _printed(int x, int y) => (x ~/ 3 + y ~/ 4).isEven ? 200 : 40;

void main() {
  group('assessDocument', () {
    test('a sharp, well-lit document has no issue', () {
      expect(assessDocument(_sample(160, 100, _printed)), isNull);
    });

    test('a dark document is too dark', () {
      expect(assessDocument(_sample(160, 100, (x, y) => _printed(x, y) ~/ 5)), DocumentPhotoIssue.tooDark);
    });

    test('a reflection over part of the document is glare', () {
      // One tile (160/8 x 100/5 = 20 x 20) washed out.
      expect(
        assessDocument(_sample(160, 100, (x, y) => x < 20 && y < 20 ? 255 : _printed(x, y))),
        DocumentPhotoIssue.glare,
      );
    });

    test('a few clipped pixels are not glare', () {
      expect(assessDocument(_sample(160, 100, (x, y) => x < 2 && y < 2 ? 255 : _printed(x, y))), isNull);
    });

    test('a document without edges is blurry', () {
      // Light that changes smoothly across the card, like text blurred away.
      expect(assessDocument(_sample(160, 100, (x, y) => 100 + x ~/ 4)), DocumentPhotoIssue.blurry);
    });

    test('darkness wins over blur and glare', () {
      expect(assessDocument(_sample(160, 100, (x, y) => 10)), DocumentPhotoIssue.tooDark);
    });
  });

  group('sampleDocument', () {
    test('turns a sideways sensor frame upright', () {
      // A 3 x 2 landscape sensor frame, pixels numbered row by row.
      final frame = LumaFrame.luma(bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]), width: 3, height: 2, bytesPerRow: 3);
      final sample = sampleDocument(frame, rotation: 90, region: const Rect.fromLTRB(0, 0, 1, 1));
      // Rotated clockwise into a 2 x 3 portrait.
      expect((sample.width, sample.height), (2, 3));
      expect(sample.pixels, [3, 0, 4, 1, 5, 2]);
    });

    test('takes only the region, at most maxWidth across', () {
      final frame = LumaFrame.luma(
        bytes: Uint8List.fromList(List.generate(100 * 100, (i) => i % 100 < 50 ? 0 : 200)),
        width: 100,
        height: 100,
        bytesPerRow: 100,
      );
      final sample = sampleDocument(frame, rotation: 0, region: const Rect.fromLTRB(0.5, 0, 1, 0.5), maxWidth: 10);
      expect((sample.width, sample.height), (10, 10));
      expect(sample.pixels.every((p) => p == 200), isTrue);
    });

    test('reads the brightness of BGRA frames', () {
      final frame = LumaFrame.bgra(
        bytes: Uint8List.fromList([255, 255, 255, 255, 0, 0, 0, 255]),
        width: 2,
        height: 1,
        bytesPerRow: 8,
      );
      expect(sampleDocument(frame, rotation: 0, region: const Rect.fromLTRB(0, 0, 1, 1)).pixels, [255, 0]);
    });
  });

  test('assessFrameInBackground checks the frame like assessDocument does', () async {
    final frame = LumaFrame.luma(
      bytes: Uint8List.fromList(List.generate(200 * 120, (i) => i % 200 < 20 && i < 200 * 24 ? 255 : 120)),
      width: 200,
      height: 120,
      bytesPerRow: 200,
    );
    const region = Rect.fromLTRB(0, 0, 1, 1);
    expect(
      await assessFrameInBackground(frame, rotation: 0, region: region),
      assessDocument(sampleDocument(frame, rotation: 0, region: region)),
    );
    expect(await assessFrameInBackground(frame, rotation: 0, region: region), DocumentPhotoIssue.glare);
  });

  group('DocumentPhotoQuality', () {
    test('is neither clear nor showing an issue before two frames agree', () {
      final quality = DocumentPhotoQuality();
      quality.update(null);
      expect((quality.clear, quality.issue), (false, null));
      quality.update(null);
      expect((quality.clear, quality.issue), (true, null));
    });

    test('a single frame does not flip it', () {
      final quality = DocumentPhotoQuality()
        ..update(null)
        ..update(null);
      quality.update(DocumentPhotoIssue.glare);
      expect(quality.clear, isTrue);
      quality.update(DocumentPhotoIssue.glare);
      expect((quality.clear, quality.issue), (false, DocumentPhotoIssue.glare));
      quality.update(null);
      expect(quality.issue, DocumentPhotoIssue.glare);
      quality.update(null);
      expect((quality.clear, quality.issue), (true, null));
    });

    test('reports whether anything changed', () {
      final quality = DocumentPhotoQuality();
      expect(quality.update(DocumentPhotoIssue.tooDark), isFalse);
      expect(quality.update(DocumentPhotoIssue.tooDark), isTrue);
      expect(quality.update(DocumentPhotoIssue.tooDark), isFalse);
    });

    test('reset forgets the frames', () {
      final quality = DocumentPhotoQuality()
        ..update(null)
        ..update(null)
        ..reset();
      expect((quality.clear, quality.issue), (false, null));
    });
  });
}
