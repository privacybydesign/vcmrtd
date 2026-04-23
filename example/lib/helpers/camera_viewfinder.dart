import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_overlay.dart';
import '../routing.dart';

/// Engine-agnostic frame that the viewfinder hands to the scanner.
///
/// Contains the raw [CameraImage] so each OCR engine can do its own
/// byte conversion (ML Kit needs InputImage, Tesseract needs NV21 + ROI).
class CameraFrame {
  final CameraImage image;
  final int rotation;
  final Rect overlayRect;
  final Rect previewRect;

  const CameraFrame({
    required this.image,
    required this.rotation,
    required this.overlayRect,
    required this.previewRect,
  });
}

class MRZCameraView extends StatefulWidget {
  const MRZCameraView({
    super.key,
    required this.onFrame,
    this.initialDirection = CameraLensDirection.back,
    required this.showOverlay,
    this.useNv21 = false,
  });

  final Function(CameraFrame frame) onFrame;
  final CameraLensDirection initialDirection;
  final bool showOverlay;

  /// When true, requests [ImageFormatGroup.nv21] on Android so the camera
  /// delivers NV21 directly (1 plane, no conversion needed — fastest for
  /// Google ML Kit). When false, requests [ImageFormatGroup.yuv420] which
  /// gives 3 planes that can be converted to NV21 (needed by Tesseract).
  /// Ignored on iOS which always uses [ImageFormatGroup.bgra8888].
  final bool useNv21;

  @override
  MRZCameraViewState createState() => MRZCameraViewState();
}

class MRZCameraViewState extends State<MRZCameraView> with RouteAware {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  Size? _viewSize;
  double _previewScale = 1.0;

  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Camera init
  // ---------------------------------------------------------------------------

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
    } catch (e) {
      if (kDebugMode) print(e);
    }

    await _startLiveFeed();
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  ImageFormatGroup get _androidImageFormat => widget.useNv21 ? ImageFormatGroup.nv21 : ImageFormatGroup.yuv420;

  Future<void> _startLiveFeed() async {
    if (_cameras.isEmpty) return;

    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? _androidImageFormat : ImageFormatGroup.bgra8888,
    );

    _controller?.initialize().then((_) {
      if (!mounted) return;
      _controller?.startImageStream(_onCameraImage);
      setState(() {});
    });
  }

  /// Safely tears down the camera. Catches [CameraException] because dispose()
  /// can race with _startLiveFeed's .then() — the controller may already be
  /// disposed or the stream may not have started yet.
  Future<void> _stopLiveFeed() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      await c.stopImageStream();
    } on CameraException catch (_) {}
    try {
      await c.dispose();
    } on CameraException catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final body = _liveFeedBody();
    return Scaffold(body: widget.showOverlay ? MRZCameraOverlay(child: body) : body);
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized != true) {
      return const SizedBox.shrink();
    }

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

  // ---------------------------------------------------------------------------
  // Frame callback
  // ---------------------------------------------------------------------------

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

    widget.onFrame(
      CameraFrame(image: image, rotation: rotation, overlayRect: _overlayRect(size), previewRect: _previewRect(size)),
    );
  }

  // ---------------------------------------------------------------------------
  // Overlay / preview geometry
  // ---------------------------------------------------------------------------

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
