import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:face_verification/face_verification.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/common/face_verification_views.dart';

// ── Enums & helpers ────────────────────────────────────────────────────────

enum VerificationState { idle, activeLiveness, processing, result }

class _PassiveProgress {
  const _PassiveProgress({required this.started, required this.elapsedMs, required this.targetMs});

  final bool started;
  final int elapsedMs;
  final int targetMs;
}

String faceActionLabel(String action) => switch (action) {
  'BLINK' => currentL10n.faceActionBlink,
  'TURN_LEFT' => currentL10n.faceActionTurnLeft,
  'TURN_RIGHT' => currentL10n.faceActionTurnRight,
  'MOUTH_OPEN' => currentL10n.faceActionMouthOpen,
  'SMILE' => currentL10n.faceActionSmile,
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
  final ValueChanged<FaceVerificationOutcome> onVerified;
  final DateTime? photoIssueDate;

  // Test-only: injects a pre-built engine and skips camera + model bootstrap.
  @visibleForTesting
  final FaceVerificationEngine? testEngine;

  /// The liveness mode chosen on the method-selection screen. The scan starts in
  /// this mode; there is no in-screen picker.
  final LivenessMode mode;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 3 there); see FaceVerificationEntryScreen's
  /// matching fields.
  final int stepNumber;
  final int totalSteps;

  const FlutterFaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    this.photoIssueDate,
    this.mode = LivenessMode.passive,
    this.stepNumber = FlowStepPlan.defaultFaceVerificationStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
    this.testEngine,
  });

  @override
  State<FlutterFaceVerificationScreen> createState() => FlutterFaceVerificationScreenState();
}

// ── State ──────────────────────────────────────────────────────────────────

/// The engine's tip once the face is in position.
const _holdStillTip = 'holdStill';

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = widget.testEngine ?? FaceVerificationEngine();
    WidgetsBinding.instance.addObserver(this);
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
    _actionFlash = true;
    _passive = const _PassiveProgress(started: true, elapsedMs: 1200, targetMs: 5000);
    _passiveAt = DateTime.now();
    _alignTip = _holdStillTip;
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
      // before liveness starts.
      final nfcImage = widget.nfcImageBytes;
      if (nfcImage != null && nfcImage.isNotEmpty) {
        unawaited(_engine.prepareNfcFaceEagerly(nfcImage).catchError((_) {}));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = context.l10n.faceErrorEngineInit('$e'));
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
        setState(() => _errorMessage = context.l10n.faceErrorNoCamera);
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
    } catch (e) {
      if (mounted && !_isDisposed) setState(() => _errorMessage = context.l10n.faceErrorOpenCamera('$e'));
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
          _errorMessage = context.l10n.faceErrorFrameProcessing('$e');
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
      setState(() => _errorMessage = context.l10n.faceErrorMissingNfcImage);
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
        setState(() => _errorMessage = context.l10n.faceErrorStartLiveness('$e'));
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
        content: Text(
          context.l10n.faceTimeoutTakeYourTime(
            action != null ? faceActionLabel(action) : context.l10n.faceTimeoutPerformAction,
          ),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
    return true;
  }

  bool _handleErrorEvent(Map<String, dynamic> map) {
    final message = map['message']?.toString() ?? context.l10n.faceErrorUnknown;
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

  /// A passing result continues right away, the spinner staying up until the
  /// next screen; only a failed result shows, with "Try Again".
  void _onComplete(VerificationResult result) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    final passed = result.matchScore > faceMatchThreshold(widget.photoIssueDate) && result.isLive;
    setState(() {
      _state = passed ? VerificationState.processing : VerificationState.result;
      _result = result;
    });
    unawaited(_stopActiveFlow(disposeCamera: false));
    if (!passed) return;
    widget.onVerified(
      FaceVerificationOutcome(
        engine: 'open source',
        livenessMode: _selectedMode.name,
        matchScore: result.matchScore,
        livenessPassed: result.isLive,
        selfieImageBytes: result.liveFace,
      ),
    );
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
    return _buildGuided(context.guided);
  }

  // TEMP diagnostics for the iOS-only black-frame flash between the loading
  // screen and the live camera view. Remove once root-caused.
  String? _lastLoggedPreviewBranch;

  Widget get _cameraOpeningPlaceholder => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 12),
          Text(context.l10n.faceOpeningCamera, style: const TextStyle(color: Colors.white70)),
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

  String? _alignTipMessage(String tip) {
    switch (tip) {
      case 'noFace':
        return context.l10n.faceTipNoFace;
      case 'centerFace':
        return context.l10n.faceTipCenterFace;
      case 'tooFar':
        return context.l10n.faceTipTooFar;
      case 'tooClose':
        return context.l10n.faceTipTooClose;
      case 'lookStraight':
        return context.l10n.faceTipLookStraight;
      case 'openEyes':
        return context.l10n.faceTipOpenEyes;
      case 'closeMouth':
        return context.l10n.faceTipCloseMouth;
      case 'relaxFace':
        return context.l10n.faceTipRelaxFace;
      case _holdStillTip:
        return _selectedMode == LivenessMode.passive ? context.l10n.faceTipHoldStill : context.l10n.faceTipGetReady;
      default:
        return null;
    }
  }
}

// ── Guided layout ──────────────────────────────────────────────────────────

extension on FlutterFaceVerificationScreenState {
  /// Guided layout: the camera behind a dark scrim with an oval cut-out that
  /// turns green once the face is in position, with the current instruction
  /// in a pill underneath.
  Widget _buildGuided(GuidedStyle g) {
    // Everything people need to read comes before scanning starts; the camera
    // view itself only shows the oval and a short cue.
    if (_errorMessage == null && _state == VerificationState.idle) return _buildGuidedIntro(g);
    final showCamera = _errorMessage == null && _state == VerificationState.activeLiveness;
    return GuidedStatusBar(
      backdrop: Backdrop.dark,
      child: Scaffold(
        backgroundColor: g.header,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (showCamera) _buildCameraPreview(),
            if (showCamera && _actionFlash) ColoredBox(color: g.successBright.withValues(alpha: 0.25)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: showCamera ? _guidedScrim(g) : Colors.transparent,
                  child: SafeArea(bottom: false, child: _buildGuidedHeader(g)),
                ),
                Expanded(child: showCamera ? _buildGuidedOval(g) : _buildGuidedStatus(g)),
                if (showCamera)
                  ColoredBox(
                    color: _guidedScrim(g),
                    child: GuidedBottomInset(child: _buildGuidedControls(g)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _guidedScrim(GuidedStyle g) => g.ink.withValues(alpha: 0.78);

  Widget _buildGuidedHeader(GuidedStyle g) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GuidedTopBar(
        leading: GuidedRoundButton(
          icon: Icons.chevron_left,
          tooltip: context.l10n.faceBack,
          backdrop: Backdrop.dark,
          onPressed: _handleBack,
        ),
      ),
      GuidedStepBar(step: widget.stepNumber, total: widget.totalSteps, backdrop: Backdrop.dark),
      const SizedBox(height: 8),
    ],
  );

  /// Before the camera view: what the check does and how to get a good
  /// result, with the button that starts it. The camera and face models load
  /// behind this screen.
  Widget _buildGuidedIntro(GuidedStyle g) {
    final ready = _debugReadyOverride || (_cameraController?.value.isInitialized == true && _engineReady);
    final l10n = context.l10n;
    final startLabel = switch ((ready, _startingLiveness)) {
      (false, _) => l10n.selfieGettingReady,
      (true, true) => l10n.selfieStarting,
      (true, false) => l10n.faceStartSelfieCheck,
    };
    return GuidedFaceIntroView(
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      style: g,
      title: l10n.faceSelfieIntroTitle,
      body: l10n.selfieIntroBody,
      tips: [
        (Icons.wb_sunny_outlined, l10n.faceTipEvenLight),
        (Icons.face_retouching_off_outlined, l10n.faceTipRemoveAccessories),
        (Icons.lock_outline, l10n.selfieTipOnDevice),
      ],
      startLabel: startLabel,
      onStart: ready && !_startingLiveness ? () => _startLiveness(widget.mode) : null,
      onBack: _handleBack,
      backTooltip: l10n.faceBack,
    );
  }

  /// Green once the engine reports a face in position and nothing left to fix.
  bool get _guidedFaceAligned =>
      _state == VerificationState.activeLiveness && (_alignTip == null || _alignTip == _holdStillTip);

  Widget _buildGuidedOval(GuidedStyle g) => CustomPaint(
    painter: _GuidedFaceOvalPainter(
      scrim: _guidedScrim(g),
      stroke: _guidedFaceAligned ? g.successBright : Colors.white.withValues(alpha: 0.5),
    ),
  );

  Widget _buildGuidedControls(GuidedStyle g) {
    final ready = _debugReadyOverride || (_cameraController?.value.isInitialized == true && _engineReady);
    final (icon, message, iconColor) = _guidedHint(g, ready: ready);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: g.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_state == VerificationState.activeLiveness &&
              _selectedMode == LivenessMode.active &&
              _actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final action in _actions)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _actionDotColor(g, action)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  (IconData, String, Color) _guidedHint(GuidedStyle g, {required bool ready}) {
    if (!ready) return (Icons.hourglass_empty, context.l10n.selfieCameraGettingReady, g.action);

    final action = _currentAction;
    if (action != null && _selectedMode == LivenessMode.active && _guidedFaceAligned) {
      return (faceActionIcon(action), faceActionLabel(action), g.action);
    }

    final tip = _alignTip;
    final tipMessage = tip == null || tip == _holdStillTip ? null : _alignTipMessage(tip);
    if (tipMessage != null) return (Icons.open_in_full, tipMessage, g.action);

    final p = _passive;
    if (_selectedMode == LivenessMode.passive && p != null && p.started) {
      var elapsedMs = p.elapsedMs;
      if (_passiveAt != null) elapsedMs += DateTime.now().difference(_passiveAt!).inMilliseconds;
      final secondsLeft = ((p.targetMs - elapsedMs.clamp(0, p.targetMs)) / 1000).ceil();
      if (secondsLeft > 0) return (Icons.check, context.l10n.selfieHoldStillCountdown(secondsLeft), g.success);
    }

    return (Icons.check, context.l10n.faceHoldStill, g.success);
  }

  /// Everything that isn't the live camera: setting up, checking, the result
  /// and errors, centred on the dark background.
  Widget _buildGuidedStatus(GuidedStyle g) {
    final error = _errorMessage;
    if (error != null) {
      return _guidedStatusPanel(
        g,
        icon: Icon(Icons.error_outline, size: 56, color: Colors.white.withValues(alpha: 0.9)),
        title: context.l10n.selfieStoppedTitle,
        message: error,
        actions: [
          GuidedButton(label: context.l10n.selfieTryAgain, icon: Icons.refresh, onPressed: _retry),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _handleBack,
            style: TextButton.styleFrom(foregroundColor: g.heroEyebrow),
            child: Text(context.l10n.selfieGoBack),
          ),
        ],
      );
    }
    if (_state == VerificationState.result && _result != null) {
      return _guidedStatusPanel(
        g,
        icon: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: g.error,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: g.error.withValues(alpha: 0.25), spreadRadius: 12)],
          ),
          child: const Icon(Icons.close, size: 48, color: Colors.white),
        ),
        title: context.l10n.selfieNoMatchTitle,
        message: context.l10n.selfieNoMatchMessage,
        actions: [GuidedButton(label: context.l10n.selfieTryAgain, icon: Icons.refresh, onPressed: _retry)],
      );
    }
    final cameraReady = _cameraController?.value.isInitialized == true;
    final checking = _state == VerificationState.processing;
    final message = switch ((checking, cameraReady)) {
      (true, _) => context.l10n.selfieComparing,
      (false, true) => context.l10n.selfieLoadingModels,
      (false, false) => context.l10n.selfieOpeningCamera,
    };
    return _guidedStatusPanel(
      g,
      icon: const SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white),
      ),
      title: checking ? context.l10n.selfieCheckingTitle : context.l10n.selfieSettingUpTitle,
      message: message,
    );
  }

  Color _actionDotColor(GuidedStyle g, String action) {
    if (_completedActions.contains(action)) return g.successBright;
    if (action == _currentAction) return Colors.white;
    return Colors.white.withValues(alpha: 0.3);
  }

  Widget _guidedStatusPanel(
    GuidedStyle g, {
    required Widget icon,
    required String title,
    required String message,
    List<Widget> actions = const [],
  }) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(child: icon),
          const SizedBox(height: 28),
          GuidedHeading(
            title,
            textAlign: TextAlign.center,
            style: g.heading(24, color: Colors.white, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: g.heroMuted),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    ),
  );
}

/// Scrim with a face-shaped cut-out filling the space it's given, outlined in [stroke].
class _GuidedFaceOvalPainter extends CustomPainter {
  const _GuidedFaceOvalPainter({required this.scrim, required this.stroke});

  final Color scrim;
  final Color stroke;

  /// Height to width, as in the design (430 × 320).
  static const _aspect = 1.34;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width * 0.82, (size.height - 24) / _aspect);
    final oval = Rect.fromCenter(center: size.center(Offset.zero), width: width, height: width * _aspect);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(oval),
      Paint()..color = scrim,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(_GuidedFaceOvalPainter old) => old.scrim != scrim || old.stroke != stroke;
}
