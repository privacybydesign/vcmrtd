import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:vcmrtdapp/routing.dart';
import 'camera_overlay.dart';

class MRZCameraView extends StatefulWidget {
  const MRZCameraView({
    super.key,
    required this.onImage,
    this.initialDirection = CameraLensDirection.back,
    required this.showOverlay,
  });

  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;
  final bool showOverlay;

  @override
  MRZCameraViewState createState() => MRZCameraViewState();
}

class MRZCameraViewState extends State<MRZCameraView> with RouteAware {
  CameraController? _controller;
  int _cameraIndex = 1;
  List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();

    try {
      if (cameras.any(
        (element) => element.lensDirection == widget.initialDirection && element.sensorOrientation == 90,
      )) {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere(
            (element) => element.lensDirection == widget.initialDirection && element.sensorOrientation == 90,
          ),
        );
      } else {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere((element) => element.lensDirection == widget.initialDirection),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    _startLiveFeed();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: widget.showOverlay ? MRZCameraOverlay(child: _liveFeedBody()) : _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized == false || _controller?.value.isInitialized == null) {
      return Container();
    }
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(aspectRatio: 9 / 16, child: CameraPreview(_controller!)),
            ),
          ),
        ],
      ),
    );
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _processCameraImage(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  Uint8List yuv420ToNv21(CameraImage img) {
    final int width = img.width;
    final int height = img.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    // Copy Y
    nv21.setRange(0, ySize, img.planes[0].bytes);

    // Interleave V and U (VU order)
    final Plane u = img.planes[1];
    final Plane v = img.planes[2];
    final int uRowStride = u.bytesPerRow;
    final int vRowStride = v.bytesPerRow;
    final int uPixelStride = u.bytesPerPixel ?? 1;
    final int vPixelStride = v.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      int uRowStart = row * uRowStride;
      int vRowStart = row * vRowStride;
      for (int col = 0; col < width ~/ 2; col++) {
        final int vByte = v.bytes[vRowStart + col * vPixelStride];
        final int uByte = u.bytes[uRowStart + col * uPixelStride];
        nv21[uvIndex++] = vByte;
        nv21[uvIndex++] = uByte;
      }
    }
    return nv21;
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // For camera feed that supports only yuv_420_888
    if (format == null || Platform.isAndroid && format == InputImageFormat.yuv_420_888) {
      final nv21Bytes = yuv420ToNv21(image);

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if ((Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  @override
  void didPush() async {
    // Called when the current route has been pushed.
    await _startLiveFeed();
  }

  @override
  void didPushNext() async {
    // Called when a new route has been pushed, and this route is no longer visible.
    await _stopLiveFeed();
  }

  // Called when the top route has been popped and this route shows again.
  @override
  void didPopNext() async {
    // For some reason an exception is sometimes triggered when going back from a session screen.
    // This doesn't have any effect for the user, but in order to prevent it from showing up in
    // Sentry logging we catch it here and pretend like nothing happened...
    try {
      await _startLiveFeed();
    } catch (e) {
      debugPrint('error while starting live feed: $e');
    }
  }

  // Called when this route is popped.
  @override
  void didPop() async {
    await _stopLiveFeed();
  }
}
