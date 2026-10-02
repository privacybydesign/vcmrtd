// MRZCameraViewState.takePicture against a fake camera platform: the picture
// is taken with the frame stream paused, which resumes after it even when the
// camera fails - which gives null.

import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeCameraPlatform extends CameraPlatform with MockPlatformInterfaceMixin {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  PlatformException? takePictureError;
  int takePictureCalls = 0;
  int imageStreamStarts = 0;
  int disposeCalls = 0;

  /// When set, [takePicture] waits for it.
  Completer<void>? pictureGate;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90),
  ];

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription, MediaSettings mediaSettings) async => 1;

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(cameraId, 1280, 720, ExposureMode.auto, true, FocusMode.auto, true));

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) {
    imageStreamStarts++;
    return const Stream.empty();
  }

  @override
  bool supportsImageStreaming() => true;

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<XFile> takePicture(int cameraId) async {
    takePictureCalls++;
    await pictureGate?.future;
    if (takePictureError != null) throw takePictureError!;
    return XFile.fromData(jpeg, mimeType: 'image/jpeg');
  }

  @override
  Future<void> dispose(int cameraId) async => disposeCalls++;
}

void main() {
  late _FakeCameraPlatform platform;

  setUp(() {
    platform = _FakeCameraPlatform();
    CameraPlatform.instance = platform;
  });

  Future<MRZCameraViewState> pumpCamera(WidgetTester tester) async {
    final key = GlobalKey<MRZCameraViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MRZCameraView(key: key, showOverlay: true, onImage: (_) {}),
      ),
    );
    // Let the camera initialise, then build the live preview.
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('takePicture returns null when there is no camera', (tester) async {
    final key = GlobalKey<MRZCameraViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MRZCameraView(key: key, showOverlay: false, initializeCamera: false, onImage: (_) {}),
      ),
    );

    expect(await key.currentState!.takePicture(), isNull);
  });

  testWidgets('takePicture returns the picture with the frame inside the preview', (tester) async {
    final state = await pumpCamera(tester);

    final picture = await tester.runAsync(state.takePicture);

    expect(platform.takePictureCalls, 1);
    expect(picture, isNotNull);
    expect(picture!.jpeg, platform.jpeg);
    expect(picture.previewAspectRatio, 9 / 16);
    // Started by the camera, then again after the picture.
    expect(platform.imageStreamStarts, 2);
    expect(const Rect.fromLTRB(0, 0, 1, 1).expandToInclude(picture.frame), const Rect.fromLTRB(0, 0, 1, 1));
  });

  testWidgets('takePicture returns null when the camera fails', (tester) async {
    final state = await pumpCamera(tester);
    platform.takePictureError = PlatformException(code: 'captureFailed');

    expect(await tester.runAsync(state.takePicture), isNull);
    expect(platform.takePictureCalls, 1);
    // Started by the camera, then again after the picture.
    expect(platform.imageStreamStarts, 2);
  });

  testWidgets('leaving the scanner while a picture is taken still releases the camera', (tester) async {
    final state = await pumpCamera(tester);
    platform.pictureGate = Completer<void>();

    unawaited(state.takePicture());
    await tester.pump();
    // Manual entry pushed on top while the picture is being taken: the
    // image stream is paused for it, so there is none to stop.
    state.didPushNext();
    await tester.pump();
    platform.pictureGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(platform.disposeCalls, 1);
  });
}
