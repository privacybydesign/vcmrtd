import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// A frame whose document has the same print in every frame, the sensor's
/// noise on it, and [light] over its rows: how bright each row was lit.
FrameSignature _banded(math.Random random, {double Function(int row)? light}) {
  const length = 300;
  Float32List band(double Function(int i) lightAt) => Float32List.fromList([
    for (var i = 0; i < length; i++) ((i ~/ 7).isEven ? 190.0 : 60.0) * lightAt(i) + random.nextDouble() * 4 - 2,
  ]);
  return FrameSignature(
    luma: Float32List(_cells),
    cb: Float32List(_cells),
    cr: Float32List(_cells),
    bands: (rows: band(light ?? (_) => 1), columns: band((_) => 1)),
  );
}

const _viewWidth = 120;
const _viewHeight = 80;

/// How much of the light the print reflects: text lines on paper.
double _print(int x, int y) => (y ~/ 4).isEven && (x ~/ 3).isEven ? 0.2 : 0.95;

DocumentView _view(int Function(int x, int y) brightness) => (
  pixels: Uint8List.fromList([
    for (var y = 0; y < _viewHeight; y++)
      for (var x = 0; x < _viewWidth; x++) brightness(x, y).clamp(0, 255),
  ]),
  width: _viewWidth,
  height: _viewHeight,
);

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
    expect(liveness.signals.flashBrightening, closeTo(0.93, 0.01), reason: 'darker in the frames themselves');
    expect(liveness.signals.flashExposure, 2);
    expect(liveness.signals.screenLike, isFalse);
  });

  test('a document flickers no more than its noise', () {
    final random = math.Random(1);
    final liveness = DocumentLiveness();
    for (var f = 0; f < 10; f++) {
      liveness.add(_banded(random), LightPhase.preview);
    }

    expect(liveness.signals.flicker, lessThan(15));
  });

  test("a screen's flicker shows as stripes that move from frame to frame", () {
    final random = math.Random(2);
    final liveness = DocumentLiveness();
    for (var f = 0; f < 10; f++) {
      liveness.add(
        _banded(random, light: (row) => 1 + 0.03 * math.sin(2 * math.pi * row / 23 + f)),
        LightPhase.preview,
      );
    }

    expect(liveness.signals.flicker, greaterThan(50));
  });

  test('the light changing across the whole document, a hand moving, is no flicker', () {
    final random = math.Random(3);
    final liveness = DocumentLiveness();
    for (var f = 0; f < 10; f++) {
      liveness.add(_banded(random, light: (row) => 1 + 0.002 * f * row / 30), LightPhase.preview);
    }

    expect(liveness.signals.flicker, lessThan(15));
  });

  test("a document's print shares out the torch's light: light parts gain more than dark ones", () {
    // Room light 200, the torch 30 more, and the laminate's sheen over all of it.
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => (200 * _print(x, y)).round()), LightPhase.unlit)
      ..view(_view((x, y) => (230 * _print(x, y) + 10).round()), LightPhase.lit);

    expect(liveness.signals.torchTracking, closeTo(0.15, 0.02));
  });

  test('the hand moving the phone a few pixels between the two frames still lines the print up', () {
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => (200 * _print(x, y)).round()), LightPhase.unlit)
      ..view(_view((x, y) => (230 * _print(x - 3, y + 2) + 10).round()), LightPhase.lit);

    expect(liveness.signals.torchTracking, closeTo(0.15, 0.02));
  });

  test("a screen's picture gives off its own light: its glass reflects the torch alike over all of it", () {
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => (200 * _print(x, y) + 5).round()), LightPhase.unlit)
      ..view(_view((x, y) => (200 * _print(x, y) + 5 + 40).round()), LightPhase.lit);

    expect(liveness.signals.torchTracking, closeTo(0, 0.02));
  });

  test('a screen whose frames the camera exposed less for once the torch went on still tracks nothing', () {
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => (200 * _print(x, y) + 5).round()), LightPhase.unlit)
      ..exposure(LightPhase.unlit, time: 20000000, iso: 400)
      ..view(_view((x, y) => ((200 * _print(x, y) + 45) / 2).round()), LightPhase.lit)
      ..exposure(LightPhase.lit, time: 10000000, iso: 400);

    expect(liveness.signals.torchTracking, closeTo(0, 0.02));
  });

  test("the torch's reflection ending sharply, off glass, or softly, off laminate", () {
    int spot(int x, int y, {required int ramp}) {
      final distance = math.sqrt(math.pow(x - 60, 2) + math.pow(y - 40, 2)) - 8;
      return distance <= 0 ? 255 : (250 - 100 * math.min(1, distance / ramp)).round();
    }

    DocumentLiveness lit(int ramp) => DocumentLiveness()
      ..view(_view((x, y) => 150), LightPhase.unlit)
      ..view(_view((x, y) => spot(x, y, ramp: ramp)), LightPhase.lit);

    expect(lit(1).signals.glareEdge, greaterThan(80));
    expect(lit(20).signals.glareEdge, lessThan(30));
    expect(
      (DocumentLiveness()
            ..view(_view((x, y) => 150), LightPhase.unlit)
            ..view(_view((x, y) => 200), LightPhase.lit))
          .signals
          .glareEdge,
      isNull,
      reason: 'the torch clipped nowhere',
    );
  });

  test("ink is darker against the paper than a screen's black", () {
    double? inkLevel(int black) =>
        (DocumentLiveness()..view(_view((x, y) => _print(x, y) < 0.5 ? black : 200), LightPhase.unlit))
            .signals
            .inkLevel;

    expect(inkLevel(20), closeTo(0.1, 0.01));
    expect(inkLevel(60), closeTo(0.3, 0.01));
  });

  test('only the last frame before the torch and the first with it need their view', () {
    final liveness = DocumentLiveness();
    expect(liveness.needsView(LightPhase.preview), isFalse);
    expect(liveness.needsView(LightPhase.unlit), isTrue);
    expect(liveness.needsView(LightPhase.lit), isTrue);

    liveness
      ..view(_view((x, y) => 100), LightPhase.unlit)
      ..view(_view((x, y) => 120), LightPhase.lit);

    expect(liveness.needsView(LightPhase.unlit), isTrue);
    expect(liveness.needsView(LightPhase.lit), isFalse);
  });

  test('a torch test that runs long keeps a bounded number of frames', () {
    final liveness = DocumentLiveness();
    for (var f = 0; f < 100; f++) {
      liveness
        ..add(_frame(), LightPhase.unlit)
        ..add(_frame(), LightPhase.lit);
    }

    expect(liveness.signals.flashFrames, (30, 30));
  });

  test('the signals are worked out off the UI isolate the same as on it', () async {
    final random = math.Random(4);
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => (200 * _print(x, y)).round()), LightPhase.unlit)
      ..view(_view((x, y) => (230 * _print(x, y) + 10).round()), LightPhase.lit);
    for (final phase in LightPhase.values) {
      for (var f = 0; f < 4; f++) {
        liveness.add(_banded(random), phase);
      }
    }

    expect((await compute(livenessSignals, liveness)).toString(), liveness.signals.toString());
  });

  test('the views of a side are forgotten for the next one', () {
    final liveness = DocumentLiveness()
      ..view(_view((x, y) => 100), LightPhase.unlit)
      ..view(_view((x, y) => 120), LightPhase.lit)
      ..reset();

    expect(liveness.signals.inkLevel, isNull);
    expect(liveness.signals.torchTracking, isNull);
  });

  test('too few frames: the signals are left out of the log line', () {
    final liveness = DocumentLiveness()..add(_frame(), LightPhase.preview);

    expect(
      liveness.signals.toString(),
      'received=0 qualityChecked=0 portraitChecked=0 frames=1 motion=- colourShift=- flashFrames=0/0 '
      'flashResponse=- flashBrightening=- flashExposure=- flashGlare=- flashColour=- flicker=- torchTracking=- glareEdge=- inkLevel=- exposure=-->-',
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
