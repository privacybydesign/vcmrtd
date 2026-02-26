import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_overlay.dart';
import '../routing.dart';

class OcrFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final int rotation;
  final double roiLeft;
  final double roiTop;
  final double roiWidth;
  final double roiHeight;

  OcrFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotation,
    required this.roiLeft,
    required this.roiTop,
    required this.roiWidth,
    required this.roiHeight,
  });
}

class MRZCameraView extends StatefulWidget {
  const MRZCameraView({
    super.key,
    required this.onImage,
    this.initialDirection = CameraLensDirection.back,
    required this.showOverlay,
  });

  final Function(OcrFrame frame) onImage;
  final CameraLensDirection initialDirection;
  final bool showOverlay;

  @override
  MRZCameraViewState createState() => MRZCameraViewState();
}

class MRZCameraViewState extends State<MRZCameraView> with RouteAware {
  CameraController? _controller;
  int _cameraIndex = 0;
  List<CameraDescription> _cameras = [];
  Size? _viewSize;
  double _previewScale = 1.0;

  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopLiveFeed();
    super.dispose();
  }

  @override
  void didPush() async {
    if (_cameras.isEmpty) return;
    await _startLiveFeed();
  }

  @override
  void didPushNext() async {
    await _stopLiveFeed();
  }

  @override
  void didPopNext() async {
    try {
      await _startLiveFeed();
    } catch (e) {
      debugPrint('error while starting live feed: $e');
    }
  }

  @override
  void didPop() async {
    await _stopLiveFeed();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    try {
      _cameraIndex = _cameras.indexWhere(
            (c) => c.lensDirection == widget.initialDirection && c.sensorOrientation == 90,
      );
      if (_cameraIndex == -1) {
        _cameraIndex = _cameras.indexWhere(
              (c) => c.lensDirection == widget.initialDirection,
        );
      }
      if (_cameraIndex == -1) _cameraIndex = 0;
    } catch (e) {
      if (kDebugMode) print(e);
    }

    await _startLiveFeed();
  }

  Future<void> _startLiveFeed() async {
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final body = _liveFeedBody();
    return Scaffold(
      body: widget.showOverlay ? MRZCameraOverlay(child: body) : body,
    );
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized != true) return Container();

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    _viewSize = size;
    _previewScale = scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!Platform.isAndroid) return;
    if (_controller == null || _viewSize == null) return;
    if (image.planes.length < 3) return;

    final camera = _cameras[_cameraIndex];
    final rotationComp = _orientations[_controller!.value.deviceOrientation];
    if (rotationComp == null) return;

    final int rotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = (camera.sensorOrientation + rotationComp) % 360;
    } else {
      rotation = (camera.sensorOrientation - rotationComp + 360) % 360;
    }

    final size = _viewSize!;
    final preview = _previewRect(size);
    final overlay = _overlayRect(size);

    final roiScreen = overlay.intersect(preview);
    final safeRoi = roiScreen.isEmpty ? preview : roiScreen;

    widget.onImage(OcrFrame(
      bytes: _yuv420ToNv21(image),
      width: image.width,
      height: image.height,
      rotation: rotation,
      roiLeft: ((safeRoi.left - preview.left) / preview.width).clamp(0.0, 1.0),
      roiTop: ((safeRoi.top - preview.top) / preview.height).clamp(0.0, 1.0),
      roiWidth: (safeRoi.width / preview.width).clamp(0.0, 1.0),
      roiHeight: (safeRoi.height / preview.height).clamp(0.0, 1.0),
    ));
  }

  Uint8List _yuv420ToNv21(CameraImage img) {
    final int width = img.width;
    final int height = img.height;
    final int ySize = width * height;
    final Uint8List nv21 = Uint8List(ySize + width * height ~/ 2);

    nv21.setRange(0, ySize, img.planes[0].bytes);

    final u = img.planes[1];
    final v = img.planes[2];
    final int uPixelStride = u.bytesPerPixel ?? 1;
    final int vPixelStride = v.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      final int uRowStart = row * u.bytesPerRow;
      final int vRowStart = row * v.bytesPerRow;
      for (int col = 0; col < width ~/ 2; col++) {
        nv21[uvIndex++] = v.bytes[vRowStart + col * vPixelStride];
        nv21[uvIndex++] = u.bytes[uRowStart + col * uPixelStride];
      }
    }
    return nv21;
  }

  Rect _overlayRect(Size size) {
    const documentFrameRatio = 1.42;

    double width, height;
    if (size.height > size.width) {
      width = size.width * 0.9;
      height = width / documentFrameRatio;
    } else {
      height = size.height * 0.75;
      width = height * documentFrameRatio;
    }

    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2 - 60.0,
      width,
      height,
    );
  }

  Rect _previewRect(Size size) {
    const previewAspect = 9 / 16;

    double baseW, baseH;
    if (size.width / size.height > previewAspect) {
      baseH = size.height;
      baseW = baseH * previewAspect;
    } else {
      baseW = size.width;
      baseH = baseW / previewAspect;
    }

    final scaledW = baseW * _previewScale;
    final scaledH = baseH * _previewScale;

    return Rect.fromLTWH(
      (size.width - scaledW) / 2,
      (size.height - scaledH) / 2,
      scaledW,
      scaledH,
    );
  }
}
