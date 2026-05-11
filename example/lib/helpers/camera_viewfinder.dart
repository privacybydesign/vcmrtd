import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_overlay.dart';
import '../routing.dart';

class OcrFrame {
  OcrFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotation,
    required this.roiLeft,
    required this.roiTop,
    required this.roiWidth,
    required this.roiHeight,
    required this.isNv21,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  // Actual row stride — may include padding on iOS BGRA.
  final int bytesPerRow;
  final int rotation;
  final double roiLeft;
  final double roiTop;
  final double roiWidth;
  final double roiHeight;
  // true = tightly-packed NV21 (Android), false = BGRA8888 (iOS).
  final bool isNv21;

  /// Returns a copy of this frame with bytes cropped to the overlay ROI.
  OcrFrame cropToRoi() {
    final roi = _roiRect();
    if (isNv21) {
      final (cropped, w, h) = _cropNv21(roi.x, roi.y, roi.w, roi.h);
      return _withCrop(cropped, w, h, w);
    } else {
      final (cropped, w, h, bpr) = _cropBgra(roi.x, roi.y, roi.w, roi.h);
      return _withCrop(cropped, w, h, bpr);
    }
  }

  OcrFrame _withCrop(Uint8List b, int w, int h, int bpr) => OcrFrame(
    bytes: b,
    width: w,
    height: h,
    bytesPerRow: bpr,
    rotation: rotation,
    roiLeft: 0,
    roiTop: 0,
    roiWidth: 1,
    roiHeight: 1,
    isNv21: isNv21,
  );

  // Converts screen-space ROI fractions to sensor-space pixel rect,
  // matching the rotation transform in TesseractOcrEngine.kt.
  ({int x, int y, int w, int h}) _roiRect() => switch (rotation) {
    90 => (
      x: (roiTop * width).toInt(),
      y: ((1.0 - roiLeft - roiWidth) * height).toInt(),
      w: (roiHeight * width).toInt(),
      h: (roiWidth * height).toInt(),
    ),
    270 => (
      x: ((1.0 - roiTop - roiHeight) * width).toInt(),
      y: (roiLeft * height).toInt(),
      w: (roiHeight * width).toInt(),
      h: (roiWidth * height).toInt(),
    ),
    180 => (
      x: ((1.0 - roiLeft - roiWidth) * width).toInt(),
      y: ((1.0 - roiTop - roiHeight) * height).toInt(),
      w: (roiWidth * width).toInt(),
      h: (roiHeight * height).toInt(),
    ),
    _ => (
      x: (roiLeft * width).toInt(),
      y: (roiTop * height).toInt(),
      w: (roiWidth * width).toInt(),
      h: (roiHeight * height).toInt(),
    ),
  };

  // Crops tightly-packed NV21. x/width rounded to even for UV-pair alignment.
  (Uint8List, int, int) _cropNv21(int x, int y, int w, int h) {
    final int cx = x.clamp(0, width - 2) & ~1;
    final int cy = y.clamp(0, height - 1);
    final int cw = ((w + 1) & ~1).clamp(2, width - cx);
    final int ch = (h & ~1).clamp(2, height - cy);
    if (cw < 2 || ch < 2) return (bytes, width, height);

    final int uvRows = ch ~/ 2;
    final dst = Uint8List(cw * ch + uvRows * cw);

    for (int r = 0; r < ch; r++) {
      final srcOff = (cy + r) * width + cx;
      dst.setRange(r * cw, r * cw + cw, bytes, srcOff);
    }

    // UV plane: starts at width*height, stride = width, col offset = cx.
    final int srcUvBase = width * height;
    final int dstUvBase = cw * ch;
    final int uvSrcRow = cy ~/ 2;
    for (int r = 0; r < uvRows; r++) {
      final srcOff = srcUvBase + (uvSrcRow + r) * width + cx;
      dst.setRange(dstUvBase + r * cw, dstUvBase + r * cw + cw, bytes, srcOff);
    }

    return (dst, cw, ch);
  }

  // Crops BGRA8888. Handles row padding via bytesPerRow.
  (Uint8List, int, int, int) _cropBgra(int x, int y, int w, int h) {
    final int cx = x.clamp(0, width - 1);
    final int cy = y.clamp(0, height - 1);
    final int cw = w.clamp(1, width - cx);
    final int ch = h.clamp(1, height - cy);
    final int dstBpr = cw * 4;

    final dst = Uint8List(ch * dstBpr);
    for (int r = 0; r < ch; r++) {
      final srcOff = (cy + r) * bytesPerRow + cx * 4;
      dst.setRange(r * dstBpr, r * dstBpr + dstBpr, bytes, srcOff);
    }
    return (dst, cw, ch, dstBpr);
  }
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
    } catch (_) {}
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
        _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == widget.initialDirection);
      }
      if (_cameraIndex == -1) _cameraIndex = 0;
    } catch (_) {}

    await _startLiveFeed();
  }

  Future<void> _startLiveFeed() async {
    if (_cameras.isEmpty) return;
    if (_controller != null) await _stopLiveFeed();

    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _stopLiveFeed() async {
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await controller?.stopImageStream();
    await controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _liveFeedBody();
    return Scaffold(body: widget.showOverlay ? MRZCameraOverlay(child: body) : body);
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
              child: AspectRatio(aspectRatio: 9 / 16, child: CameraPreview(_controller!)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_controller == null || _viewSize == null) return;
    // Android: 3-plane YUV420. iOS: 1-plane BGRA8888.
    if (Platform.isAndroid && image.planes.length < 3) return;
    if (!Platform.isAndroid && image.planes.isEmpty) return;

    final camera = _cameras[_cameraIndex];
    final rotationComp = _orientations[_controller!.value.deviceOrientation] ?? 0;

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

    final Uint8List bytes;
    final int bytesPerRow;
    final bool isNv21;

    if (Platform.isAndroid) {
      bytes = _yuv420ToNv21(image);
      bytesPerRow = image.width;
      isNv21 = true;
    } else {
      bytes = image.planes[0].bytes;
      bytesPerRow = image.planes[0].bytesPerRow;
      isNv21 = false;
    }

    widget.onImage(
      OcrFrame(
        bytes: bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: bytesPerRow,
        rotation: rotation,
        roiLeft: ((safeRoi.left - preview.left) / preview.width).clamp(0.0, 1.0),
        roiTop: ((safeRoi.top - preview.top) / preview.height).clamp(0.0, 1.0),
        roiWidth: (safeRoi.width / preview.width).clamp(0.0, 1.0),
        roiHeight: (safeRoi.height / preview.height).clamp(0.0, 1.0),
        isNv21: isNv21,
      ),
    );
  }

  Uint8List _yuv420ToNv21(CameraImage img) {
    final int width = img.width;
    final int height = img.height;
    final int ySize = width * height;
    final Uint8List nv21 = Uint8List(ySize + width * height ~/ 2);

    final yPlane = img.planes[0];
    final int yRowStride = yPlane.bytesPerRow;
    if (yRowStride == width) {
      nv21.setRange(0, ySize, yPlane.bytes);
    } else {
      for (int row = 0; row < height; row++) {
        nv21.setRange(row * width, row * width + width, yPlane.bytes, row * yRowStride);
      }
    }

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

    return Rect.fromLTWH((size.width - width) / 2, (size.height - height) / 2 - 60.0, width, height);
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

    return Rect.fromLTWH((size.width - scaledW) / 2, (size.height - scaledH) / 2, scaledW, scaledH);
  }
}
