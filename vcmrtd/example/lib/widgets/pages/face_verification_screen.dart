import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:face_verification/face_verification.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';

// ── Enums & helpers ────────────────────────────────────────────────────────

enum VerificationState { idle, activeLiveness, processing, result }

class _PassiveProgress {
  const _PassiveProgress({required this.started, required this.elapsedMs, required this.targetMs});

  final bool started;
  final int elapsedMs;
  final int targetMs;
}

String faceActionLabel(String action) => switch (action) {
  'BLINK' => 'Blink your eyes',
  'TURN_LEFT' => 'Turn your head left',
  'TURN_RIGHT' => 'Turn your head right',
  'MOUTH_OPEN' => 'Open your mouth and hold',
  'SMILE' => 'Smile and hold',
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
  final bool consistencyFailed;
  final Uint8List? liveFace;
  const VerificationResult({
    required this.matchScore,
    required this.isLive,
    this.antiSpoofScore,
    this.antiSpoofPassed = false,
    this.rppgHr,
    this.rppgPassed = false,
    this.rppgSampleCount = 0,
    this.consistencyFailed = false,
    this.liveFace,
  });
}

// ── Widget ─────────────────────────────────────────────────────────────────

class FlutterFaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;

  /// Explicit cancel — the back-arrow tap (or the error screen's "Go Back").
  /// Leaves this screen without having verified anything.
  final VoidCallback onBackPressed;

  /// Fired once, a couple of seconds after a passing result, to continue on to
  /// whatever comes after face verification. Distinct from [onBackPressed] so
  /// callers can send a cancel and a successful verification to different
  /// places (e.g. back to NFC reading vs. on to the document data screen).
  final VoidCallback onVerified;
  final DateTime? photoIssueDate;

  // Test-only: injects a pre-built engine and skips camera + model bootstrap.
  @visibleForTesting
  final FaceVerificationEngine? testEngine;

  /// The liveness mode chosen on the method-selection screen. The scan starts in
  /// this mode; there is no in-screen picker.
  final LivenessMode mode;

  const FlutterFaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    this.photoIssueDate,
    this.mode = LivenessMode.passive,
  }) : testEngine = null;

  const FlutterFaceVerificationScreen.withEngine({
    super.key,
    required FaceVerificationEngine engine,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    this.photoIssueDate,
    this.mode = LivenessMode.passive,
  }) : testEngine = engine;

  @override
  State<FlutterFaceVerificationScreen> createState() => FlutterFaceVerificationScreenState();
}

// ── State ──────────────────────────────────────────────────────────────────

class FlutterFaceVerificationScreenState extends State<FlutterFaceVerificationScreen> with WidgetsBindingObserver {
  static const Map<DeviceOrientation, int> _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  late final FaceVerificationEngine _engine;
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
  bool _debugReadyOverride = false;
  String? _alignTip;
  late LivenessMode _selectedMode = widget.mode;
  _PassiveProgress? _passive;
  DateTime? _passiveAt;
  Timer? _passiveTicker;
  Future<void>? _stopActiveFlowFuture;
  CameraImage? _pendingImage;
  bool _isSending = false;
  int _frameToken = 0;
  int _flowToken = 0;
  Uint8List? _documentPhoto;
  Timer? _autoContinueTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = widget.testEngine ?? FaceVerificationEngine();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadDocumentPhoto());
    if (widget.testEngine != null) {
      // Test mode: skip camera and model bootstrap, just wire up event listening.
      _eventSub = _engine.events.listen(_onLivenessEvent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _engineReady = true);
      });
    } else {
      _bootstrap();
    }
  }

  // Test-only accessors.
  @visibleForTesting
  VerificationState get debugState => _state;
  @visibleForTesting
  String? get debugCurrentAction => _currentAction;
  @visibleForTesting
  String? get debugAlignTip => _alignTip;
  @visibleForTesting
  VerificationResult? get debugResult => _result;
  @visibleForTesting
  bool get debugEngineReady => _engineReady;
  @visibleForTesting
  Set<String> get debugCompletedActions => _completedActions;
  @visibleForTesting
  void debugOnLivenessEvent(Map<String, dynamic> event) => _onLivenessEvent(event);

  @visibleForTesting
  void debugSetActiveLiveness() => setState(() => _state = VerificationState.activeLiveness);

  @visibleForTesting
  void debugSetActions(List<String> actions) => setState(() => _actions = actions);

  @visibleForTesting
  void debugSetSelectedMode(LivenessMode mode) => setState(() => _selectedMode = mode);

  @visibleForTesting
  void debugSetResultState(VerificationResult result) => setState(() {
    _result = result;
    _errorMessage = 'previous error';
    _state = VerificationState.result;
    _actions = <String>['BLINK', 'SMILE'];
    _currentAction = 'SMILE';
    _completedActions = <String>{'BLINK'};
    _extraActionMode = true;
    _actionFlash = true;
    _passive = const _PassiveProgress(started: true, elapsedMs: 1200, targetMs: 5000);
    _passiveAt = DateTime.now();
    _alignTip = 'holdStill';
  });

  @visibleForTesting
  void debugResetForRetry() => _resetForRetry();

  /// Pure rotation arithmetic — testable without a real CameraController.
  @visibleForTesting
  static int debugBackCameraRotation(int sensorOrientation, int deviceOrientationDegrees) =>
      (sensorOrientation - deviceOrientationDegrees + 360) % 360;

  @visibleForTesting
  void debugSetReadyForTesting() {
    setState(() {
      _debugReadyOverride = true;
      _engineReady = true;
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _passiveTicker?.cancel();
    _passiveTicker = null;
    _autoContinueTimer?.cancel();
    _autoContinueTimer = null;
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
    // Open camera first so the live feed is visible while models load.
    await _openCamera();
    if (!mounted) return;
    try {
      await _engine.initialize();
      if (!mounted) return;
      _eventSub = _engine.events.listen(_onLivenessEvent);
      debugPrint(
        '[faceverify] engine ready at ${DateTime.now()} '
        '(camera initialized=${_cameraController?.value.isInitialized}, previewSize=${_cameraController?.value.previewSize})',
      );
      setState(() => _engineReady = true);

      // Start NFC decode + detection + embedding in background so it's ready
      // before liveness auto-starts.
      final nfcImage = widget.nfcImageBytes;
      if (nfcImage != null && nfcImage.isNotEmpty) {
        unawaited(_engine.prepareNfcFaceEagerly(nfcImage).catchError((_) {}));
      }
      _maybeAutoStart();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not initialize Flutter face engine: $e');
    }
  }

  // Starts liveness as soon as camera + engine are both ready, so the user
  // never has to tap Start — the engine itself waits for a face to be found
  // (via the align/tip events) before anything actually happens.
  void _maybeAutoStart() {
    if (_isDisposed || !mounted) return;
    if (_state != VerificationState.idle || _startingLiveness) return;
    if (!_isReady) return;
    final nfcImage = widget.nfcImageBytes;
    if (nfcImage == null || nfcImage.isEmpty) return;
    unawaited(_startLiveness(widget.mode));
  }

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  // Decodes the NFC portrait for display on the result screen. DG2 photos may
  // be JPEG or JPEG2000; mirrors FaceVerificationEngine._decodeNfcImage,
  // falling back to the native JP2 decoder via image_channel when the Dart
  // decoder does not recognise the format.
  Future<void> _loadDocumentPhoto() async {
    final photo = await _toPng(widget.nfcImageBytes);
    if (!mounted || _isDisposed) return;
    setState(() => _documentPhoto = photo);
  }

  static Future<Uint8List?> _toPng(Uint8List? bytes) async {
    if (bytes == null) return null;
    final decoded = await _decodeImage(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  static Future<img.Image?> _decodeImage(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded != null) return decoded;

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) return null;
      return img.decodeImage(converted);
    } catch (_) {
      return null;
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
      debugPrint(
        '[faceverify] camera initialized at ${DateTime.now()} '
        '(previewSize=${ctrl.value.previewSize})',
      );
      _maybeAutoStart();
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
    if (camera.lensDirection == CameraLensDirection.front) {
      // iOS AVFoundation delivers BGRA buffers already portrait (system applies the
      // orientation transform internally). Android Camera2 does not — raw YUV comes out
      // in sensor orientation and needs the sensorOrientation correction.
      if (Platform.isIOS) return 0;
      return camera.sensorOrientation;
    }
    final rotationComp = _orientations[ctrl.value.deviceOrientation] ?? 0;
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

  Future<void> _startLiveness(LivenessMode mode) async {
    if (_startingLiveness || _state == VerificationState.activeLiveness) return;
    if (!_engineReady) return;
    final ctrl = _cameraController;
    final nfcImage = widget.nfcImageBytes;
    if (_isDisposed || ctrl == null || !ctrl.value.isInitialized) return;
    if (nfcImage == null || nfcImage.isEmpty) {
      setState(() => _errorMessage = 'Missing NFC image');
      return;
    }
    setState(() {
      _startingLiveness = true;
      _selectedMode = mode;
      _alignTip = null;
      _passive = null;
      _passiveAt = null;
    });
    _passiveTicker?.cancel();
    _passiveTicker = null;
    final flowToken = _flowToken;
    try {
      await _doStartLiveness(ctrl, nfcImage, mode);
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

  Future<void> _doStartLiveness(CameraController ctrl, Uint8List nfcImage, LivenessMode mode) async {
    final flowToken = _flowToken;
    final newActions = await _engine.start(nfcImage, mode: mode);
    if (flowToken != _flowToken || !mounted || _isDisposed) return;
    if (mode == LivenessMode.active && newActions.isEmpty) return;
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
    }
  }

  void _onLivenessEvent(Map<String, dynamic> map) {
    if (_handleCommonLivenessEvent(map)) return;
    if (map['type'] != 'complete') return;
    final passed = map['passed'] as bool;
    final matchScore = (map['matchScore'] as num?)?.toDouble() ?? 0.0;
    final antiSpoofScore = (map['antiSpoofScore'] as num?)?.toDouble();
    final antiSpoofPassed = (map['antiSpoofPassed'] as bool?) ?? false;
    final consistencyFailed = (map['consistencyFailed'] as bool?) ?? false;
    final rppg = map['rppg'] as Map<String, dynamic>?;
    final rppgHr = (rppg?['hr'] as num?)?.toDouble();
    final rppgPassed = (rppg?['passed'] as bool?) ?? false;
    final rppgSampleCount = (rppg?['sampleCount'] as num?)?.toInt() ?? 0;
    final liveFace = map['liveFace'] as Uint8List?;
    _onComplete(
      VerificationResult(
        matchScore: matchScore,
        isLive: passed,
        antiSpoofScore: antiSpoofScore,
        antiSpoofPassed: antiSpoofPassed,
        consistencyFailed: consistencyFailed,
        rppgHr: rppgHr,
        rppgPassed: rppgPassed,
        rppgSampleCount: rppgSampleCount,
        liveFace: liveFace,
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
      case 'align':
        final tip = map['tip'] as String?;
        if (tip != _alignTip) setState(() => _alignTip = tip);
        return true;
      case 'passiveProgress':
        return _handlePassiveProgressEvent(map);
      case 'actionDetected':
        final action = map['action'] as String;
        setState(() {
          _completedActions.add(action);
          _actionFlash = true;
        });
        _scheduleActionFlashClear();
        return true;
      case 'nextAction':
        _handleNextActionEvent(map);
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
        _cancelPassiveTicker();
        setState(() {
          _state = VerificationState.processing;
          _currentAction = null;
        });
        return true;
      case 'timeout':
        return _handleTimeoutEvent(map);
      case 'error':
        return _handleErrorEvent(map);
    }
    return false;
  }

  bool _handlePassiveProgressEvent(Map<String, dynamic> map) {
    final progress = _PassiveProgress(
      started: (map['started'] as bool?) ?? false,
      elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
      targetMs: (map['targetMs'] as num?)?.toInt() ?? 5000,
    );
    setState(() {
      _passive = progress;
      _passiveAt = DateTime.now();
    });
    // Once the countdown has started, interpolate between frames so the
    // timer ticks down smoothly. It runs to completion (never pauses).
    if (progress.started) {
      _passiveTicker ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    }
    return true;
  }

  void _handleNextActionEvent(Map<String, dynamic> map) {
    setState(() {
      _currentAction = map['action'] as String;
      _alignTip = null;
    });
  }

  bool _handleTimeoutEvent(Map<String, dynamic> map) {
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
  }

  bool _handleErrorEvent(Map<String, dynamic> map) {
    final message = map['message']?.toString() ?? 'Unknown error';
    _cancelPassiveTicker();
    _invalidateFramePipeline();
    setState(() {
      _state = VerificationState.idle;
      _currentAction = null;
      _errorMessage = message;
    });
    return true;
  }

  void _cancelPassiveTicker() {
    _passiveTicker?.cancel();
    _passiveTicker = null;
  }

  void _onComplete(VerificationResult result) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    setState(() {
      _state = VerificationState.result;
      _result = result;
    });
    unawaited(_stopActiveFlow(disposeCamera: false));
    _scheduleAutoContinueIfPassed(result);
  }

  /// On a passing result, give the user a brief look at the scores before
  /// automatically moving on — only a failed result waits for "Try Again".
  void _scheduleAutoContinueIfPassed(VerificationResult result) {
    final threshold = faceMatchThreshold(widget.photoIssueDate);
    final passed = result.matchScore > threshold && result.isLive;
    if (!passed) return;

    _autoContinueTimer?.cancel();
    _autoContinueTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isDisposed) return;
      widget.onVerified();
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _retry() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed || !mounted) return;
    _passiveTicker?.cancel();
    _passiveTicker = null;
    _resetForRetry();
    await _openCamera();
  }

  void _resetForRetry() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _state = VerificationState.idle;
      _actions = <String>[];
      _currentAction = null;
      _completedActions = <String>{};
      _extraActionMode = false;
      _actionFlash = false;
      _passive = null;
      _passiveAt = null;
      _alignTip = null;
    });
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
      body: Stack(
        children: [
          _buildBody(),
          Positioned(left: 0, right: 0, top: 0, child: SafeArea(bottom: false, child: _buildTopBar())),
        ],
      ),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
          const StepBadge(current: 3, total: 4, label: 'Face Verification'),
        ],
      ),
    ),
  );

  Widget _buildBackButton() => Container(
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
    child: IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: _handleBack,
    ),
  );

  // previewSize is required too: on iOS it can lag a beat behind isInitialized,
  // and without it _buildCameraPreview has nothing to size the texture against
  // (see its own previewSize == null fallback below).
  bool get _isReady =>
      _debugReadyOverride ||
      (_engineReady && _cameraController?.value.isInitialized == true && _cameraController?.value.previewSize != null);

  // TEMP diagnostics for the iOS-only black-frame flash between the loading
  // screen and the live camera view. Remove once root-caused.
  bool _loggedReadyTransition = false;
  String? _lastLoggedPreviewBranch;

  Widget _buildBody() {
    if (_errorMessage != null) return _buildErrorScreen();
    if (_state == VerificationState.idle && !_isReady) return _buildLoadingScreen();
    if (_state == VerificationState.idle && !_loggedReadyTransition) {
      _loggedReadyTransition = true;
      debugPrint(
        '[faceverify] switching loading -> idle at ${DateTime.now()} '
        '(previewSize=${_cameraController?.value.previewSize})',
      );
    }
    return switch (_state) {
      VerificationState.idle => _buildIdleScreen(),
      VerificationState.activeLiveness => _buildActiveLivenessScreen(),
      VerificationState.processing => _buildProcessingScreen(),
      VerificationState.result => _buildResultScreen(),
    };
  }

  Widget _buildLoadingScreen() {
    final cameraReady = _cameraController?.value.isInitialized == true;
    final modelsReady = _engineReady;
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
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
                _LoadingStage(label: 'Loading face models', done: modelsReady),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildPassiveProgressCard() {
    if (_selectedMode != LivenessMode.passive) return null;
    final p = _passive;
    if (p == null || !p.started) return null;
    // Fixed countdown: interpolate elapsed against wall-clock so the timer ticks
    // down smoothly between camera frames.
    var elapsedMs = p.elapsedMs;
    if (_passiveAt != null) {
      elapsedMs += DateTime.now().difference(_passiveAt!).inMilliseconds;
    }
    elapsedMs = elapsedMs.clamp(0, p.targetMs);
    final remainingMs = (p.targetMs - elapsedMs).clamp(0, p.targetMs);
    // Bar represents time LEFT: starts full, depletes to empty in sync with the
    // seconds countdown.
    final progress = p.targetMs == 0 ? 0.0 : (remainingMs / p.targetMs).clamp(0.0, 1.0);
    final secondsLeft = (remainingMs / 1000).ceil().clamp(0, 99);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  secondsLeft <= 0 ? 'Almost done…' : 'Hold still',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${secondsLeft}s',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            ),
          ),
        ],
      ),
    );
  }

  static const Widget _cameraOpeningPlaceholder = ColoredBox(
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

  void _logPreviewBranch(String branch) {
    if (_lastLoggedPreviewBranch == branch) return;
    _lastLoggedPreviewBranch = branch;
    debugPrint('[faceverify] _buildCameraPreview -> $branch at ${DateTime.now()}');
  }

  Widget _buildCameraPreview() {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      _logPreviewBranch('placeholder (not initialized)');
      return _cameraOpeningPlaceholder;
    }
    // previewSize can lag a beat behind isInitialized (seen on iOS); without it
    // there is nothing to size the texture against, so keep showing the same
    // placeholder rather than an unlabelled black frame.
    final preview = ctrl.value.previewSize;
    if (preview == null) {
      _logPreviewBranch('placeholder (previewSize null)');
      return _cameraOpeningPlaceholder;
    }
    _logPreviewBranch('live preview');
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
    final ready = _debugReadyOverride || (_cameraController?.value.isInitialized == true && _engineReady);
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        _buildOvalOverlay(),
        Positioned(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
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
                    _FaceStepRow(number: '2', text: 'Follow the on-screen prompts'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStartButton(
                ready: ready,
                onStart: () => _startLiveness(widget.mode),
                label: 'Start',
                busy: _startingLiveness,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton({
    required bool ready,
    required VoidCallback onStart,
    required String label,
    required bool busy,
  }) {
    final enabled = ready && !_startingLiveness;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onStart : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.face),
        label: Text(busy ? 'Preparing…' : label),
      ),
    );
  }

  Widget? _buildTipCard() {
    final tip = _alignTip;
    if (tip == null) return null;
    final message = _alignTipMessage(tip);
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

  String? _alignTipMessage(String tip) {
    switch (tip) {
      case 'noFace':
        return 'Position your face in the oval';
      case 'centerFace':
        return 'Move your face into the oval';
      case 'tooFar':
        return 'Move a bit closer to the camera';
      case 'tooClose':
        return 'Move a bit further from the camera';
      case 'lookStraight':
        return 'Look straight at the camera';
      case 'openEyes':
        return 'Keep your eyes open';
      case 'closeMouth':
        return 'Close your mouth';
      case 'relaxFace':
        return 'Relax your expression';
      case 'holdStill':
        return _selectedMode == LivenessMode.passive ? 'Hold still…' : 'Get ready…';
      default:
        return null;
    }
  }

  Widget _buildActiveLivenessScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        if (_actionFlash) Container(color: Colors.green.withValues(alpha: 0.25)),
        _buildOvalOverlay(),
        _buildTopInfoPanel(),
      ],
    );
  }

  Widget _buildTopInfoPanel() {
    final tipCard = _buildTipCard();
    final passiveCard = _buildPassiveProgressCard();
    final action = _currentAction;
    final isAligning = action == null;

    final cards = <Widget>[];

    if (passiveCard != null) cards.add(passiveCard);
    if (tipCard != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 8));
      cards.add(tipCard);
    }
    if (action != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 8));
      cards.add(_buildActionInstruction(action));
      if (_selectedMode == LivenessMode.active && !isAligning) {
        cards.add(const SizedBox(height: 8));
        cards.add(_buildActionChecklist());
      }
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Positioned(
      // Sits below the top bar (safe-area top inset + its 48px height).
      top: MediaQuery.paddingOf(context).top + 48 + 16,
      left: 16,
      right: 16,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
    );
  }

  Widget _buildActionChecklist() => Container(
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
  );

  Widget _buildActionInstruction(String action) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(faceActionIcon(action), color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            faceActionLabel(action),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  Widget _buildProcessingScreen() => const SafeArea(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Verifying identity...', style: TextStyle(fontSize: 16)),
        ],
      ),
    ),
  );

  Widget _buildErrorScreen() => SafeArea(
    child: Center(
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
    ),
  );

  Widget _buildResultScreen() {
    final r = _result!;
    final threshold = faceMatchThreshold(widget.photoIssueDate);
    final matchPassed = r.matchScore > threshold;
    final passed = matchPassed && r.isLive;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
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
            if (r.consistencyFailed) _scoreRow('Identity consistent', 'face changed mid-session', false),
            if (_documentPhoto != null || r.liveFace != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_documentPhoto != null) _Thumbnail(label: 'Document photo', bytes: _documentPhoto!),
                  if (_documentPhoto != null && r.liveFace != null) const SizedBox(width: 16),
                  if (r.liveFace != null) _Thumbnail(label: 'Live capture', bytes: r.liveFace!),
                ],
              ),
            ],
            const SizedBox(height: 32),
            if (passed)
              const Center(
                child: Text('Continuing…', style: TextStyle(color: Colors.grey)),
              )
            else
              OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
          ],
        ),
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
}

// ── Supporting widgets ─────────────────────────────────────────────────────

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

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
