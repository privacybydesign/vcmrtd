import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/helpers/face_alignment_camera.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/services/face_verification_client.dart';

final _log = Logger('FaceVerificationScreen');

// ── Screen flow ──────────────────────────────────────────────────────────────
//
// Remote face verification with on-device positioning:
//   • MediaPipe (the `face_verification` package) runs locally on each camera
//     frame purely to *position* the face — it tells the user to centre and
//     face the camera, and gates which frames are worth sending.
//   • The actual recognition + liveness/anti-spoofing run on the remote
//     face-verification-service. Selected frames are JPEG-encoded and streamed
//     over a signed WebSocket; the service replies with per-frame scores and a
//     final verification result.
//
// The binding key that authenticates the stream is derived from the raw DG2
// bytes read over NFC, so only the wallet that read the chip can stream against
// the session the issuer created.

enum VerifyState { idle, connecting, verifying, result }

// ── Widget ───────────────────────────────────────────────────────────────────

class FlutterFaceVerificationScreen extends StatefulWidget {
  final FaceVerificationArgs args;
  final VoidCallback onBackPressed;

  // Test-only: skips camera + model bootstrap so the widget can be driven
  // through its states without a real camera or TFLite runtime.
  @visibleForTesting
  final bool skipBootstrapForTesting;

  const FlutterFaceVerificationScreen({super.key, required this.args, required this.onBackPressed})
    : skipBootstrapForTesting = false;

  @visibleForTesting
  const FlutterFaceVerificationScreen.test({super.key, required this.args, required this.onBackPressed})
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

  // Maximum absolute yaw (degrees) for a frame to be considered frontal enough
  // to bother sending to the verification service.
  static const double _maxYawDegrees = 25.0;

  // JPEG quality for streamed frames — high enough for the SDK, small enough to
  // keep the per-frame round trip quick.
  static const int _frameJpegQuality = 80;

  final FaceDetectorService _detector = FaceDetectorService();
  CameraController? _cameraController;
  CameraDescription? _activeCamera;

  VerifyState _state = VerifyState.idle;
  String? _errorMessage;
  String? _alignTip;

  bool _modelsReady = false;
  bool _isDisposed = false;
  bool _cameraOpening = false;
  bool _cameraClosing = false;

  // Remote verification stream + live progress.
  FaceVerificationStream? _stream;
  FaceVerificationComplete? _completion;
  int _framesProcessed = 0;
  double? _lastMatchScore;
  double? _lastLivenessScore;

  // Frame pipeline (single-flight: drop frames while one is being processed).
  CameraImage? _pendingImage;
  bool _isProcessingFrame = false;
  int _frameToken = 0;

  bool get _canVerify => widget.args.canVerifyRemotely;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final s = widget.args.faceSession;
    _log.info(
      'Face verification screen opened: canVerifyRemotely=${widget.args.canVerifyRemotely}, '
      'faceSessionId=${s?.faceSessionId}, '
      'hasReferencePhoto=${widget.args.referencePhotoBytes?.isNotEmpty ?? false}, '
      'wsUrl=${s?.resolvedWebsocketUrl}',
    );
    if (!widget.args.canVerifyRemotely) {
      _log.warning(
        'Remote face verification unavailable — no face session was started for this document '
        '(e.g. a driving licence has no DG2 portrait, or the issuer has face verification disabled).',
      );
    }
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
        _state == VerifyState.idle &&
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
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not initialize face detection: $e');
    }
  }

  Future<void> _disposeEverything() async {
    await _stopCapture(disposeCamera: true);
    await _stream?.dispose();
    _stream = null;
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

  // ── Verification ─────────────────────────────────────────────────────────────

  Future<void> _start() async {
    if (!_isReady || _state != VerifyState.idle) return;
    final args = widget.args;
    final session = args.faceSession;
    if (session == null || args.referencePhotoBytes == null) {
      _log.warning(
        'Cannot start remote verification: faceSession=${session?.faceSessionId}, '
        'hasReferencePhoto=${args.referencePhotoBytes != null}',
      );
      return;
    }

    final wsUrl = session.resolvedWebsocketUrl;
    if (wsUrl == null) {
      _log.warning('Verification session ${session.faceSessionId} has no stream URL');
      setState(() => _errorMessage = 'Verification session has no stream URL');
      return;
    }
    _log.info('Starting remote verification: session=${session.faceSessionId}, wsUrl=$wsUrl');

    setState(() {
      _state = VerifyState.connecting;
      _errorMessage = null;
      _alignTip = null;
    });

    final bindingKey = deriveBindingKey(session.faceSessionId, args.referencePhotoBytes!);
    final stream = FaceVerificationStream(
      websocketUrl: wsUrl,
      sessionId: session.faceSessionId,
      bindingKey: bindingKey,
    );

    try {
      await stream.connect();
    } catch (e) {
      await stream.dispose();
      if (mounted && !_isDisposed) {
        setState(() {
          _state = VerifyState.idle;
          _errorMessage = 'Could not connect to verification service: $e';
        });
      }
      return;
    }

    if (!mounted || _isDisposed) {
      await stream.dispose();
      return;
    }

    _stream = stream;
    _detector.resetTracking();
    _framesProcessed = 0;
    _lastMatchScore = null;
    _lastLivenessScore = null;

    unawaited(
      stream.onComplete
          .then(_onVerificationComplete)
          .catchError((Object e) => _onStreamError(e)),
    );

    setState(() => _state = VerifyState.verifying);

    final ctrl = _cameraController;
    try {
      if (ctrl != null && ctrl.value.isInitialized && !ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _state = VerifyState.idle;
          _errorMessage = 'Could not start camera stream: $e';
        });
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed || _state != VerifyState.verifying || _cameraClosing) return;
    _pendingImage = image;
    if (!_isProcessingFrame) {
      _isProcessingFrame = true;
      unawaited(_processFrames(_frameToken));
    }
  }

  Future<void> _processFrames(int token) async {
    try {
      while (_state == VerifyState.verifying &&
          token == _frameToken &&
          !_isDisposed &&
          _stream != null &&
          !_stream!.isCompleted) {
        final image = _pendingImage;
        if (image == null) break;
        _pendingImage = null;

        final rotation = _cameraFrameRotation();
        if (rotation == null) continue;
        final upright = cameraImageToUpright(image, rotation);
        if (upright == null) continue;

        // MediaPipe positioning: only send frontal, well-positioned faces.
        final face = _detector.detectPrimaryFace(upright, mode: FaceAlignmentMode.selfie);
        if (face == null) {
          _setTip('noFace');
          continue;
        }
        final yaw = (face.yawDegrees ?? 90.0).abs();
        if (yaw > _maxYawDegrees) {
          _setTip('turnToCamera');
          continue;
        }
        _setTip('holdStill');

        final jpeg = Uint8List.fromList(img.encodeJpg(upright, quality: _frameJpegQuality));
        final result = await _stream?.sendFrame(jpeg);
        if (result != null && mounted && !_isDisposed) {
          setState(() {
            _framesProcessed = result.framesProcessed;
            _lastMatchScore = result.matchScore;
            _lastLivenessScore = result.livenessScore;
          });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _state = VerifyState.idle;
          _errorMessage = 'Frame processing error: $e';
        });
      }
    } finally {
      if (token == _frameToken) _isProcessingFrame = false;
    }
  }

  void _setTip(String tip) {
    if (mounted && _alignTip != tip) setState(() => _alignTip = tip);
  }

  Future<void> _onVerificationComplete(FaceVerificationComplete completion) async {
    await _stopCapture(disposeCamera: false);
    if (!mounted || _isDisposed) return;
    setState(() {
      _completion = completion;
      _state = VerifyState.result;
    });
  }

  void _onStreamError(Object e) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _state = VerifyState.idle;
      _errorMessage = 'Verification failed: $e';
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _retry() async {
    await _stopCapture(disposeCamera: true);
    await _stream?.dispose();
    _stream = null;
    if (_isDisposed || !mounted) return;
    setState(() {
      _state = VerifyState.idle;
      _errorMessage = null;
      _alignTip = null;
      _completion = null;
      _framesProcessed = 0;
      _lastMatchScore = null;
      _lastLivenessScore = null;
    });
    await _openCamera();
  }

  Future<void> _handleBack() async {
    await _stopCapture(disposeCamera: true);
    await _stream?.dispose();
    _stream = null;
    if (_isDisposed) return;
    widget.onBackPressed();
  }

  // ── Test hooks ──────────────────────────────────────────────────────────────

  @visibleForTesting
  VerifyState get debugState => _state;
  @visibleForTesting
  String? get debugAlignTip => _alignTip;
  @visibleForTesting
  bool get debugModelsReady => _modelsReady;

  // Jumps straight to the result screen with a supplied completion so the result
  // UI can be verified without a camera, TFLite runtime, or network.
  @visibleForTesting
  void debugShowResult(FaceVerificationComplete completion) {
    setState(() {
      _completion = completion;
      _state = VerifyState.result;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
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
    if (_state == VerifyState.idle && !_isReady) return _buildLoadingScreen();
    return switch (_state) {
      VerifyState.idle => _buildIdleScreen(),
      VerifyState.connecting => _buildConnectingScreen(),
      VerifyState.verifying => _buildVerifyingScreen(),
      VerifyState.result => _buildResultScreen(),
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
                'Setting up face verification',
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
    if (!_canVerify) return _buildUnavailableScreen();
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
                    _FaceStepRow(number: '3', text: 'Look at the camera and hold still'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isReady ? _start : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.face),
                  label: const Text('Verify my face'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableScreen() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 16),
          const Text(
            'Face verification is not available',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'No verification session was started for this document. This requires '
            'a passport with a chip portrait and the issuer to have face verification enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _handleBack, child: const Text('Go Back')),
        ],
      ),
    ),
  );

  Widget _buildConnectingScreen() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text('Connecting to verification service…', style: TextStyle(fontSize: 16)),
      ],
    ),
  );

  Widget _buildVerifyingScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        _buildOvalOverlay(),
        if (_buildTipCard() != null) Positioned(top: 16, left: 16, right: 16, child: _buildTipCard()!),
        Positioned(bottom: 24, left: 20, right: 20, child: _buildProgressCard()),
      ],
    );
  }

  Widget _buildProgressCard() {
    String fmt(double? v) => v == null ? '—' : '${(v * 100).clamp(0, 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('Verifying…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProgressStat(label: 'Frames', value: '$_framesProcessed'),
              _ProgressStat(label: 'Match', value: fmt(_lastMatchScore)),
              _ProgressStat(label: 'Liveness', value: fmt(_lastLivenessScore)),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildTipCard() {
    final message = switch (_alignTip) {
      'noFace' => 'Position your face in the oval',
      'turnToCamera' => 'Look straight at the camera',
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
    final completion = _completion;
    final success = completion?.isSuccess ?? false;
    final livenessPassed = completion?.livenessPassed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            success ? Icons.verified_user : Icons.gpp_bad,
            size: 72,
            color: success ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'Face verified' : 'Verification failed',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _ResultRow(
            label: 'Result',
            value: completion?.result ?? 'unknown',
            ok: success,
          ),
          if (completion?.matchConfidence != null)
            _ResultRow(
              label: 'Match confidence',
              value: '${(completion!.matchConfidence! * 100).clamp(0, 100).toStringAsFixed(0)}%',
            ),
          if (livenessPassed != null)
            _ResultRow(
              label: 'Liveness',
              value: livenessPassed ? 'Passed' : 'Failed',
              ok: livenessPassed,
            ),
          _ResultRow(label: 'Frames processed', value: '${completion?.framesProcessed ?? 0}'),
          if ((completion?.verificationDurationMs ?? 0) > 0)
            _ResultRow(
              label: 'Duration',
              value: '${((completion!.verificationDurationMs) / 1000).toStringAsFixed(1)}s',
            ),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _handleBack, child: const Text('Done')),
        ],
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.ok});
  final String label;
  final String value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          Row(
            children: [
              if (ok != null) ...[
                Icon(ok! ? Icons.check_circle : Icons.cancel, size: 18, color: ok! ? Colors.green : Colors.red),
                const SizedBox(width: 6),
              ],
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
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
