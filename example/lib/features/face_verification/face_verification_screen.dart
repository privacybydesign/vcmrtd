import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_diagnostics.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_engine.dart';

// ── Enums & helpers ────────────────────────────────────────────────────────

enum VerificationState { idle, activeLiveness, processing, result }

String faceActionLabel(String action) => switch (action) {
  'BLINK' => 'Blink your eyes',
  'TURN_LEFT' => 'Turn your head left',
  'TURN_RIGHT' => 'Turn your head right',
  'MOUTH_OPEN' => 'Open your mouth',
  'SMILE' => 'Smile',
  _ => action,
};

IconData faceActionIcon(String action) => switch (action) {
  'BLINK' => Icons.visibility_off,
  'TURN_LEFT' => Icons.arrow_back,
  'TURN_RIGHT' => Icons.arrow_forward,
  'MOUTH_OPEN' => Icons.sentiment_neutral,
  'SMILE' => Icons.sentiment_satisfied,
  _ => Icons.face,
};

double faceMatchThreshold(DateTime? photoIssueDate) {
  if (photoIssueDate == null) return 0.60;
  final ageYears = DateTime.now().difference(photoIssueDate).inDays / 365.25;
  if (ageYears <= 3) return 0.65;
  if (ageYears <= 7) return 0.60;
  return 0.55;
}

// ── Result model ───────────────────────────────────────────────────────────

class VerificationResult {
  final double matchScore;
  final bool isLive;
  final double? antiSpoofScore;
  final bool antiSpoofPassed;
  final double? rppgHr;
  final bool rppgPassed;
  final int rppgSampleCount;
  final Uint8List? debugNfcInputPng;
  final Uint8List? debugSelfieInputPng;
  const VerificationResult({
    required this.matchScore,
    required this.isLive,
    this.antiSpoofScore,
    this.antiSpoofPassed = false,
    this.rppgHr,
    this.rppgPassed = false,
    this.rppgSampleCount = 0,
    this.debugNfcInputPng,
    this.debugSelfieInputPng,
  });
}

// ── Widget ─────────────────────────────────────────────────────────────────

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

// ── State ──────────────────────────────────────────────────────────────────

class _FlutterFaceVerificationScreenState extends State<FlutterFaceVerificationScreen> with WidgetsBindingObserver {
  static const Map<DeviceOrientation, int> _orientations = <DeviceOrientation, int>{
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
  VerificationState _state = VerificationState.idle;

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
  Future<void>? _stopActiveFlowFuture;
  CameraImage? _pendingImage;
  bool _isSending = false;
  int _frameToken = 0;
  int _flowToken = 0;
  bool _diagSawFirstCameraImage = false;
  bool _diagSawFirstFrameSent = false;
  bool _diagSawFirstNextActionEvent = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
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
        _state == VerificationState.idle &&
        (_cameraController == null || _cameraController?.value.isInitialized != true)) {
      _openCamera();
    }
  }

  // ── Bootstrap & cleanup ───────────────────────────────────────────────────

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
        unawaited(_engine.prepareNfcFaceEagerly(nfcImage).catchError((_) {}));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not initialize Flutter face engine: $e');
    }
  }

  Future<void> _disposeEverything() async {
    await _stopActiveFlow(disposeCamera: true);
    await _eventSub?.cancel();
    await _engine.dispose();
  }

  Future<void> _stopActiveFlow({required bool disposeCamera}) {
    _flowToken++;
    final runningStop = _stopActiveFlowFuture;
    if (runningStop != null) {
      if (!disposeCamera) return runningStop;
      return runningStop.then((_) async {
        final ctrl = _cameraController;
        if (ctrl != null) await _disposeCameraController(ctrl, disposeCamera: true);
      });
    }
    final stopFuture = _doStopActiveFlow(disposeCamera: disposeCamera);
    _stopActiveFlowFuture = stopFuture.whenComplete(() => _stopActiveFlowFuture = null);
    return _stopActiveFlowFuture!;
  }

  Future<void> _doStopActiveFlow({required bool disposeCamera}) async {
    if (_cameraClosing || _activeLivenessStopping) return;
    _activeLivenessStopping = true;
    try {
      _invalidateFramePipeline();
      await _engine.stop();
      final ctrl = _cameraController;
      if (ctrl != null) await _disposeCameraController(ctrl, disposeCamera: disposeCamera);
    } finally {
      _activeLivenessStopping = false;
    }
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

  // ── Frame pipeline ────────────────────────────────────────────────────────

  void _invalidateFramePipeline() {
    _pendingImage = null;
    _isSending = false;
    _frameToken++;
  }

  bool get _isFrameLoopActive => !_isDisposed && _state == VerificationState.activeLiveness;

  void _finalizeSendCycle(int token) {
    if (token != _frameToken) return;
    _isSending = false;
    if (_pendingImage != null && _isFrameLoopActive) {
      _isSending = true;
      unawaited(_sendLatestFrame(token));
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed) return;
    if (_state != VerificationState.activeLiveness) return;
    if (_cameraClosing || _activeLivenessStopping) return;
    if (FaceVerificationDiagnostics.enabled && !_diagSawFirstCameraImage) {
      _diagSawFirstCameraImage = true;
      FaceVerificationDiagnostics.log(
        'first CameraImage ${image.width}x${image.height} format=${image.format.group.name}',
      );
    }
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
        if (FaceVerificationDiagnostics.enabled && !_diagSawFirstFrameSent) {
          _diagSawFirstFrameSent = true;
          FaceVerificationDiagnostics.log('first frame sent to engine rotation=$rotation');
        }
        await _engine.processFrame(image, rotation);
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _invalidateFramePipeline();
        setState(() {
          _state = VerificationState.idle;
          _currentAction = null;
          _errorMessage = 'Frame processing error: $e';
        });
      }
    } finally {
      _finalizeSendCycle(token);
    }
  }

  // ── Liveness ──────────────────────────────────────────────────────────────

  Future<void> _startActiveLiveness() async {
    if (_startingLiveness || _state == VerificationState.activeLiveness) return;
    if (!_engineReady) return;
    final ctrl = _cameraController;
    final nfcImage = widget.nfcImageBytes;
    if (_isDisposed || ctrl == null || !ctrl.value.isInitialized) return;
    if (nfcImage == null || nfcImage.isEmpty) {
      setState(() => _errorMessage = 'Missing NFC image');
      return;
    }
    FaceVerificationDiagnostics.startSession('start tapped');
    _diagSawFirstCameraImage = false;
    _diagSawFirstFrameSent = false;
    _diagSawFirstNextActionEvent = false;
    setState(() => _startingLiveness = true);
    final flowToken = _flowToken;
    try {
      await _doStartLiveness(ctrl, nfcImage);
    } catch (e) {
      if (flowToken == _flowToken && mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not start liveness: $e');
      }
    } finally {
      if (flowToken == _flowToken && mounted && !_isDisposed) {
        setState(() => _startingLiveness = false);
      }
    }
  }

  Future<void> _doStartLiveness(CameraController ctrl, Uint8List nfcImage) async {
    final flowToken = _flowToken;
    final newActions = await _engine.start(nfcImage);
    FaceVerificationDiagnostics.log('engine.start complete actions=${newActions.join(',')}');
    if (flowToken != _flowToken || !mounted || _isDisposed || newActions.isEmpty) return;
    setState(() {
      _state = VerificationState.activeLiveness;
      _actions = newActions;
      _currentAction = null;
      _completedActions = <String>{};
      _extraActionMode = false;
      _actionFlash = false;
      _errorMessage = null;
      _result = null;
    });
    if (flowToken != _flowToken || !mounted || _isDisposed) return;
    if (!ctrl.value.isStreamingImages) {
      await ctrl.startImageStream(_onCameraFrame);
      FaceVerificationDiagnostics.log('image stream started');
    } else {
      FaceVerificationDiagnostics.log('image stream already active');
    }
  }

  void _onLivenessEvent(Map<String, dynamic> map) {
    if (_handleCommonLivenessEvent(map)) return;
    if (map['type'] != 'complete') return;
    final rawMatchScore = map['matchScore'];
    debugPrint(
      '[FaceVerification] UI complete event: rawMatchScore=$rawMatchScore '
      'rawMatchScoreType=${rawMatchScore.runtimeType}',
    );
    final passed = map['passed'] as bool;
    final matchScore = (map['matchScore'] as num?)?.toDouble() ?? 0.0;
    final antiSpoofScore = (map['antiSpoofScore'] as num?)?.toDouble();
    final antiSpoofPassed = (map['antiSpoofPassed'] as bool?) ?? false;
    final rppg = map['rppg'] as Map<String, dynamic>?;
    final rppgHr = (rppg?['hr'] as num?)?.toDouble();
    final rppgPassed = (rppg?['passed'] as bool?) ?? false;
    final rppgSampleCount = (rppg?['sampleCount'] as num?)?.toInt() ?? 0;
    final debugNfcInputPng = map['debugNfcInputPng'] as Uint8List?;
    final debugSelfieInputPng = map['debugSelfieInputPng'] as Uint8List?;
    _onComplete(
      VerificationResult(
        matchScore: matchScore,
        isLive: passed,
        antiSpoofScore: antiSpoofScore,
        antiSpoofPassed: antiSpoofPassed,
        rppgHr: rppgHr,
        rppgPassed: rppgPassed,
        rppgSampleCount: rppgSampleCount,
        debugNfcInputPng: debugNfcInputPng,
        debugSelfieInputPng: debugSelfieInputPng,
      ),
    );
  }

  void _scheduleActionFlashClear() {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_isDisposed) setState(() => _actionFlash = false);
    });
  }

  bool _handleCommonLivenessEvent(Map<String, dynamic> map) {
    if (!mounted || _isDisposed) return false;
    if (_state != VerificationState.activeLiveness && _state != VerificationState.processing) {
      return false;
    }
    final type = map['type'] as String?;
    if (type == null) return false;

    switch (type) {
      case 'actionDetected':
        final action = map['action'] as String;
        setState(() {
          _completedActions.add(action);
          _actionFlash = true;
        });
        _scheduleActionFlashClear();
        return true;

      case 'nextAction':
        if (FaceVerificationDiagnostics.enabled && !_diagSawFirstNextActionEvent) {
          _diagSawFirstNextActionEvent = true;
          FaceVerificationDiagnostics.log('ui received first nextAction action=${map['action']}');
        }
        setState(() => _currentAction = map['action'] as String);
        return true;

      case 'extraAction':
        final extra = map['action'] as String;
        setState(() {
          _extraActionMode = true;
          _actions = <String>[..._actions, extra];
          _currentAction = extra;
        });
        return true;

      case 'processing':
        setState(() {
          _state = VerificationState.processing;
          _currentAction = null;
        });
        return true;

      case 'timeout':
        final action = map['action'] as String?;
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Take your time - ${action != null ? faceActionLabel(action) : 'perform the action'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return true;

      case 'error':
        final message = map['message']?.toString() ?? 'Unknown error';
        _invalidateFramePipeline();
        setState(() {
          _state = VerificationState.idle;
          _currentAction = null;
          _errorMessage = message;
        });
        return true;
    }
    return false;
  }

  void _onComplete(VerificationResult result) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    setState(() {
      _state = VerificationState.result;
      _result = result;
    });
    unawaited(_stopActiveFlow(disposeCamera: false));
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _retry() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed || !mounted) return;
    setState(() {
      _result = null;
      _errorMessage = null;
      _state = VerificationState.idle;
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildErrorScreen()
            : switch (_state) {
                VerificationState.idle => _buildIdleScreen(),
                VerificationState.activeLiveness => _buildActiveLivenessScreen(),
                VerificationState.processing => _buildProcessingScreen(),
                VerificationState.result => _buildResultScreen(),
              },
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
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(aspectRatio: 3 / 4, child: CameraPreview(ctrl)),
      ),
    );
  }

  Widget _buildOvalOverlay() => const Center(
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: CustomPaint(painter: _FaceOvalPainter()),
    ),
  );

  Widget _buildIdleScreen() {
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
                    _FaceStepRow(number: '1', text: 'Center your face inside the oval'),
                    SizedBox(height: 4),
                    _FaceStepRow(number: '2', text: 'Tap the button below'),
                    SizedBox(height: 4),
                    _FaceStepRow(number: '3', text: 'Follow the on-screen prompts'),
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

  Widget _buildActiveLivenessScreen() {
    final isAligning = _currentAction == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        if (_actionFlash) Container(color: Colors.green.withValues(alpha: 0.25)),
        if (isAligning) ..._buildAlignmentOverlay(),
        if (!isAligning) _buildActionChecklist(),
        if (_currentAction != null) _buildActionInstruction(_currentAction!),
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

  Widget _buildActionChecklist() => Positioned(
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
          final current = e.value == _currentAction;
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
                    faceActionLabel(e.value),
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
          Icon(faceActionIcon(action), color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            faceActionLabel(action),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  Widget _buildProcessingScreen() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text('Verifying identity...', style: TextStyle(fontSize: 16)),
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
    final r = _result!;
    final threshold = faceMatchThreshold(widget.photoIssueDate);
    final matchPassed = r.matchScore > threshold;
    final passed = matchPassed && r.isLive;

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
          Row(
            children: [
              _debugModelInput('NFC input', r.debugNfcInputPng),
              const SizedBox(width: 12),
              _debugModelInput('Selfie input', r.debugSelfieInputPng),
            ],
          ),
          const SizedBox(height: 20),
          _scoreRow(
            'Match (≥${(threshold * 100).toStringAsFixed(0)}%)',
            '${(r.matchScore * 100).toStringAsFixed(1)}%',
            matchPassed,
          ),
          _scoreRow(
            'Anti-spoof',
            r.antiSpoofScore != null ? '${(r.antiSpoofScore! * 100).toStringAsFixed(1)}%' : 'n/a',
            r.antiSpoofPassed,
          ),
          _scoreRow(
            'rPPG (${r.rppgSampleCount} samples)',
            r.rppgHr != null ? '${r.rppgHr!.toStringAsFixed(0)} bpm' : 'n/a',
            r.rppgPassed,
          ),
          _scoreRow('Liveness actions', r.isLive ? 'passed' : 'failed', r.isLive),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }

  static Widget _scoreRow(String label, String value, bool ok) => Padding(
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

  static Widget _debugModelInput(String label, Uint8List? bytes) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
          clipBehavior: Clip.antiAlias,
          child: bytes == null || bytes.isEmpty
              ? const Center(
                  child: Text('n/a', style: TextStyle(color: Colors.grey)),
                )
              : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ],
    ),
  );
}

// ── Supporting widgets ─────────────────────────────────────────────────────

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
