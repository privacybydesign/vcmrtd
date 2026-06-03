import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/helpers/camera_overlay.dart';
import 'package:vcmrtdapp/helpers/camera_viewfinder.dart';

void main() {
  group('OcrFrame', () {
    group('constructor', () {
      test('stores all fields', () {
        final bytes = Uint8List(4 * 4 + 4 * 4 ~/ 2);
        final frame = OcrFrame(
          bytes: bytes,
          width: 4,
          height: 4,
          bytesPerRow: 4,
          rotation: 90,
          roiLeft: 0.1,
          roiTop: 0.2,
          roiWidth: 0.6,
          roiHeight: 0.5,
          isNv21: true,
        );

        expect(frame.bytes, same(bytes));
        expect(frame.width, 4);
        expect(frame.height, 4);
        expect(frame.bytesPerRow, 4);
        expect(frame.rotation, 90);
        expect(frame.roiLeft, 0.1);
        expect(frame.roiTop, 0.2);
        expect(frame.roiWidth, 0.6);
        expect(frame.roiHeight, 0.5);
        expect(frame.isNv21, isTrue);
      });
    });

    group('NV21 cropToRoi (Android)', () {
      test('full-frame crop preserves dimensions and resets ROI to full', () {
        final frame = _nv21(width: 4, height: 4);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
        expect(cropped.isNv21, isTrue);
        expect(cropped.roiLeft, 0.0);
        expect(cropped.roiTop, 0.0);
        expect(cropped.roiWidth, 1.0);
        expect(cropped.roiHeight, 1.0);
        expect(cropped.bytes.length, 4 * 4 + 4 * 4 ~/ 2);
      });

      test('crops left half (rotation 0)', () {
        final frame = _nv21(width: 8, height: 4, roiWidth: 0.5);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
        expect(cropped.bytes.length, 4 * 4 + 4 * 4 ~/ 2);
      });

      test('crops bottom half (rotation 0)', () {
        final frame = _nv21(width: 4, height: 4, roiTop: 0.5, roiHeight: 0.5);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 2);
      });

      test('preserves Y-plane row content after crop', () {
        // 4×4 NV21: row r has Y byte value r+1
        final bytes = Uint8List(4 * 4 + 4 * 4 ~/ 2);
        for (var r = 0; r < 4; r++) {
          bytes.fillRange(r * 4, r * 4 + 4, r + 1);
        }
        bytes.fillRange(16, bytes.length, 200);

        final frame = OcrFrame(
          bytes: bytes,
          width: 4,
          height: 4,
          bytesPerRow: 4,
          rotation: 0,
          roiLeft: 0,
          roiTop: 0.5,
          roiWidth: 1,
          roiHeight: 0.5,
          isNv21: true,
        );
        final cropped = frame.cropToRoi();

        // Bottom half → sensor y=2..3, row values 3 and 4
        expect(cropped.bytes[0], 3);
        expect(cropped.bytes[4], 4);
      });

      test('rotation 90: sensor ROI maps to swapped width/height axes', () {
        // Sensor 8×4 (landscape), screen ROI covers full frame
        final frame = _nv21(width: 8, height: 4, rotation: 90);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 8);
        expect(cropped.height, 4);
      });

      test('rotation 90: partial screen ROI produces correct sensor crop', () {
        // Screen ROI top-right quadrant on a 8×4 sensor
        // _roiRect(90): x = roiTop*8 = 2, y = (1-roiLeft-roiWidth)*4 = 0, w = roiHeight*8 = 4, h = roiWidth*4 = 4
        final frame = _nv21(width: 8, height: 4, rotation: 90, roiLeft: 0, roiTop: 0.25, roiWidth: 1, roiHeight: 0.5);
        final cropped = frame.cropToRoi();

        // w = (0.5 * 8).toInt() = 4, h = (1.0 * 4).toInt() = 4
        expect(cropped.width, 4);
        expect(cropped.height, 4);
      });

      test('rotation 180: ROI is flipped in both axes', () {
        // Full ROI should still yield full frame
        final frame = _nv21(width: 4, height: 4, rotation: 180);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
      });

      test('rotation 180: partial ROI remapped correctly', () {
        // roiLeft=0.25, roiTop=0.25, roiWidth=0.5, roiHeight=0.5 on 8×8 sensor
        // _roiRect(180): x=(1-0.25-0.5)*8=2, y=(1-0.25-0.5)*8=2, w=4, h=4
        final frame = _nv21(
          width: 8,
          height: 8,
          rotation: 180,
          roiLeft: 0.25,
          roiTop: 0.25,
          roiWidth: 0.5,
          roiHeight: 0.5,
        );
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
      });

      test('rotation 270: partial screen ROI produces correct sensor crop', () {
        // Full ROI on 4×8 sensor
        // _roiRect(270): x=(1-0-1)*4=0, y=0*8=0, w=1.0*4=4, h=1.0*8=8
        final frame = _nv21(width: 4, height: 8, rotation: 270);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 8);
      });

      test('unknown rotation falls through to default (identity) mapping', () {
        final frame = _nv21(width: 4, height: 4, rotation: 45);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
      });

      test('cropped NV21 bytesPerRow equals cropped width', () {
        final frame = _nv21(width: 8, height: 4, roiWidth: 0.5);
        final cropped = frame.cropToRoi();

        // NV21 _withCrop passes w as bytesPerRow
        expect(cropped.bytesPerRow, cropped.width);
      });
    });

    group('BGRA cropToRoi (iOS)', () {
      test('full-frame crop preserves dimensions', () {
        final frame = _bgra(width: 4, height: 4);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
        expect(cropped.isNv21, isFalse);
        expect(cropped.bytesPerRow, 4 * 4);
        expect(cropped.bytes.length, 4 * 4 * 4);
      });

      test('crops top-left quadrant', () {
        final frame = _bgra(width: 4, height: 4, roiWidth: 0.5, roiHeight: 0.5);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 2);
        expect(cropped.height, 2);
        expect(cropped.bytesPerRow, 2 * 4);
      });

      test('crops right half', () {
        final frame = _bgra(width: 4, height: 4, roiLeft: 0.5, roiWidth: 0.5);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 2);
        expect(cropped.height, 4);
      });

      test('handles row padding in source frame', () {
        const width = 4, height = 4;
        const bytesPerRow = 24; // 16 bytes pixel + 8 bytes padding
        final bytes = Uint8List(height * bytesPerRow);
        for (var r = 0; r < height; r++) {
          for (var c = 0; c < width; c++) {
            bytes[r * bytesPerRow + c * 4] = r * 10 + c + 1; // B channel
          }
        }

        final frame = OcrFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: bytesPerRow,
          rotation: 0,
          roiLeft: 0,
          roiTop: 0,
          roiWidth: 1,
          roiHeight: 0.5,
          isNv21: false,
        );
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 2);
        // Output has no padding
        expect(cropped.bytesPerRow, 4 * 4);
        // Row 0, col 0: B = 0*10+0+1 = 1
        expect(cropped.bytes[0], 1);
        // Row 1, col 0: B = 1*10+0+1 = 11
        expect(cropped.bytes[4 * 4], 11);
      });

      test('preserves pixel content: B channel matches source', () {
        const width = 4, height = 2;
        final bytes = Uint8List(height * width * 4);
        for (var r = 0; r < height; r++) {
          for (var c = 0; c < width; c++) {
            bytes[(r * width + c) * 4 + 0] = r * 4 + c + 1; // B
            bytes[(r * width + c) * 4 + 1] = 200; // G
            bytes[(r * width + c) * 4 + 2] = 100; // R
            bytes[(r * width + c) * 4 + 3] = 255; // A
          }
        }

        final frame = OcrFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: width * 4,
          rotation: 0,
          roiLeft: 0,
          roiTop: 0,
          roiWidth: 0.5,
          roiHeight: 1,
          isNv21: false,
        );
        final cropped = frame.cropToRoi();

        expect(cropped.width, 2);
        expect(cropped.height, 2);
        // Row 0 col 0: B = 1
        expect(cropped.bytes[0], 1);
        // Row 0 col 1: B = 2
        expect(cropped.bytes[4], 2);
        // Row 1 col 0: B = 5
        expect(cropped.bytes[2 * 4], 5);
      });

      test('rotation 90 remaps ROI', () {
        final frame = _bgra(width: 4, height: 8, rotation: 90);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 8);
      });

      test('rotation 180 remaps ROI', () {
        final frame = _bgra(width: 4, height: 4, rotation: 180);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 4);
        expect(cropped.height, 4);
      });

      test('rotation 270 remaps ROI', () {
        final frame = _bgra(width: 8, height: 4, rotation: 270);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 8);
        expect(cropped.height, 4);
      });

      test('cropped frame has roiLeft=0 and roiWidth=1', () {
        final frame = _bgra(width: 4, height: 4, roiLeft: 0.25, roiWidth: 0.5);
        final cropped = frame.cropToRoi();

        expect(cropped.roiLeft, 0.0);
        expect(cropped.roiTop, 0.0);
        expect(cropped.roiWidth, 1.0);
        expect(cropped.roiHeight, 1.0);
      });
    });
  });

  group('MRZCameraView', () {
    testWidgets('builds without overlay when showOverlay is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(MRZCameraOverlay), findsNothing);
    });

    testWidgets('wraps body in MRZCameraOverlay when showOverlay is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: true, initializeCamera: false, onImage: (_) {})),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(MRZCameraOverlay), findsOneWidget);
    });

    testWidgets('renders empty container while camera is not initialized', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.child, isNull);
    });
  });

  group('MRZCameraViewState geometry', () {
    testWidgets('overlayRect uses portrait sizing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));

      const size = Size(400, 800);
      final rect = state.overlayRectForTesting(size);

      expect(rect.width, 360);
      expect(rect.height, closeTo(360 / 1.42, 0.001));
      expect(rect.left, 20);
      expect(rect.top, closeTo((800 - (360 / 1.42)) / 2 - 60, 0.001));
    });

    testWidgets('overlayRect uses landscape sizing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));

      const size = Size(800, 400);
      final rect = state.overlayRectForTesting(size);

      final expectedHeight = 400 * 0.75;
      final expectedWidth = expectedHeight * 1.42;

      expect(rect.height, expectedHeight);
      expect(rect.width, closeTo(expectedWidth, 0.001));
      expect(rect.left, closeTo((800 - expectedWidth) / 2, 0.001));
      expect(rect.top, closeTo((400 - expectedHeight) / 2 - 60, 0.001));
    });

    testWidgets('previewRect centers scaled preview for portrait screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));

      const size = Size(400, 800);
      final rect = state.previewRectForTesting(size);

      expect(rect.width, 400);
      expect(rect.height, closeTo(711.111, 0.001));
      expect(rect.left, 0);
      expect(rect.top, closeTo((800 - 711.111) / 2, 0.001));
    });

    testWidgets('previewRect centers scaled preview for landscape screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));

      const size = Size(800, 400);
      final rect = state.previewRectForTesting(size);

      expect(rect.width, 225);
      expect(rect.height, 400);
      expect(rect.left, closeTo((800 - 225) / 2, 0.001));
      expect(rect.top, 0);
    });
  });
}

OcrFrame _nv21({
  int width = 4,
  int height = 4,
  int rotation = 0,
  double roiLeft = 0,
  double roiTop = 0,
  double roiWidth = 1,
  double roiHeight = 1,
}) {
  return OcrFrame(
    bytes: Uint8List(width * height + width * height ~/ 2),
    width: width,
    height: height,
    bytesPerRow: width,
    rotation: rotation,
    roiLeft: roiLeft,
    roiTop: roiTop,
    roiWidth: roiWidth,
    roiHeight: roiHeight,
    isNv21: true,
  );
}

OcrFrame _bgra({
  int width = 4,
  int height = 4,
  int rotation = 0,
  double roiLeft = 0,
  double roiTop = 0,
  double roiWidth = 1,
  double roiHeight = 1,
}) {
  final bytesPerRow = width * 4;
  return OcrFrame(
    bytes: Uint8List(height * bytesPerRow),
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    rotation: rotation,
    roiLeft: roiLeft,
    roiTop: roiTop,
    roiWidth: roiWidth,
    roiHeight: roiHeight,
    isNv21: false,
  );
}
