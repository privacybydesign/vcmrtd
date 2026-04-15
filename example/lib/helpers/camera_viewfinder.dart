import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_overlay.dart';
import '../routing.dart';

/// Which platform pixel format the camera is delivering.
enum FrameFormat { nv21, bgra8888 }

/// Lightweight token passed on every frame — no byte conversion happens here.
/// Each OCR engine extracts what it needs in its own way after the busy check.
class OcrFrame {
  final CameraImage image;
  final int rotation;
  final FrameFormat format;
  final double roiLeft;
  final double roiTop;
  final double roiWidth;
  final double roiHeight;

  const OcrFrame({
    required this.image,
    required this.rotation,
    required this.format,
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
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  Size? _viewSize;
  double _previewScale = 1.0;

  /// Every camera operation chains onto this future.
  /// Guarantees strict sequential execution and prevents start/stop races.
  Future<void> _cameraChain = Future.value();

  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _enqueue(_initAndStart);
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
    _enqueue(_doStop);
    super.dispose();
  }

  @override
  void didPush() => _enqueue(_doStart);

  @override
  void didPushNext() => _enqueue(_doStop);

  @override
  void didPopNext() => _enqueue(_doStart);

  @override
  void didPop() => _enqueue(_doStop);

  void _enqueue(Future<void> Function() action) {
    _cameraChain = _cameraChain
        .then((_) => action())
        .catchError((Object e, StackTrace st) => Error.throwWithStackTrace(e, st));
  }

  /// Discovers cameras and selects the correct index, then starts the feed.
  /// Runs inside the queue so _cameras is always populated before any
  /// subsequent start or stop can execute.
  Future<void> _initAndStart() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == widget.initialDirection && c.sensorOrientation == 90);
    if (_cameraIndex == -1) {
      _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == widget.initialDirection);
    }
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _doStart();
  }

  Future<void> _doStart() async {
    if (_cameras.isEmpty) return;
    await _doStop();
    if (!mounted) return;

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    _controller = controller;
    await _controller!.startImageStream(_onCameraImage);
    if (mounted) setState(() {});
  }

  Future<void> _doStop() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    await c.stopImageStream().catchError((_) {});
    await c.dispose().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final body = _liveFeedBody();
    return Scaffold(body: widget.showOverlay ? MRZCameraOverlay(child: body) : body);
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized != true) return const SizedBox.shrink();

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

  /// Cheap per-frame callback: rotation + ROI only, no byte conversion.
  /// Byte work happens in the scanner after the busy check.
  void _onCameraImage(CameraImage image) {
    if (_controller == null || _viewSize == null) return;

    final camera = _cameras[_cameraIndex];
    final size = _viewSize!;

    final int rotation;
    if (Platform.isAndroid) {
      final comp = _orientations[_controller!.value.deviceOrientation] ?? 0;
      rotation = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + comp) % 360
          : (camera.sensorOrientation - comp + 360) % 360;
    } else {
      rotation = camera.sensorOrientation;
    }

    final preview = _previewRect(size);
    final overlay = _overlayRect(size);
    final intersection = overlay.intersect(preview);
    final roi = intersection.isEmpty ? preview : intersection;

    widget.onImage(
      OcrFrame(
        image: image,
        rotation: rotation,
        format: Platform.isAndroid ? FrameFormat.nv21 : FrameFormat.bgra8888,
        roiLeft: ((roi.left - preview.left) / preview.width).clamp(0.0, 1.0),
        roiTop: ((roi.top - preview.top) / preview.height).clamp(0.0, 1.0),
        roiWidth: (roi.width / preview.width).clamp(0.0, 1.0),
        roiHeight: (roi.height / preview.height).clamp(0.0, 1.0),
      ),
    );
  }

  Rect _overlayRect(Size size) {
    const ratio = 1.42;
    final double w, h;
    if (size.height > size.width) {
      w = size.width * 0.9;
      h = w / ratio;
    } else {
      h = size.height * 0.75;
      w = h * ratio;
    }
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2 - 60.0, w, h);
  }

  Rect _previewRect(Size size) {
    const previewAspect = 9 / 16;
    final double baseW, baseH;
    if (size.width / size.height > previewAspect) {
      baseH = size.height;
      baseW = baseH * previewAspect;
    } else {
      baseW = size.width;
      baseH = baseW / previewAspect;
    }
    final sw = baseW * _previewScale;
    final sh = baseH * _previewScale;
    return Rect.fromLTWH((size.width - sw) / 2, (size.height - sh) / 2, sw, sh);
  }
}
