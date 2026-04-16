import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _VerificationState { idle, activeLiveness, processing, result }

class VerificationResult {
  final double matchScore;
  final bool isLive;
  const VerificationResult({required this.matchScore, required this.isLive});
}

String _actionLabel(String action) => switch (action) {
  'BLINK' => 'Blink your eyes',
  'TURN_LEFT' => 'Turn your head left',
  'TURN_RIGHT' => 'Turn your head right',
  'MOUTH_OPEN' => 'Open your mouth',
  'SMILE' => 'Smile',
  _ => action,
};

IconData _actionIcon(String action) => switch (action) {
  'BLINK' => Icons.visibility_off,
  'TURN_LEFT' => Icons.arrow_back,
  'TURN_RIGHT' => Icons.arrow_forward,
  'MOUTH_OPEN' => Icons.sentiment_neutral,
  'SMILE' => Icons.sentiment_satisfied,
  _ => Icons.face,
};

/// NV21 packing — runs in a compute isolate.
/// Only called for the frame that is actually sent to the native side.
Uint8List? _packNv21Isolate(CameraImage image) {
  if (image.planes.length < 3) return null;

  final w = image.width;
  final h = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final uvPixelStride = vPlane.bytesPerPixel ?? 1;
  final uvRowStride = vPlane.bytesPerRow;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final uRowStride = uPlane.bytesPerRow;
  final yRowStride = yPlane.bytesPerRow;

  final uvHeight = h ~/ 2;
  final uvWidth = w ~/ 2;

  final out = Uint8List(8 + (w * h + uvHeight * uvWidth * 2));
  final header = ByteData.sublistView(out, 0, 8);
  header.setInt32(0, w, Endian.big);
  header.setInt32(4, h, Endian.big);

  var idx = 8;

  for (var row = 0; row < h; row++) {
    final rowStart = row * yRowStride;
    for (var col = 0; col < w; col++) {
      out[idx++] = yPlane.bytes[rowStart + col];
    }
  }

  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      final vIdx = row * uvRowStride + col * uvPixelStride;
      final uIdx = row * uRowStride + col * uPixelStride;
      if (vIdx < vPlane.bytes.length && uIdx < uPlane.bytes.length) {
        out[idx++] = vPlane.bytes[vIdx];
        out[idx++] = uPlane.bytes[uIdx];
      } else {
        out[idx++] = 128;
        out[idx++] = 128;
      }
    }
  }

  return out;
}

class FaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  static const double matchThreshold = 0.6;

  const FaceVerificationScreen({super.key, required this.nfcImageBytes, required this.onBackPressed});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> with WidgetsBindingObserver {
  static const _methodChannel = MethodChannel('foundation.privacybydesign.vcmrtd/face_verification');
  static const _eventChannel = EventChannel('foundation.privacybydesign.vcmrtd/liveness_events');

  CameraController? _cameraController;
  StreamSubscription<dynamic>? _eventSub;

  VerificationResult? _result;
  String? _errorMessage;
  _VerificationState _state = _VerificationState.idle;

  List<String> _actions = <String>[];
  String? _currentAction;
  Set<String> _completedActions = <String>{};
  bool _extraActionMode = false;
  bool _actionFlash = false;

  bool _cameraOpening = false;
  bool _cameraClosing = false;
  bool _isDisposed = false;
  bool _activeLivenessStopping = false;
  bool _startingLiveness = false;

  // ── Latest-frame-only: no queue, only the most recent frame ──
  // _pendingImage holds the latest CameraImage.
  // _isSending is true while packing + sending is in progress.
  CameraImage? _pendingImage;
  bool _isSending = false;
  int _frameToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
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
      unawaited(_stopActiveFlow(disposeCamera: true));
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _state == _VerificationState.idle &&
        (_cameraController == null || _cameraController?.value.isInitialized != true)) {
      _openCamera();
    }
  }

  Future<void> _disposeEverything() async {
    await _stopActiveFlow(disposeCamera: true);
  }

  Future<void> _stopActiveFlow({required bool disposeCamera}) async {
    if (_cameraClosing || _activeLivenessStopping) return;
    _activeLivenessStopping = true;

    try {
      _invalidateFramePipeline();

      await _eventSub?.cancel();
      _eventSub = null;

      try {
        await _methodChannel.invokeMethod<void>('stopActiveLiveness');
      } catch (_) {}

      final ctrl = _cameraController;
      if (ctrl != null) {
        await _disposeCameraController(ctrl, disposeCamera: disposeCamera);
      }
    } finally {
      _activeLivenessStopping = false;
    }
  }

  Future<void> _disposeCameraController(CameraController ctrl, {required bool disposeCamera}) async {
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

  void _invalidateFramePipeline() {
    _pendingImage = null;
    _isSending = false;
    _frameToken++;
  }

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
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      if (!mounted || _isDisposed) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _cameraController = ctrl;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not open camera: $e');
      }
    } finally {
      _cameraOpening = false;
    }
  }

  Future<void> _startActiveLiveness() async {
    if (_startingLiveness || _state == _VerificationState.activeLiveness) return;

    final ctrl = _cameraController;
    final nfcImage = widget.nfcImageBytes;
    if (_isDisposed || ctrl == null || !ctrl.value.isInitialized) return;
    if (nfcImage == null || nfcImage.isEmpty) {
      setState(() => _errorMessage = 'Missing NFC image');
      return;
    }

    _startingLiveness = true;
    try {
      _invalidateFramePipeline();

      await _eventSub?.cancel();
      _eventSub = _eventChannel.receiveBroadcastStream().listen(_onLivenessEvent, onError: _onLivenessStreamError);

      final actions = await _methodChannel.invokeMethod<List<dynamic>>('startActiveLiveness', {'nfcImage': nfcImage});

      if (!mounted || _isDisposed || actions == null || actions.isEmpty) return;

      setState(() {
        _state = _VerificationState.activeLiveness;
        _actions = actions.cast<String>();
        _currentAction = null; // wait for 'nextAction' event after alignment
        _completedActions = <String>{};
        _extraActionMode = false;
        _actionFlash = false;
        _errorMessage = null;
        _result = null;
      });

      if (!ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not start liveness: $e');
      }
    } finally {
      _startingLiveness = false;
    }
  }

  void _onLivenessStreamError(Object e) {
    if (mounted && !_isDisposed) {
      _invalidateFramePipeline();
      setState(() {
        _state = _VerificationState.idle;
        _currentAction = null;
        _errorMessage = 'Liveness error: $e';
      });
    }
  }

  /// Camera callback: store only the latest frame.
  /// If the previous frame is still being processed, overwrite it —
  /// the Kotlin side only processes ~12 FPS anyway.
  void _onCameraFrame(CameraImage image) {
    if (_isDisposed) return;
    if (_state != _VerificationState.activeLiveness) return;
    if (_cameraClosing || _activeLivenessStopping) return;

    // Store the latest frame (overwrite the previous one).
    _pendingImage = image;

    // Start a send cycle if one is not already running.
    if (!_isSending) {
      _isSending = true;
      final token = _frameToken;
      unawaited(_sendLatestFrame(token));
    }
  }

  /// Picks up the latest frame, sends it to Kotlin, then checks whether
  /// a newer frame arrived in the meantime.
  Future<void> _sendLatestFrame(int token) async {
    try {
      while (!_isDisposed && token == _frameToken && _state == _VerificationState.activeLiveness) {
        final image = _pendingImage;
        if (image == null) break; // no new frame, stop loop

        // Clear so we can detect if a newer frame arrives during packing.
        _pendingImage = null;

        // Pack NV21 in isolate
        final data = await compute(_packNv21Isolate, image);

        if (_isDisposed || token != _frameToken || _state != _VerificationState.activeLiveness || data == null) {
          continue;
        }

        // Send to Kotlin (stored in AtomicReference, returns immediately).
        await _methodChannel.invokeMethod<void>('processFrame', {'frame': data});

        // Check whether a newer frame arrived while we were sending.
        // If yes: loop and pick it up.
        // If no: break and wait for the next _onCameraFrame callback.
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _invalidateFramePipeline();
        setState(() {
          _state = _VerificationState.idle;
          _currentAction = null;
          _errorMessage = 'Frame processing error: $e';
        });
      }
    } finally {
      if (token == _frameToken) {
        _isSending = false;

        // Check if a pending frame arrived that we missed.
        if (_pendingImage != null && !_isDisposed && _state == _VerificationState.activeLiveness) {
          _isSending = true;
          unawaited(_sendLatestFrame(token));
        }
      }
    }
  }

  void _onLivenessEvent(dynamic event) {
    if (!mounted || _isDisposed) return;
    if (_state != _VerificationState.activeLiveness && _state != _VerificationState.processing) return;

    final map = Map<String, dynamic>.from(event as Map);
    final type = map['type'] as String;

    switch (type) {
      case 'actionDetected':
        final action = map['action'] as String;
        setState(() {
          _completedActions.add(action);
          _actionFlash = true;
        });
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_isDisposed) setState(() => _actionFlash = false);
        });

      case 'nextAction':
        setState(() {
          _currentAction = map['action'] as String;
        });

      case 'extraAction':
        final extra = map['action'] as String;
        setState(() {
          _extraActionMode = true;
          _actions = [..._actions, extra];
          _currentAction = extra;
        });

      case 'processing':
        _pendingImage = null;
        setState(() {
          _state = _VerificationState.processing;
          _currentAction = null;
        });

      case 'timeout':
        final action = map['action'] as String?;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Take your time — ${action != null ? _actionLabel(action) : 'perform the action'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );

      case 'complete':
        final passed = map['passed'] as bool;
        final matchScore = (map['matchScore'] as num?)?.toDouble() ?? 0.0;
        _onComplete(passed: passed, matchScore: matchScore);

      case 'error':
        final message = map['message']?.toString() ?? 'Unknown native error';
        _invalidateFramePipeline();
        setState(() {
          _state = _VerificationState.idle;
          _currentAction = null;
          _errorMessage = message;
        });
    }
  }

  void _onComplete({required bool passed, required double matchScore}) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    setState(() {
      _state = _VerificationState.result;
      _result = VerificationResult(matchScore: matchScore, isLive: passed);
    });
    unawaited(_stopActiveFlow(disposeCamera: false));
  }

  Future<void> _retry() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed || !mounted) return;
    setState(() {
      _result = null;
      _errorMessage = null;
      _state = _VerificationState.idle;
      _actions = <String>[];
      _currentAction = null;
      _completedActions = <String>{};
      _extraActionMode = false;
      _actionFlash = false;
    });
    await _openCamera();
  }

  Future<void> _handleBack() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed) return;
    widget.onBackPressed();
  }

  // ═══════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : switch (_state) {
                _VerificationState.idle => _buildIdle(),
                _VerificationState.activeLiveness => _buildActiveLiveness(),
                _VerificationState.processing => _buildProcessing(),
                _VerificationState.result => _buildResult(),
              },
      ),
    );
  }

  /// Oval face-guide overlay, sized and positioned to match the camera preview
  /// (same Center + AspectRatio 3/4 container) so it is correct on all devices.
  Widget _buildOvalOverlay() => const Center(
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: CustomPaint(painter: _FaceOvalPainter()),
    ),
  );

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
              Text('Opening camera…', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(aspectRatio: 3 / 4, child: CameraPreview(ctrl)),
      ),
    );
  }

  Widget _buildIdle() {
    final ready = _cameraController?.value.isInitialized == true;
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
                    _StepRow(number: '1', text: 'Center your face inside the oval'),
                    SizedBox(height: 4),
                    _StepRow(number: '2', text: 'Tap the button below'),
                    SizedBox(height: 4),
                    _StepRow(number: '3', text: 'Follow the on-screen prompts'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ready ? _startActiveLiveness : null,
                  icon: const Icon(Icons.face),
                  label: const Text('Start Verification'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveLiveness() {
    final action = _currentAction;
    final isAligning = action == null;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        if (_actionFlash) Container(color: Colors.green.withValues(alpha: 0.25)),
        if (isAligning) ..._buildAlignmentOverlay(),
        if (!isAligning) _buildActionChecklist(action),
        if (action != null) _buildActionInstruction(action),
      ],
    );
  }

  List<Widget> _buildAlignmentOverlay() => [
    _buildOvalOverlay(),
    Positioned(
      bottom: 40,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
            SizedBox(width: 10),
            Text('Hold still — reading your face…', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      ),
    ),
  ];

  Widget _buildActionChecklist(String action) => Positioned(
    top: 16,
    left: 16,
    right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _actions.asMap().entries.map((e) {
          final done = _completedActions.contains(e.value);
          final current = e.value == action;
          final iconWhenNotDone = current ? Icons.radio_button_checked : Icons.radio_button_unchecked;
          final itemIcon = done ? Icons.check_circle : iconWhenNotDone;
          final colorWhenNotDone = current ? Colors.white : Colors.white38;
          final itemColor = done ? Colors.green : colorWhenNotDone;
          final itemWeight = current ? FontWeight.bold : FontWeight.normal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(itemIcon, color: itemColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _actionLabel(e.value),
                    style: TextStyle(color: itemColor, fontWeight: itemWeight),
                  ),
                ),
                if (_extraActionMode && e.key == _actions.length - 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                    child: const Text('extra', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildActionInstruction(String action) => Positioned(
    bottom: 40,
    left: 24,
    right: 24,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_actionIcon(action), color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            _actionLabel(action),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  Widget _buildProcessing() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text('Verifying identity…', style: TextStyle(fontSize: 16)),
      ],
    ),
  );

  Widget _buildResult() {
    final r = _result!;
    final passed = r.matchScore > FaceVerificationScreen.matchThreshold && r.isLive;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel, size: 80, color: passed ? Colors.green : Colors.red),
          const SizedBox(height: 24),
          Text(
            passed ? 'Identity Verified' : 'Verification Failed',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            'Match score: ${(r.matchScore * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
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
}

/// A single numbered step row used in the idle-screen instruction card.
class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

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

/// Draws a semi-transparent dark overlay with an oval cutout in the centre.
/// The canvas is the same 3:4 AspectRatio widget as the camera preview, so
/// all measurements are relative to the actual camera view — not the screen.
class _FaceOvalPainter extends CustomPainter {
  const _FaceOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Canvas is the 3:4 camera view (width/height ≈ 0.75).
    // Target pixel aspect ratio ≈ 0.67 (portrait head shape):
    //   0.75 × wPct / hPct = 0.67  →  wPct/hPct ≈ 0.89
    // Use large values so the face fills the oval comfortably.
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.46),
      width: size.width * 0.80,
      height: size.height * 0.90,
    );

    // Dark overlay with the oval punched out.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: 0.50));
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Oval border on top.
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
