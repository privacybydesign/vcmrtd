import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/helpers/face_alignment_camera.dart';

// ── Screen flow ──────────────────────────────────────────────────────────────
//
// Face-alignment only. The verification/matching and liveness logic has been
// removed; this screen demonstrates the two alignment outputs of the
// `face_verification` package:
//   • NFC route   — the document photo (nfcImageBytes) is aligned in the
//     background as soon as the models load.
//   • Selfie route — the live front-camera feed is aligned frame by frame; the
//     most frontal aligned crop is kept.
// The result screen shows both aligned 112×112 faces side by side.

enum AlignmentState { idle, capturing, processing, result }

// ── Widget ───────────────────────────────────────────────────────────────────

class FlutterFaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;

  // Test-only: skips camera + model bootstrap so the widget can be driven
  // through its states without a real camera or TFLite runtime.
  @visibleForTesting
  final bool skipBootstrapForTesting;

  const FlutterFaceVerificationScreen({super.key, required this.nfcImageBytes, required this.onBackPressed})
    : skipBootstrapForTesting = false;

  @visibleForTesting
  const FlutterFaceVerificationScreen.test({super.key, this.nfcImageBytes, required this.onBackPressed})
    : skipBootstrapForTesting = true;

  @override
  State<FlutterFaceVerificationScreen> createState() => FlutterFaceVerificationScreenState();
}

// ── State ────────────────────────────────────────────────────────────────────

class FlutterFaceVerificationScreenState extends State<FlutterFaceVerificationScreen> with WidgetsBindingObserver {
  static const Map<DeviceOrientation, int> _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // Number of accepted aligned frames sampled before picking the most frontal.
  static const int _selfieSampleTarget = 6;

  final FaceDetectorService _detector = FaceDetectorService();
  CameraController? _cameraController;
  CameraDescription? _activeCamera;

  AlignmentState _state = AlignmentState.idle;
  String? _errorMessage;
  String? _alignTip;

  bool _modelsReady = false;
  bool _isDisposed = false;
  bool _cameraOpening = false;
  bool _cameraClosing = false;

  // Background alignment of the document (NFC) photo.
  bool _nfcAligning = false;
  Uint8List? _alignedNfcPng;

  // Best (most frontal) aligned selfie collected during capture.
  Uint8List? _alignedSelfiePng;
  img.Image? _bestSelfie;
  double _bestSelfieYaw = double.infinity;
  int _selfieSampleCount = 0;

  // Frame pipeline (single-flight: drop frames while one is being processed).
  CameraImage? _pendingImage;
  bool _isProcessingFrame = false;
  int _frameToken = 0;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.skipBootstrapForTesting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _modelsReady = true);
      });
    } else {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeEverything());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_stopCapture(disposeCamera: true));
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _state == AlignmentState.idle &&
        (_cameraController == null || _cameraController?.value.isInitialized != true)) {
      _openCamera();
    }
  }

  // ── Bootstrap & cleanup ───────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _openCamera();
    if (!mounted) return;
    try {
      await _detector.initialize();
      if (!mounted) return;
      setState(() => _modelsReady = true);
      // Align the document photo eagerly so it is ready on the result screen.
      final nfc = widget.nfcImageBytes;
      if (nfc != null && nfc.isNotEmpty) {
        unawaited(_alignNfcPhoto(nfc));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not initialize face alignment: $e');
    }
  }

  Future<void> _alignNfcPhoto(Uint8List bytes) async {
    if (mounted) setState(() => _nfcAligning = true);
    Uint8List? png;
    try {
      final decoded = await decodeNfcImage(bytes);
      if (decoded != null) {
        final aligned = _detector.detectAndCrop(decoded);
        if (aligned != null) png = Uint8List.fromList(img.encodePng(aligned));
      }
    } catch (_) {
      png = null;
    }
    if (!mounted) return;
    setState(() {
      _alignedNfcPng = png;
      _nfcAligning = false;
    });
  }

  Future<void> _disposeEverything() async {
    await _stopCapture(disposeCamera: true);
    await _detector.close();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    if (_isDisposed || _cameraOpening || _cameraClosing) return;
    if (_cameraController?.value.isInitialized == true) return;
    _cameraOpening = true;
    try {
      final cameras = await availableCameras();
      if (!mounted || _isDisposed) return;
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      if (!mounted || _isDisposed) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _cameraController = ctrl;
        _activeCamera = front;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted && !_isDisposed) setState(() => _errorMessage = 'Could not open camera: $e');
    } finally {
      _cameraOpening = false;
    }
  }

  Future<void> _stopCapture({required bool disposeCamera}) async {
    _pendingImage = null;
    _isProcessingFrame = false;
    _frameToken++;
    final ctrl = _cameraController;
    if (ctrl == null) return;
    try {
      if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
    } catch (_) {}
    if (disposeCamera) {
      _cameraClosing = true;
      try {
        await ctrl.dispose();
      } catch (_) {}
      if (identical(_cameraController, ctrl)) _cameraController = null;
      _cameraClosing = false;
    }
  }

  int? _cameraFrameRotation() {
    final ctrl = _cameraController;
    final camera = _activeCamera ?? ctrl?.description;
    if (ctrl == null || camera == null) return null;
    if (camera.lensDirection == CameraLensDirection.front) {
      // iOS AVFoundation delivers BGRA buffers already portrait. Android Camera2
      // delivers raw YUV in sensor orientation and needs the correction.
      if (Platform.isIOS) return 0;
      return camera.sensorOrientation;
    }
    final rotationComp = _orientations[ctrl.value.deviceOrientation] ?? 0;
    return (camera.sensorOrientation - rotationComp + 360) % 360;
  }

  // ── Selfie capture & alignment ──────────────────────────────────────────────

  Future<void> _startCapture() async {
    if (!_isReady || _state != AlignmentState.idle) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    _detector.resetTracking();
    _bestSelfie = null;
    _alignedSelfiePng = null;
    _bestSelfieYaw = double.infinity;
    _selfieSampleCount = 0;
    setState(() {
      _state = AlignmentState.capturing;
      _alignTip = null;
    });
    try {
      if (!ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _state = AlignmentState.idle;
          _errorMessage = 'Could not start camera stream: $e';
        });
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed || _state != AlignmentState.capturing || _cameraClosing) return;
    _pendingImage = image;
    if (!_isProcessingFrame) {
      _isProcessingFrame = true;
      unawaited(_processFrames(_frameToken));
    }
  }

  Future<void> _processFrames(int token) async {
    try {
      while (_state == AlignmentState.capturing && token == _frameToken && !_isDisposed) {
        final image = _pendingImage;
        if (image == null) break;
        _pendingImage = null;
        final rotation = _cameraFrameRotation();
        if (rotation == null) continue;

        final upright = cameraImageToUpright(image, rotation);
        if (upright == null) continue;
        final face = _detector.detectPrimaryFace(upright, mode: FaceAlignmentMode.selfie);

        if (face == null) {
          if (mounted && _alignTip != 'noFace') setState(() => _alignTip = 'noFace');
          continue;
        }
        if (mounted && _alignTip != 'holdStill') setState(() => _alignTip = 'holdStill');

        // Keep the most frontal crop (smallest absolute yaw).
        final yaw = (face.yawDegrees ?? 90.0).abs();
        if (yaw < _bestSelfieYaw) {
          _bestSelfieYaw = yaw;
          _bestSelfie = face.alignedFace112;
        }
        _selfieSampleCount++;
        if (_selfieSampleCount >= _selfieSampleTarget && _bestSelfie != null) {
          await _finalizeCapture();
          return;
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _state = AlignmentState.idle;
          _errorMessage = 'Frame processing error: $e';
        });
      }
    } finally {
      if (token == _frameToken) _isProcessingFrame = false;
    }
  }

  Future<void> _finalizeCapture() async {
    final best = _bestSelfie;
    if (best == null) return;
    if (mounted) setState(() => _state = AlignmentState.processing);
    await _stopCapture(disposeCamera: false);
    final png = Uint8List.fromList(img.encodePng(best));
    if (!mounted || _isDisposed) return;
    setState(() {
      _alignedSelfiePng = png;
      _state = AlignmentState.result;
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _retry() async {
    await _stopCapture(disposeCamera: true);
    if (_isDisposed || !mounted) return;
    setState(() {
      _state = AlignmentState.idle;
      _errorMessage = null;
      _alignTip = null;
      _alignedSelfiePng = null;
      _bestSelfie = null;
      _bestSelfieYaw = double.infinity;
      _selfieSampleCount = 0;
    });
    await _openCamera();
  }

  Future<void> _handleBack() async {
    await _stopCapture(disposeCamera: true);
    if (_isDisposed) return;
    widget.onBackPressed();
  }

  // ── Test hooks ──────────────────────────────────────────────────────────────

  @visibleForTesting
  AlignmentState get debugState => _state;
  @visibleForTesting
  String? get debugAlignTip => _alignTip;
  @visibleForTesting
  bool get debugModelsReady => _modelsReady;

  // Jumps straight to the result screen with the supplied aligned PNGs so the
  // result UI can be verified without a camera or TFLite runtime.
  @visibleForTesting
  void debugShowResult({Uint8List? selfiePng, Uint8List? nfcPng}) {
    setState(() {
      _alignedSelfiePng = selfiePng;
      _alignedNfcPng = nfcPng;
      _nfcAligning = false;
      _state = AlignmentState.result;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Alignment'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  bool get _isReady => widget.skipBootstrapForTesting
      ? _modelsReady
      : (_modelsReady && _cameraController?.value.isInitialized == true);

  Widget _buildBody() {
    if (_errorMessage != null) return _buildErrorScreen();
    if (_state == AlignmentState.idle && !_isReady) return _buildLoadingScreen();
    return switch (_state) {
      AlignmentState.idle => _buildIdleScreen(),
      AlignmentState.capturing => _buildCapturingScreen(),
      AlignmentState.processing => _buildProcessingScreen(),
      AlignmentState.result => _buildResultScreen(),
    };
  }

  Widget _buildLoadingScreen() {
    final cameraReady = _cameraController?.value.isInitialized == true;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face_retouching_natural, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Setting up face alignment',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text('This only takes a moment', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 28),
              _LoadingStage(label: 'Opening camera', done: cameraReady),
              const SizedBox(height: 10),
              _LoadingStage(label: 'Loading face models', done: _modelsReady),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('Opening camera...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    final preview = ctrl.value.previewSize;
    if (preview == null) {
      return ColoredBox(color: Colors.black, child: CameraPreview(ctrl));
    }
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: preview.height, height: preview.width, child: CameraPreview(ctrl)),
          ),
        ),
      ),
    );
  }

  Widget _buildOvalOverlay() => const Positioned.fill(child: CustomPaint(painter: _FaceOvalPainter()));

  Widget _buildIdleScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        _buildOvalOverlay(),
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    _FaceStepRow(number: '1', text: 'Center your face inside the oval'),
                    SizedBox(height: 4),
                    _FaceStepRow(number: '2', text: 'Tap the button below'),
                    SizedBox(height: 4),
                    _FaceStepRow(number: '3', text: 'Hold still while we align your face'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isReady ? _startCapture : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.face),
                  label: const Text('Align my face'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturingScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        _buildOvalOverlay(),
        if (_buildTipCard() != null) Positioned(top: 16, left: 16, right: 16, child: _buildTipCard()!),
      ],
    );
  }

  Widget? _buildTipCard() {
    final message = switch (_alignTip) {
      'noFace' => 'Position your face in the oval',
      'holdStill' => 'Hold still…',
      _ => null,
    };
    if (message == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingScreen() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text('Aligning face...', style: TextStyle(fontSize: 16)),
      ],
    ),
  );

  Widget _buildErrorScreen() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _handleBack, child: const Text('Go Back')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    ),
  );

  Widget _buildResultScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.face_retouching_natural, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Aligned faces',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Both faces aligned to the 112×112 ArcFace template',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AlignedFaceTile(label: 'Document (NFC)', png: _alignedNfcPng, loading: _nfcAligning),
              _AlignedFaceTile(label: 'Selfie', png: _alignedSelfiePng, loading: false),
            ],
          ),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _AlignedFaceTile extends StatelessWidget {
  const _AlignedFaceTile({required this.label, required this.png, required this.loading});

  final String label;
  final Uint8List? png;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const double size = 140;
    Widget content;
    if (png != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(png!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    } else {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        alignment: Alignment.center,
        child: loading
            ? const CircularProgressIndicator()
            : const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No face found', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LoadingStage extends StatelessWidget {
  const _LoadingStage({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: done
              ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)
              : const CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: done ? Colors.white : Colors.white70, fontSize: 14)),
      ],
    );
  }
}

class _FaceStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _FaceStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  const _FaceOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Size the oval to a face-shaped 3:4 (w:h), fitting inside the screen.
    final ovalWidth = math.min(size.width * 0.80, size.height * 0.90 * (3 / 4));
    final ovalHeight = ovalWidth * (4 / 3);
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.46),
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: 0.50));
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_FaceOvalPainter old) => false;
}
