import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_liveness.dart';

const _cells = signatureColumns * signatureRows;

FrameSignature _frame({
  double luma = 150,
  double cb = 128,
  double cr = 128,
  Map<int, (double, double)> cells = const {},
}) {
  final signature = FrameSignature(
    luma: Float32List(_cells)..fillRange(0, _cells, luma),
    cb: Float32List(_cells)..fillRange(0, _cells, cb),
    cr: Float32List(_cells)..fillRange(0, _cells, cr),
  );
  cells.forEach((cell, colour) {
    signature.cb[cell] = colour.$1;
    signature.cr[cell] = colour.$2;
  });
  return signature;
}

void main() {
  test("the camera's white balance shifting every colour is no hologram", () {
    final liveness = DocumentLiveness();
    for (final shift in [0.0, 10.0, 20.0, 30.0]) {
      liveness.add(_frame(cb: 128 + shift, cr: 128 - shift), LightPhase.preview);
    }

    expect(liveness.signals.colourShift, closeTo(0, 0.01));
  });

  test('part of the document changing colour as it tilts is', () {
    final liveness = DocumentLiveness();
    for (final colour in [(100.0, 160.0), (160.0, 100.0), (128.0, 170.0), (170.0, 128.0)]) {
      liveness.add(
        _frame(
          cells: {
            for (final cell in [40, 41, 56]) cell: colour,
          },
        ),
        LightPhase.preview,
      );
    }

    expect(liveness.signals.colourShift, greaterThan(20));
  });

  test('cells too bright to show colour are left out', () {
    final liveness = DocumentLiveness();
    for (final colour in [(100.0, 160.0), (160.0, 100.0), (128.0, 170.0)]) {
      final frame = _frame(cells: {40: colour});
      frame.luma[40] = 250;
      liveness.add(frame, LightPhase.preview);
    }

    expect(liveness.signals.colourShift, closeTo(0, 0.01));
  });

  test('motion: none for a document held still, the brightness change otherwise', () {
    final still = DocumentLiveness();
    final moving = DocumentLiveness();
    for (final luma in [100.0, 110.0, 100.0]) {
      still.add(_frame(), LightPhase.preview);
      moving.add(_frame(luma: luma), LightPhase.preview);
    }

    expect(still.signals.motion, 0);
    expect(moving.signals.motion, closeTo(10, 0.01));
  });

  test('a document reflecting the torch gets brighter; its clipped reflection is left out', () {
    final liveness = DocumentLiveness();
    liveness.add(_frame(luma: 80), LightPhase.unlit);
    final lit = _frame(luma: 160)..luma[3] = 255;
    liveness.add(lit, LightPhase.lit);

    expect(liveness.signals.flashResponse, closeTo(2, 0.01));
    expect(liveness.signals.flashFrames, (1, 1));
  });

  test("the torch's reflection turning more of the document white is its glare", () {
    final liveness = DocumentLiveness();
    liveness.add(_frame(luma: 120), LightPhase.unlit);
    final lit = _frame(luma: 160);
    for (var cell = 0; cell < 16; cell++) {
      lit.luma[cell] = 250;
    }
    liveness.add(lit, LightPhase.lit);

    expect(liveness.signals.flashGlare, closeTo(16 / _cells, 0.001));
  });

  test('a hologram lighting up in colour under the torch; the white balance shifting all colours is not', () {
    final hologram = DocumentLiveness()
      ..add(_frame(), LightPhase.unlit)
      ..add(
        _frame(
          cb: 120,
          cr: 136,
          cells: {
            for (final cell in [40, 41, 56]) cell: (160.0, 100.0),
          },
        ),
        LightPhase.lit,
      );
    final screen = DocumentLiveness()
      ..add(_frame(), LightPhase.unlit)
      ..add(_frame(cb: 120, cr: 136), LightPhase.lit);

    expect(hologram.signals.flashColour, greaterThan(30));
    expect(screen.signals.flashColour, closeTo(0, 0.01));
  });

  test("the exposure before and with the torch on, to tell whether the lock held", () {
    final liveness = DocumentLiveness()
      ..exposure(LightPhase.unlit, time: 10000000, iso: 200)
      ..exposure(LightPhase.lit, time: 5000000, iso: 100)
      ..exposure(LightPhase.lit, time: 7000000, iso: 100)
      ..exposure(LightPhase.lit, time: null, iso: 100);

    expect(liveness.signals.exposures, (unlit: (milliseconds: 10.0, iso: 200.0), lit: (milliseconds: 6.0, iso: 100.0)));
    expect(liveness.signals.toString(), contains('exposure=10.00ms/ISO200->6.00ms/ISO100'));
  });

  group('like a screen: the torch neither made it glare nor brighten', () {
    LivenessSignals torched({required double before, required double after, int glaring = 0}) {
      final lit = _frame(luma: after);
      for (var cell = 0; cell < glaring; cell++) {
        lit.luma[cell] = 250;
      }
      return (DocumentLiveness()
            ..add(_frame(luma: before), LightPhase.unlit)
            ..add(lit, LightPhase.lit))
          .signals;
    }

    test('a phone screen: little glare, no brighter', () {
      expect(torched(before: 150, after: 140, glaring: 8).screenLike, isTrue);
    });

    test('an identity card: glare', () {
      expect(torched(before: 150, after: 150, glaring: 48).screenLike, isFalse);
    });

    test("a passport's less glossy photo page: little glare, but brighter", () {
      expect(torched(before: 150, after: 156, glaring: 12).screenLike, isFalse);
    });

    test('no torch test, no verdict', () {
      expect(DocumentLiveness().signals.screenLike, isNull);
    });
  });

  test('the frames received and checked are counted', () {
    final liveness = DocumentLiveness()
      ..received()
      ..received()
      ..qualityChecked()
      ..portraitChecked();

    expect(liveness.signals.checks, (received: 2, quality: 1, portrait: 1));
  });

  test('a screen giving off its own light hardly does', () {
    final liveness = DocumentLiveness();
    liveness.add(_frame(luma: 150), LightPhase.unlit);
    liveness.add(_frame(luma: 156), LightPhase.lit);

    expect(liveness.signals.flashResponse, closeTo(1.04, 0.01));
  });

  test('a document the camera exposed less for once the torch went on still brightens', () {
    final liveness = DocumentLiveness()
      ..add(_frame(luma: 150), LightPhase.unlit)
      ..exposure(LightPhase.unlit, time: 20000000, iso: 400)
      ..add(_frame(luma: 140), LightPhase.lit)
      ..exposure(LightPhase.lit, time: 10000000, iso: 400);

    expect(liveness.signals.flashResponse, closeTo(1.87, 0.01));
    expect(liveness.signals.screenLike, isFalse);
  });

  test('too few frames: the signals are left out of the log line', () {
    final liveness = DocumentLiveness()..add(_frame(), LightPhase.preview);

    expect(
      liveness.signals.toString(),
      'received=0 qualityChecked=0 portraitChecked=0 frames=1 motion=- colourShift=- flashFrames=0/0 '
      'flashResponse=- flashGlare=- flashColour=- exposure=-->-',
    );
  });

  test('reset forgets the previous side', () {
    final liveness = DocumentLiveness();
    for (var i = 0; i < 3; i++) {
      liveness.add(_frame(), LightPhase.preview);
    }
    liveness.reset();

    expect(liveness.signals.frames, 0);
  });
}
