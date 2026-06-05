import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
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

      test('odd NV21 crop coordinates are aligned to even chroma boundaries', () {
        final frame = _nv21(width: 6, height: 4, roiLeft: 0.2, roiTop: 0.0, roiWidth: 0.5, roiHeight: 1.0);
        final cropped = frame.cropToRoi();

        expect(cropped.width.isEven, isTrue);
        expect(cropped.width, 4);
        expect(cropped.height, 4);
        expect(cropped.bytesPerRow, 4);
      });

      test('tiny NV21 ROI is clamped to the minimum chroma-safe crop size', () {
        final frame = _nv21(width: 4, height: 4, roiLeft: 0.75, roiTop: 0.5, roiWidth: 0.01, roiHeight: 0.01);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 2);
        expect(cropped.height, 2);
        expect(cropped.bytes.length, 2 * 2 + 2 * 2 ~/ 2);
      });

      test('partial NV21 crop copies matching UV rows', () {
        final bytes = Uint8List(4 * 4 + 4 * 4 ~/ 2);
        for (var i = 0; i < 16; i++) {
          bytes[i] = i;
        }
        for (var i = 16; i < bytes.length; i++) {
          bytes[i] = 100 + i;
        }

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

        expect(cropped.bytes.sublist(0, 8), Uint8List.fromList(<int>[8, 9, 10, 11, 12, 13, 14, 15]));
        expect(cropped.bytes.sublist(8), Uint8List.fromList(<int>[120, 121, 122, 123]));
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

      test('BGRA crop clamps ROI that extends beyond the image bounds', () {
        final frame = _bgra(width: 4, height: 4, roiLeft: 0.75, roiTop: 0.75, roiWidth: 1, roiHeight: 1);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 1);
        expect(cropped.height, 1);
        expect(cropped.bytesPerRow, 4);
        expect(cropped.bytes.length, 4);
      });

      test('BGRA crop with tiny ROI still returns a single pixel crop', () {
        final frame = _bgra(width: 4, height: 4, roiLeft: 0.5, roiTop: 0.5, roiWidth: 0.01, roiHeight: 0.01);
        final cropped = frame.cropToRoi();

        expect(cropped.width, 1);
        expect(cropped.height, 1);
        expect(cropped.bytes.length, 4);
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

  group('MRZCameraViewState YUV420 to NV21 conversion', () {
    Future<MRZCameraViewState> pumpState(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      return tester.state<MRZCameraViewState>(find.byType(MRZCameraView));
    }

    testWidgets('debugYuv420PlanesToNv21 copies tight Y plane and interleaves VU chroma', (tester) async {
      final state = await pumpState(tester);

      final nv21 = state.debugYuv420PlanesToNv21(
        width: 4,
        height: 2,
        yBytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
        yBytesPerRow: 4,
        uBytes: Uint8List.fromList(<int>[10, 20]),
        uBytesPerRow: 2,
        uBytesPerPixel: 1,
        vBytes: Uint8List.fromList(<int>[30, 40]),
        vBytesPerRow: 2,
        vBytesPerPixel: 1,
      );

      expect(nv21, Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 30, 10, 40, 20]));
    });

    testWidgets('debugYuv420PlanesToNv21 removes padded Y row stride', (tester) async {
      final state = await pumpState(tester);

      final nv21 = state.debugYuv420PlanesToNv21(
        width: 2,
        height: 2,
        yBytes: Uint8List.fromList(<int>[1, 2, 99, 3, 4, 99]),
        yBytesPerRow: 3,
        uBytes: Uint8List.fromList(<int>[10]),
        uBytesPerRow: 1,
        uBytesPerPixel: 1,
        vBytes: Uint8List.fromList(<int>[20]),
        vBytesPerRow: 1,
        vBytesPerPixel: 1,
      );

      expect(nv21, Uint8List.fromList(<int>[1, 2, 3, 4, 20, 10]));
    });

    testWidgets('debugYuv420PlanesToNv21 respects chroma pixel stride of 2', (tester) async {
      final state = await pumpState(tester);

      final nv21 = state.debugYuv420PlanesToNv21(
        width: 4,
        height: 2,
        yBytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
        yBytesPerRow: 4,
        uBytes: Uint8List.fromList(<int>[10, 99, 20, 99]),
        uBytesPerRow: 4,
        uBytesPerPixel: 2,
        vBytes: Uint8List.fromList(<int>[30, 99, 40, 99]),
        vBytesPerRow: 4,
        vBytesPerPixel: 2,
      );

      expect(nv21, Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 30, 10, 40, 20]));
    });

    testWidgets('route callbacks do not throw when no cameras are initialized', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      final state = tester.state<MRZCameraViewState>(find.byType(MRZCameraView));

      state.didPush();
      state.didPushNext();
      state.didPopNext();
      state.didPop();

      await tester.pump();

      expect(find.byType(MRZCameraView), findsOneWidget);
    });
  });

  group('MRZCameraViewState OCR frame mapping', () {
    Future<MRZCameraViewState> pumpState(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MRZCameraView(showOverlay: false, initializeCamera: false, onImage: (_) {})),
      );

      return tester.state<MRZCameraViewState>(find.byType(MRZCameraView));
    }

    testWidgets('debugBuildOcrFrameFromBytes computes back-camera rotation', (tester) async {
      final state = await pumpState(tester);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 2,
        isNv21: true,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        viewSize: const Size(400, 800),
      );

      expect(frame.rotation, 0);
      expect(frame.isNv21, isTrue);
      expect(frame.bytesPerRow, 2);
    });

    testWidgets('debugBuildOcrFrameFromBytes computes front-camera rotation', (tester) async {
      final state = await pumpState(tester);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 8,
        isNv21: false,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.front,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        viewSize: const Size(400, 800),
      );

      expect(frame.rotation, 180);
      expect(frame.isNv21, isFalse);
      expect(frame.bytesPerRow, 8);
    });

    testWidgets('debugBuildOcrFrameFromBytes clamps ROI fractions into valid range', (tester) async {
      final state = await pumpState(tester);

      state.debugSetPreviewScale(0.1);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 2,
        isNv21: true,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitUp,
        viewSize: const Size(400, 800),
      );

      expect(frame.roiLeft, inInclusiveRange(0.0, 1.0));
      expect(frame.roiTop, inInclusiveRange(0.0, 1.0));
      expect(frame.roiWidth, inInclusiveRange(0.0, 1.0));
      expect(frame.roiHeight, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('debugBuildOcrFrameFromBytes maps back camera portraitDown rotation', (tester) async {
      final state = await pumpState(tester);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 2,
        isNv21: true,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitDown,
        viewSize: const Size(400, 800),
      );

      expect(frame.rotation, 270);
    });

    testWidgets('debugBuildOcrFrameFromBytes maps front camera landscapeRight rotation', (tester) async {
      final state = await pumpState(tester);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 2,
        isNv21: false,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.front,
        deviceOrientation: DeviceOrientation.landscapeRight,
        viewSize: const Size(400, 800),
      );

      expect(frame.rotation, 0);
    });

    testWidgets('debugBuildOcrFrameFromBytes uses preview fallback when overlay misses scaled preview', (tester) async {
      final state = await pumpState(tester);

      state.debugSetPreviewScale(0.05);

      final frame = state.debugBuildOcrFrameFromBytes(
        bytes: Uint8List(4),
        width: 2,
        height: 2,
        bytesPerRow: 2,
        isNv21: true,
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitUp,
        viewSize: const Size(400, 800),
      );

      expect(frame.roiLeft, 0.0);
      expect(frame.roiTop, 0.0);
      expect(frame.roiWidth, 1.0);
      expect(frame.roiHeight, 1.0);
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
