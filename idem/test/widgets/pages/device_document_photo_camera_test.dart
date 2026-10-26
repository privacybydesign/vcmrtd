import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/widgets/pages/document_photo_screen.dart';
import 'package:mrz_capture/mrz_capture.dart';

class _FakeCameraPlatform extends CameraPlatform {
  /// When set, [availableCameras] waits for it: a camera that takes a while to open.
  Completer<void>? camerasGate;

  Object? pictureError;

  var created = 0;
  final disposed = <int>[];
  var streamsStarted = 0;
  var streaming = false;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    await camerasGate?.future;
    return const [CameraDescription(name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90)];
  }

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription, MediaSettings mediaSettings) async =>
      ++created;

  final _initialized = StreamController<CameraInitializedEvent>.broadcast();

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    scheduleMicrotask(
      () => _initialized.add(
        CameraInitializedEvent(cameraId, 1920, 1080, ExposureMode.auto, false, FocusMode.auto, false),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream.where((e) => e.cameraId == cameraId);

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) {
    late final StreamController<CameraImageData> frames;
    frames = StreamController<CameraImageData>(
      onListen: () {
        streamsStarted++;
        streaming = true;
      },
      onCancel: () => streaming = false,
    );
    return frames.stream;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final error = pictureError;
    if (error != null) throw error;
    return XFile.fromData(Uint8List(0));
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async => disposed.add(cameraId);
}

void main() {
  late _FakeCameraPlatform platform;
  late DeviceDocumentPhotoCamera camera;

  setUp(() {
    platform = _FakeCameraPlatform();
    CameraPlatform.instance = platform;
    camera = DeviceDocumentPhotoCamera();
  });
  tearDown(() => camera.dispose());

  Future<void> open() => camera.open(
    frameRatio: MRZCameraOverlay.cardFrameRatio,
    content: (portrait: true, mrz: false),
    onFrameChecked: (_) {},
  );

  testWidgets('opening streams the preview frames; closing stops them and releases the camera', (tester) async {
    await tester.runAsync(open);
    expect(platform.created, 1);
    expect(platform.streaming, isTrue);

    await tester.runAsync(camera.close);
    expect(platform.streaming, isFalse);
    expect(platform.disposed, [1]);
  });

  testWidgets('opening again reuses the open camera', (tester) async {
    await tester.runAsync(open);
    await tester.runAsync(open);

    expect(platform.created, 1);
    expect(platform.streamsStarted, 1);
    await tester.runAsync(camera.close);
  });

  testWidgets('opening after a failed picture restarts the preview frames', (tester) async {
    await tester.runAsync(open);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: camera.buildPreview),
      ),
    );
    platform.pictureError = PlatformException(code: 'capture');

    await tester.runAsync(() async {
      await expectLater(camera.takePicture(frameRatio: MRZCameraOverlay.cardFrameRatio), throwsA(anything));
    });
    expect(platform.streaming, isFalse);

    await tester.runAsync(open);
    expect(platform.created, 1);
    expect(platform.streamsStarted, 2);
    expect(platform.streaming, isTrue);
    await tester.runAsync(camera.close);
  });

  testWidgets('a picture taken releases the camera before it is prepared', (tester) async {
    await tester.runAsync(open);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: camera.buildPreview),
      ),
    );

    await tester.runAsync(() async {
      final taken = await camera.takePicture(frameRatio: MRZCameraOverlay.cardFrameRatio);
      // The fake's picture is no JPEG: preparing it fails, after the camera is released.
      await expectLater(taken.photo, throwsA(anything));
    });

    expect(platform.disposed, [1]);
  });

  testWidgets('a picture taken takes the preview off the screen before its camera is released', (tester) async {
    await tester.runAsync(open);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: camera.buildPreview),
      ),
    );
    expect(find.byType(CameraPreview), findsOneWidget);

    await tester.runAsync(() async {
      final taken = await camera.takePicture(frameRatio: MRZCameraOverlay.cardFrameRatio);
      await expectLater(taken.photo, throwsA(anything));
    });
    // On a device the preview is redrawn while the picture is prepared, for one.
    for (final preview in find.byType(CameraPreview).evaluate()) {
      preview.markNeedsBuild();
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CameraPreview), findsNothing);
    expect(platform.disposed, [1]);
  });

  testWidgets('an open that a close overtook opens no camera', (tester) async {
    await tester.runAsync(() async {
      platform.camerasGate = Completer();
      final opening = open();
      await camera.close();
      platform.camerasGate!.complete();
      await opening;
    });

    expect(platform.created, 0);
    expect(platform.disposed, isEmpty);
    expect(platform.streamsStarted, 0);
  });

  testWidgets('an open that a later open overtook leaves the camera to it', (tester) async {
    await tester.runAsync(() async {
      platform.camerasGate = Completer();
      final first = open();
      await camera.close();
      final second = open();
      platform.camerasGate!.complete();
      await Future.wait([first, second]);
    });

    expect(platform.created, 1);
    expect(platform.disposed, isEmpty);
    expect(platform.streamsStarted, 1);
    expect(platform.streaming, isTrue);
    await tester.runAsync(camera.close);
    expect(platform.disposed, [1]);
  });
}
