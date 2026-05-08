import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_engine.dart';

enum _VerificationState { idle, activeLiveness, processing, result }

class VerificationResult {
  final double matchScore;
  final bool isLive;
  final double? antiSpoofScore;
  final bool antiSpoofPassed;
  final double? rppgHr;
  final bool rppgPassed;
  final int rppgSampleCount;
  const VerificationResult({
    required this.matchScore,
    required this.isLive,
    this.antiSpoofScore,
    this.antiSpoofPassed = false,
    this.rppgHr,
    this.rppgPassed = false,
    this.rppgSampleCount = 0,
  });
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

class FlutterFaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;

  const FlutterFaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  });

  @override
  State<FlutterFaceVerificationScreen> createState() => _FlutterFaceVerificationScreenState();
}

class _FlutterFaceVerificationScreenState extends State<FlutterFaceVerificationScreen> with WidgetsBindingObserver {
  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final FaceVerificationEngine _engine = FaceVerificationEngine();

  CameraController? _cameraController;
  CameraDescription? _activeCamera;
  StreamSubscription<Map<String, dynamic>>? _eventSub;

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
  bool _engineReady = false;
  CameraImage? _pendingImage;
  bool _isSending = false;
  int _frameToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Engine init and camera opening are independent — run in parallel.
      await Future.wait(<Future<void>>[_engine.initialize(), _openCamera()]);
      if (!mounted) return;
      _eventSub = _engine.events.listen(_onLivenessEvent);
      setState(() => _engineReady = true);

      // Start NFC decode + detection + embedding in background so it's ready
      // before the user taps Start — eliminates the delay on first tap.
      final nfcImage = widget.nfcImageBytes;
      if (nfcImage != null && nfcImage.isNotEmpty) {
        unawaited(
          _engine.prepareNfcFaceEagerly(nfcImage).catchError((_) {
            // Silently swallowed — start() will retry when the user taps.
          }),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not initialize Flutter face engine: $e');
      }
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
    await _eventSub?.cancel();
    await _engine.dispose();
  }

  Future<void> _stopActiveFlow({required bool disposeCamera}) async {
    if (_cameraClosing || _activeLivenessStopping) return;
    _activeLivenessStopping = true;

    try {
      _invalidateFramePipeline();
      await _engine.stop();

      final ctrl = _cameraController;
      if (ctrl != null) {
        await _disposeCameraController(ctrl, disposeCamera: disposeCamera);
      }
    } finally {
      _activeLivenessStopping = false;
    }
  }

  void _invalidateFramePipeline() {
    _pendingImage = null;
    _isSending = false;
    _frameToken++;
  }

  bool get _isFrameLoopActive => !_isDisposed && _state == _VerificationState.activeLiveness;

  void _finalizeSendCycle(int token) {
    if (token != _frameToken) return;
    _isSending = false;
    if (_pendingImage != null && _isFrameLoopActive) {
      _isSending = true;
      unawaited(_sendLatestFrame(token));
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
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not open camera: $e');
      }
    } finally {
      _cameraOpening = false;
    }
  }

  Future<void> _startActiveLiveness() async {
    if (_startingLiveness || _state == _VerificationState.activeLiveness) return;
    if (!_engineReady) return;

    final ctrl = _cameraController;
    final nfcImage = widget.nfcImageBytes;
    if (_isDisposed || ctrl == null || !ctrl.value.isInitialized) return;
    if (nfcImage == null || nfcImage.isEmpty) {
      setState(() => _errorMessage = 'Missing NFC image');
      return;
    }

    setState(() => _startingLiveness = true);
    try {
      final actions = await _engine.start(nfcImage);
      if (!mounted || _isDisposed || actions.isEmpty) return;

      setState(() {
        _state = _VerificationState.activeLiveness;
        _actions = actions;
        _currentAction = null;
        _completedActions = <String>{};
        _extraActionMode = false;
        _actionFlash = false;
        _errorMessage = null;
        _result = null;
      });

      if (!ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onCameraFrame);
      }
    } catch (e, st) {
      debugPrint('LIVENESS START ERROR: $e\n$st');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not start liveness: $e');
      }
    } finally {
      if (mounted && !_isDisposed) setState(() => _startingLiveness = false);
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed) return;
    if (_state != _VerificationState.activeLiveness) return;
    if (_cameraClosing || _activeLivenessStopping) return;

    _pendingImage = image;

    if (!_isSending) {
      _isSending = true;
      final token = _frameToken;
      unawaited(_sendLatestFrame(token));
    }
  }

  Future<void> _sendLatestFrame(int token) async {
    try {
      while (_isFrameLoopActive && token == _frameToken) {
        final image = _pendingImage;
        if (image == null) break;

        _pendingImage = null;
        final rotation = _cameraFrameRotation();
        if (rotation == null) continue;

        await _engine.processFrame(image, rotation);
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
      _finalizeSendCycle(token);
    }
  }

  int? _cameraFrameRotation() {
    final ctrl = _cameraController;
    final camera = _activeCamera ?? ctrl?.description;
    if (ctrl == null || camera == null) return null;

    final rotationComp = _orientations[ctrl.value.deviceOrientation];
    if (rotationComp == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      return (camera.sensorOrientation + rotationComp) % 360;
    }
    return (camera.sensorOrientation - rotationComp + 360) % 360;
  }

  void _onLivenessEvent(Map<String, dynamic> map) {
    if (!mounted || _isDisposed) return;
    if (_state != _VerificationState.activeLiveness && _state != _VerificationState.processing) return;

    final type = map['type'] as String?;
    if (type == null) return;

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
        setState(() {
          _state = _VerificationState.processing;
          _currentAction = null;
        });

      case 'timeout':
        final action = map['action'] as String?;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Take your time - ${action != null ? _actionLabel(action) : 'perform the action'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );

      case 'complete':
        final passed = map['passed'] as bool;
        final matchScore = (map['matchScore'] as num?)?.toDouble() ?? 0.0;
        final antiSpoofScore = (map['antiSpoofScore'] as num?)?.toDouble();
        final antiSpoofPassed = (map['antiSpoofPassed'] as bool?) ?? false;
        final rppg = map['rppg'] as Map<String, dynamic>?;
        final rppgHr = (rppg?['hr'] as num?)?.toDouble();
        final rppgPassed = (rppg?['passed'] as bool?) ?? false;
        final rppgSampleCount = (rppg?['sampleCount'] as num?)?.toInt() ?? 0;
        _onComplete(
          passed: passed,
          matchScore: matchScore,
          antiSpoofScore: antiSpoofScore,
          antiSpoofPassed: antiSpoofPassed,
          rppgHr: rppgHr,
          rppgPassed: rppgPassed,
          rppgSampleCount: rppgSampleCount,
        );

      case 'error':
        final message = map['message']?.toString() ?? 'Unknown Flutter pipeline error';
        _invalidateFramePipeline();
        setState(() {
          _state = _VerificationState.idle;
          _currentAction = null;
          _errorMessage = message;
        });
    }
  }

  void _onComplete({
    required bool passed,
    required double matchScore,
    double? antiSpoofScore,
    bool antiSpoofPassed = false,
    double? rppgHr,
    bool rppgPassed = false,
    int rppgSampleCount = 0,
  }) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    setState(() {
      _state = _VerificationState.result;
      _result = VerificationResult(
        matchScore: matchScore,
        isLive: passed,
        antiSpoofScore: antiSpoofScore,
        antiSpoofPassed: antiSpoofPassed,
        rppgHr: rppgHr,
        rppgPassed: rppgPassed,
        rppgSampleCount: rppgSampleCount,
      );
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

  double _matchThreshold() {
    final issueDate = widget.photoIssueDate;
    if (issueDate == null) return 0.60;
    final ageYears = DateTime.now().difference(issueDate).inDays / 365.25;
    if (ageYears <= 3) return 0.65;
    if (ageYears <= 7) return 0.60;
    return 0.55;
  }

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
              Text('Opening camera...', style: TextStyle(color: Colors.white70)),
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
    final ready = _cameraController?.value.isInitialized == true && _engineReady;
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
                  onPressed: (ready && !_startingLiveness) ? _startActiveLiveness : null,
                  icon: _startingLiveness
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.face),
                  label: Text(_startingLiveness ? 'Preparing...' : 'Start Verification'),
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
            Text('Hold still - reading your face...', style: TextStyle(color: Colors.white70, fontSize: 15)),
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
        Text('Verifying identity...', style: TextStyle(fontSize: 16)),
      ],
    ),
  );

  Widget _buildResult() {
    final r = _result!;
    final threshold = _matchThreshold();
    final matchPassed = r.matchScore > threshold;
    final passed = matchPassed && r.isLive;

    Widget scoreRow(String label, String value, bool ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(value, style: TextStyle(color: ok ? Colors.green : Colors.red)),
              const SizedBox(width: 6),
              Icon(ok ? Icons.check : Icons.close, size: 16, color: ok ? Colors.green : Colors.red),
            ],
          ),
        ],
      ),
    );

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
          const SizedBox(height: 20),
          scoreRow(
            'Match (≥${(threshold * 100).toStringAsFixed(0)}%)',
            '${(r.matchScore * 100).toStringAsFixed(1)}%',
            matchPassed,
          ),
          scoreRow(
            'Anti-spoof',
            r.antiSpoofScore != null ? '${(r.antiSpoofScore! * 100).toStringAsFixed(1)}%' : 'n/a',
            r.antiSpoofPassed,
          ),
          scoreRow(
            'rPPG (${r.rppgSampleCount} samples)',
            r.rppgHr != null ? '${r.rppgHr!.toStringAsFixed(0)} bpm' : 'n/a',
            r.rppgPassed,
          ),
          scoreRow('Liveness actions', r.isLive ? 'passed' : 'failed', r.isLive),
          const SizedBox(height: 32),
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

class _FaceOvalPainter extends CustomPainter {
  const _FaceOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.46),
      width: size.width * 0.80,
      height: size.height * 0.90,
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
