import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_photo_quality.dart';

const _frame = Rect.fromLTWH(26, 17, 320, 202);
const _sceneWidth = 372;
const _sceneHeight = 236;

int _printed(int x, int y) {
  final u = (x - _frame.left) / _frame.width;
  final v = (y - _frame.top) / _frame.height;
  final onLine = u >= 0.08 && u < 0.92 && [0.15, 0.35, 0.55, 0.75].any((top) => v >= top && v < top + 0.06);
  return onLine && (x ~/ 2 + y ~/ 3).isEven ? 40 : 200;
}

DocumentSample _scene({
  bool Function(int x, int y)? onCard,
  int Function(int x, int y, int printed)? card,
  int Function(int x, int y)? table,
}) {
  final pixels = Uint8List(_sceneWidth * _sceneHeight);
  for (var y = 0; y < _sceneHeight; y++) {
    for (var x = 0; x < _sceneWidth; x++) {
      final isCard = onCard?.call(x, y) ?? _frame.contains(Offset(x + 0.5, y + 0.5));
      pixels[y * _sceneWidth + x] = isCard
          ? (card?.call(x, y, _printed(x, y)) ?? _printed(x, y)).clamp(0, 255)
          : (table?.call(x, y) ?? 60);
    }
  }
  return DocumentSample(pixels, _sceneWidth, _sceneHeight);
}

Set<DocumentPhotoIssue> _issues(DocumentSample sample) => documentPhotoIssues(sample, frame: _frame);

int _hazed(int pixel) => pixel + ((255 - pixel) * 0.85).round();

bool Function(int, int) _in(Rect area) =>
    (x, y) => area.contains(Offset(x + 0.5, y + 0.5));

/// Blurred edges, sharpening halo and sensor noise, as a phone camera shows it.
DocumentSample _camera(DocumentSample sample, {int blur = 1}) {
  final w = sample.width;
  final h = sample.height;
  int at(Uint8List p, int x, int y) => p[y.clamp(0, h - 1) * w + x.clamp(0, w - 1)];
  Uint8List box(Uint8List p, int r) {
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0;
        for (var dy = -r; dy <= r; dy++) {
          for (var dx = -r; dx <= r; dx++) {
            sum += at(p, x + dx, y + dy);
          }
        }
        out[y * w + x] = sum ~/ ((2 * r + 1) * (2 * r + 1));
      }
    }
    return out;
  }

  final blurred = box(sample.pixels, blur);
  final wide = box(blurred, 2);
  final random = math.Random(7);
  return DocumentSample(
    Uint8List.fromList([
      for (var i = 0; i < w * h; i++)
        (blurred[i] + 1.2 * (blurred[i] - wide[i]) + random.nextInt(13) - 6).round().clamp(0, 255),
    ]),
    w,
    h,
  );
}

int _guilloche(int x, int y, int printed) =>
    printed == 200 ? 200 + (14 * math.sin(x / 1.7 + 3 * math.sin(y / 11))).round() : printed;

void main() {
  group('the document in the frame', () {
    test('a card lying in the frame is found, with no issues', () {
      expect(_issues(_scene()), isEmpty);
    });

    test('a card as a phone camera shows it is found: blurred, sharpened, noisy, printed to its edges', () {
      expect(_issues(_camera(_scene())), isEmpty);
      expect(_issues(_camera(_scene(card: _guilloche))), isEmpty);
      expect(_issues(_camera(_scene(card: _guilloche, table: (x, y) => 20), blur: 2)), isEmpty);
      expect(_issues(_camera(_scene(card: _guilloche, table: (x, y) => 120 + (x * 7 + y * 13) % 17))), isEmpty);
      expect(_issues(_camera(_scene(onCard: _in(_frame.shift(const Offset(8, -6))), card: _guilloche))), isEmpty);
    });

    test('nothing in the frame as a phone camera shows it is still no document', () {
      expect(_issues(_camera(_scene(onCard: (x, y) => false))), {DocumentPhotoIssue.noDocument});
      expect(_issues(_camera(_scene(onCard: _in(_frame.shift(const Offset(48, 0))), card: _guilloche))), {
        DocumentPhotoIssue.noDocument,
      });
    });

    test('a card a little off the frame is found', () {
      expect(_issues(_scene(onCard: _in(_frame.shift(const Offset(8, -6))))), isEmpty);
      expect(_issues(_scene(onCard: _in(_frame.deflate(12)))), isEmpty);
    });

    test('an empty table is no document; a dark one, too dark', () {
      expect(_issues(_scene(onCard: (x, y) => false)), {DocumentPhotoIssue.noDocument});
      expect(_issues(_scene(onCard: (x, y) => false, table: (x, y) => 15)), {DocumentPhotoIssue.tooDark});
    });

    test('a card in the dark is too dark', () {
      expect(_issues(_scene(card: (x, y, printed) => printed ~/ 5, table: (x, y) => 12)), {DocumentPhotoIssue.tooDark});
    });

    test('a card partly outside the frame is no document', () {
      expect(_issues(_scene(onCard: _in(_frame.shift(const Offset(48, 0))))), {DocumentPhotoIssue.noDocument});
      expect(_issues(_scene(onCard: _in(_frame.shift(const Offset(0, -40))))), {DocumentPhotoIssue.noDocument});
    });

    test('a card far smaller than the frame is no document', () {
      expect(_issues(_scene(onCard: _in(Rect.fromCenter(center: _frame.center, width: 160, height: 101)))), {
        DocumentPhotoIssue.noDocument,
      });
    });

    test('a page of text filling the view is no document: it has no edges in the frame', () {
      expect(_issues(_scene(onCard: (x, y) => false, table: (x, y) => (y ~/ 6).isEven && (x ~/ 2).isEven ? 40 : 200)), {
        DocumentPhotoIssue.noDocument,
      });
    });

    test('a busy surface has no edges in the frame; a card that stands out on it does', () {
      int busy(int x, int y) => (x ~/ 3 + y ~/ 3).isEven ? 40 : 120;
      expect(_issues(_scene(onCard: (x, y) => false, table: busy)), {DocumentPhotoIssue.noDocument});
      expect(_issues(_camera(_scene(onCard: (x, y) => false, table: busy))), {DocumentPhotoIssue.noDocument});
      expect(_issues(_scene(table: busy)), isEmpty);
    });

    test('a white card on a white table is found: its print stands out where its edges do not', () {
      expect(_issues(_scene(table: (x, y) => 200)), isEmpty);
      expect(_issues(_scene(onCard: (x, y) => false, table: (x, y) => 200)), {DocumentPhotoIssue.noDocument});
    });

    test('a pale card on a white table is found, its edges a small step in brightness', () {
      expect(_issues(_camera(_scene(card: _guilloche, table: (x, y) => 216), blur: 2)), isEmpty);
    });

    test('one edge without contrast, like a passport page at its fold, is found by the frame shape', () {
      expect(_issues(_scene(table: (x, y) => y < _frame.top ? 200 : 60)), isEmpty);
    });

    test('a card whose edges have a shadow over part of it is found', () {
      expect(_issues(_scene(card: (x, y, printed) => x < 186 ? printed ~/ 2 : printed)), isEmpty);
    });
  });

  group('glare', () {
    test('a reflection over part of the document is glare', () {
      expect(_issues(_scene(card: (x, y, printed) => x >= 100 && x < 140 && y >= 80 && y < 110 ? 255 : printed)), {
        DocumentPhotoIssue.glare,
      });
    });

    test('a streak of reflection across the document is glare', () {
      // 4 of a tile's 19 pixels across: over 10% of it.
      expect(_issues(_scene(card: (x, y, printed) => x >= 150 && x < 154 ? 255 : printed)), {DocumentPhotoIssue.glare});
    });

    test('a few clipped pixels are not glare', () {
      expect(
        _issues(_scene(card: (x, y, printed) => x >= 150 && x < 152 && y >= 80 && y < 82 ? 255 : printed)),
        isEmpty,
      );
    });

    test('a bright table around the document is not glare', () {
      expect(_issues(_scene(table: (x, y) => 255)), isEmpty);
    });

    test('a reflection big enough to wash out the edges is glare, not no document', () {
      // Over two thirds of it from the left: its left, top and bottom edges are gone.
      expect(_issues(_scene(card: (x, y, printed) => x < 240 ? 255 : printed, table: (x, y) => x < 240 ? 255 : 60)), {
        DocumentPhotoIssue.noDocument,
        DocumentPhotoIssue.glare,
      });
    });
  });

  group('reflection', () {
    test('a reflection just short of clipping over part of the document is one', () {
      expect(
        _issues(_scene(card: (x, y, printed) => x >= 60 && x < 140 && y >= 40 && y < 90 ? _hazed(printed) : printed)),
        {DocumentPhotoIssue.reflection},
      );
    });

    test('a shadow over part of the document is none', () {
      expect(
        _issues(_scene(card: (x, y, printed) => x >= 60 && x < 140 && y >= 40 && y < 90 ? printed ~/ 2 : printed)),
        isEmpty,
      );
    });

    test('light that brightens one side of the document is none', () {
      expect(_issues(_scene(card: (x, y, printed) => printed + (x - 26) ~/ 8)), isEmpty);
    });

    test('a brightly lit document, its paper near white all over, is none', () {
      expect(_issues(_scene(card: (x, y, printed) => printed == 200 ? 246 : printed)), isEmpty);
    });
  });

  group('tilt', () {
    test('a document facing the camera at an angle, its far side smaller, is tilted', () {
      // The top edge 24 pixels shorter at each end than the bottom one: its
      // sides some 13 degrees apart.
      bool trapezoid(int x, int y) {
        final py = y + 0.5;
        if (py < _frame.top || py >= _frame.bottom) return false;
        final inset = 24 * (_frame.bottom - py) / _frame.height;
        return x + 0.5 >= _frame.left + inset && x + 0.5 < _frame.right - inset;
      }

      expect(_issues(_scene(onCard: trapezoid)), {DocumentPhotoIssue.tilted});
    });

    test('a document slightly tilted, as for a reflection, is not tilted', () {
      // Its sides some 4 degrees apart.
      bool trapezoid(int x, int y) {
        final py = y + 0.5;
        if (py < _frame.top || py >= _frame.bottom) return false;
        final inset = 7 * (_frame.bottom - py) / _frame.height;
        return x + 0.5 >= _frame.left + inset && x + 0.5 < _frame.right - inset;
      }

      expect(_issues(_scene(onCard: trapezoid)), isEmpty);
    });

    test('a document turned a little flat on the table is not tilted', () {
      const angle = 3 * math.pi / 180;
      bool turned(int x, int y) {
        final dx = x + 0.5 - _frame.center.dx;
        final dy = y + 0.5 - _frame.center.dy;
        final u = dx * math.cos(angle) + dy * math.sin(angle);
        final v = -dx * math.sin(angle) + dy * math.cos(angle);
        return u.abs() < _frame.width / 2 && v.abs() < _frame.height / 2;
      }

      expect(_issues(_scene(onCard: turned)), isEmpty);
    });
  });

  group('blur', () {
    int blurred(int x, int y, int printed) => 170 + (20 * math.sin(x / 9) * math.sin(y / 9)).round();

    test('a document without sharp print is blurry', () {
      expect(_issues(_scene(card: blurred)), {DocumentPhotoIssue.blurry});
    });

    test('every check is made on its own: glare does not hide blur, nor pass for sharp print', () {
      expect(
        _issues(
          _scene(card: (x, y, printed) => x >= 100 && x < 140 && y >= 80 && y < 110 ? 255 : blurred(x, y, printed)),
        ),
        {DocumentPhotoIssue.glare, DocumentPhotoIssue.blurry},
      );
    });
  });

  group('readable text', () {
    const region = Rect.fromLTRB(0.1, 0.3, 0.9, 0.7);
    Rect line(double top) => Rect.fromLTRB(0.15, top, 0.85, top + 0.03);

    test('is readable once enough lines of text are read in the frame', () {
      expect(textReadable([line(0.35), line(0.45), line(0.6)], region), isTrue);
      expect(textReadable([line(0.35), line(0.45)], region), isFalse);
      expect(textReadable([line(0.35), line(0.45), line(0.1)], region), isFalse);
    });

    test('text that is not readable is an issue of a document found, only', () {
      expect(withUnreadable(const {}), {DocumentPhotoIssue.unreadable});
      expect(withUnreadable({DocumentPhotoIssue.glare}), {DocumentPhotoIssue.glare, DocumentPhotoIssue.unreadable});
      expect(withUnreadable({DocumentPhotoIssue.noDocument}), {DocumentPhotoIssue.noDocument});
      expect(withUnreadable({DocumentPhotoIssue.tooDark}), {DocumentPhotoIssue.tooDark});
    });
  });

  group('checkFrame', () {
    // A 300 x 400 portrait view of the card lying in the frame, as a sideways
    // sensor frame turned 90 degrees clockwise to be upright.
    const uprightWidth = 300;
    const uprightHeight = 400;
    const frame = Rect.fromLTWH(20, 105, 260, 164);
    final region = Rect.fromLTRB(
      frame.left / uprightWidth,
      frame.top / uprightHeight,
      frame.right / uprightWidth,
      frame.bottom / uprightHeight,
    );
    LumaFrame sensorFrame(bool Function(Offset upright) onCard) {
      final bytes = Uint8List(uprightWidth * uprightHeight);
      for (var uy = 0; uy < uprightHeight; uy++) {
        for (var ux = 0; ux < uprightWidth; ux++) {
          // Upright (ux, uy) is sensor (uy, height - 1 - ux), the sensor
          // frame uprightHeight wide and uprightWidth high.
          bytes[(uprightWidth - 1 - ux) * uprightHeight + uy] = onCard(Offset(ux + 0.5, uy + 0.5)) ? 200 : 60;
        }
      }
      return LumaFrame.luma(bytes: bytes, width: uprightHeight, height: uprightWidth, bytesPerRow: uprightHeight);
    }

    LumaFrame cardFrame() => sensorFrame(frame.contains);
    LumaFrame emptyFrame() => sensorFrame((_) => false);

    test('finds the card where the frame lies in the upright frame', () {
      expect(checkFrame(cardFrame(), rotation: 90, region: region), {DocumentPhotoIssue.blurry});
      expect(checkFrame(emptyFrame(), rotation: 90, region: region), {DocumentPhotoIssue.noDocument});
    });

    test('DocumentFrameChecker checks every frame on its isolate, in order, like checkFrame', () async {
      final checker = await DocumentFrameChecker.start();
      addTearDown(checker.close);
      final withCard = cardFrame();
      final without = emptyFrame();
      final results = await Future.wait([
        for (final f in [withCard, without, withCard, without]) checker.check(f, rotation: 90, region: region),
      ]);
      expect(results, [
        for (final f in [withCard, without, withCard, without]) checkFrame(f, rotation: 90, region: region),
      ]);
      expect(results[1], {DocumentPhotoIssue.noDocument});
    });

    test('DocumentFrameChecker fails the frames still being checked when it closes', () async {
      final checker = await DocumentFrameChecker.start();
      final result = checker.check(cardFrame(), rotation: 90, region: region);
      checker.close();
      await expectLater(result, throwsStateError);
    });

    test('DocumentFrameChecker is busy while a frame is checked', () async {
      final checker = await DocumentFrameChecker.start();
      addTearDown(checker.close);
      expect(checker.busy, isFalse);
      final result = checker.check(cardFrame(), rotation: 90, region: region);
      expect(checker.busy, isTrue);
      await result;
      expect(checker.busy, isFalse);
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

  group('DocumentPhotoQuality', () {
    const none = <DocumentPhotoIssue>{};
    const agree = DocumentPhotoQuality.framesToAgree;
    const window = DocumentPhotoQuality.windowFrames;

    void feed(DocumentPhotoQuality quality, Set<DocumentPhotoIssue> issues, int frames) {
      for (var i = 0; i < frames; i++) {
        quality.update(issues);
      }
    }

    test('is neither clear nor showing an issue before enough frames agree', () {
      final quality = DocumentPhotoQuality();
      feed(quality, none, agree - 1);
      expect((quality.clear, quality.issue), (false, null));
      quality.update(none);
      expect((quality.clear, quality.issue), (true, null));
    });

    test('tells why there is no document once enough frames agree', () {
      final quality = DocumentPhotoQuality();
      feed(quality, {DocumentPhotoIssue.tooDark}, agree - 1);
      expect(quality.issue, isNull);
      quality.update({DocumentPhotoIssue.tooDark});
      expect((quality.clear, quality.issue), (false, DocumentPhotoIssue.tooDark));
      feed(quality, {DocumentPhotoIssue.noDocument}, agree);
      expect(quality.issue, DocumentPhotoIssue.noDocument);
    });

    test('tells glare over the frame as why there is no document', () {
      final quality = DocumentPhotoQuality();
      feed(quality, {DocumentPhotoIssue.noDocument, DocumentPhotoIssue.glare}, agree);
      expect((quality.clear, quality.issue), (false, DocumentPhotoIssue.glare));
      feed(quality, {DocumentPhotoIssue.noDocument}, agree);
      expect(quality.issue, DocumentPhotoIssue.noDocument);
    });

    test('a few frames do not flip a check', () {
      final quality = DocumentPhotoQuality();
      feed(quality, none, window);
      feed(quality, {DocumentPhotoIssue.glare}, window - agree);
      expect(quality.clear, isTrue);
      feed(quality, {DocumentPhotoIssue.glare}, agree - (window - agree));
      expect((quality.clear, quality.issue), (false, DocumentPhotoIssue.glare));
      feed(quality, none, window - agree);
      expect(quality.issue, DocumentPhotoIssue.glare);
      feed(quality, none, agree - (window - agree));
      expect((quality.clear, quality.issue), (true, null));
    });

    test('each check settles on its own: one flickering does not drag another along', () {
      final quality = DocumentPhotoQuality();
      // Glare in every frame, blur in every other one.
      for (var i = 0; i < window; i++) {
        quality.update({DocumentPhotoIssue.glare, if (i.isEven) DocumentPhotoIssue.blurry});
      }
      expect(quality.issue, DocumentPhotoIssue.glare);
      feed(quality, none, window);
      expect((quality.clear, quality.issue), (true, null));
    });

    test('a failing check hides no other: the next shows once it passes', () {
      final quality = DocumentPhotoQuality();
      feed(quality, {DocumentPhotoIssue.glare, DocumentPhotoIssue.tilted, DocumentPhotoIssue.blurry}, window);
      expect(quality.issue, DocumentPhotoIssue.glare);
      feed(quality, {DocumentPhotoIssue.tilted, DocumentPhotoIssue.blurry}, window);
      expect(quality.issue, DocumentPhotoIssue.tilted);
    });

    test('forgets the checks once the document is gone, not for a few frames without it', () {
      final quality = DocumentPhotoQuality();
      feed(quality, {DocumentPhotoIssue.glare}, window);
      feed(quality, {DocumentPhotoIssue.noDocument}, window - agree);
      expect(quality.issue, DocumentPhotoIssue.glare);
      feed(quality, {DocumentPhotoIssue.noDocument}, window);
      expect(quality.issue, DocumentPhotoIssue.noDocument);
      feed(quality, none, window);
      expect((quality.clear, quality.issue), (true, null));
    });

    test('reports whether anything changed', () {
      final quality = DocumentPhotoQuality();
      feed(quality, {DocumentPhotoIssue.tooDark}, agree - 1);
      expect(quality.update({DocumentPhotoIssue.tooDark}), isTrue);
      expect(quality.update({DocumentPhotoIssue.tooDark}), isFalse);
    });

    test('reset forgets the frames', () {
      final quality = DocumentPhotoQuality();
      feed(quality, none, window);
      quality.reset();
      expect((quality.clear, quality.issue), (false, null));
    });
  });
}
