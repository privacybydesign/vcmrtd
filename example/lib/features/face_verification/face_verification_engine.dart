import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/active_liveness_service.dart';

enum LivenessMode { active, passive }

/// Orchestrates a complete face verification session: active/passive liveness,
/// NFC face matching, anti-spoof, rPPG, and mid-session consistency check.
///
/// Usage:
///   1. Call [initialize].
///   2. Optionally call [prepareNfcFaceEagerly] to embed the NFC photo in the background.
///   3. Call [start] when the user taps the start button.
///   4. Feed camera frames via [processFrame] on each camera callback.
///   5. Listen to [events] for alignment tips, action prompts, and the final result.
///   6. Call [dispose] when the widget is removed.
class FaceVerificationEngine {
  static const int _requiredActions = FaceVerificationTuning.requiredActions;
  static const int _actionsNeededToPass = FaceVerificationTuning.actionsNeededToPass;
  static const int _actionTimeoutFrames = FaceVerificationTuning.actionTimeoutFrames;

  late final FaceVerificationWorker _worker;
  final ActiveLivenessService _active = ActiveLivenessService();
  final StreamController<Map<String, dynamic>> _events = StreamController<Map<String, dynamic>>.broadcast();
  final math.Random _random = math.Random();
  int Function()? _debugNowMs;

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Default constructor used in production.
  FaceVerificationEngine() {
    _worker = FaceVerificationWorker();
  }

  /// Test-only constructor that injects a custom worker (for unit tests).
  /// Keep small and safe: does not change runtime behaviour when not used.
  FaceVerificationEngine.withWorker(FaceVerificationWorker worker) {
    _worker = worker;
  }

  /// Expose the internal worker frame-chain future so tests can await the
  /// engine's internal pipeline draining without touching private fields.
  Future<void> get frameChainDrained => _workerFrameChain;

  // ---------------------------------------------------------------------------
  // Session lifecycle state
  // ---------------------------------------------------------------------------

  bool _running = false;
  bool _processing = false;
  bool _sessionFinished = true;
  bool _sessionStopping = false;
  LivenessMode _mode = LivenessMode.active;
  StreamSubscription<WorkerFrameResult>? _workerFrameSub;
  Future<void> _workerFrameChain = Future<void>.value();

  // ---------------------------------------------------------------------------
  // Active liveness state
  // ---------------------------------------------------------------------------

  final List<LivenessAction> _pendingActions = <LivenessAction>[];
  int _completedCount = 0;
  int _currentActionIndex = 0;
  bool _extraActionMode = false;
  int _framesSinceLastAction = 0;

  // ---------------------------------------------------------------------------
  // Passive liveness state
  // ---------------------------------------------------------------------------

  // Wall-clock ms when the countdown started. Null = lock-on phase (not yet counting).
  int? _passiveStartMs;
  // Wall-clock ms when the face first entered the oval continuously.
  // Reset to null whenever the face leaves the oval during lock-on.
  int? _passiveInOvalSinceMs;

  // ---------------------------------------------------------------------------
  // NFC face & selfie matching state
  // ---------------------------------------------------------------------------

  bool _nfcFacePrepared = false;
  Future<void>? _nfcPrepareFuture;
  Uint8List? _nfcImageBytes;
  img.Image? _firstSelfie;
  double _bestSelfieYaw = double.infinity;
  int _selfieFrameCount = 0;

  /// How many aligned frames we sample to pick the most frontal selfie.
  static const int _selfieFrameSampleSize = 5;

  // ---------------------------------------------------------------------------
  // Mid-session consistency check state
  // ---------------------------------------------------------------------------
  //
  // A second selfie is taken at a random moment mid-liveness and compared to
  // _firstSelfie. A large score drop indicates a face swap (e.g. photo held up
  // after alignment, then replaced by a different person for the gestures).

  bool _consistencySelfieStored = false;
  bool _consistencyChecked = false;
  bool _consistencyFailed = false;
  Future<void>? _consistencyCheckFuture;
  int _consistencyCheckToken = 0;
  // Active mode: track whether we were already in rest phase to detect entry.
  bool _wasWaitingForRest = false;
  // Random frame delay (0–14) before sampling the consistency selfie.
  // Randomisation prevents a sophisticated attacker from predicting the exact frame.
  int _consistencyRestFrameCount = 0;
  int _consistencyRestDelay = -1;
  // Passive mode: wall-clock ms at which to take the consistency selfie.
  int? _consistencyCheckMs;

  Future<void> initialize() async {
    await _worker.initialize();
    _workerFrameSub = _worker.frames.listen(
      (WorkerFrameResult result) {
        _workerFrameChain = _workerFrameChain.then((_) => _handleWorkerFrame(result));
      },
      onError: (Object error) {
        _sendEvent({'type': 'error', 'message': error.toString()});
        _running = false;
      },
    );
  }

  /// Call this right after [initialize] to decode + detect + embed the NFC face
  /// in the background, so it's ready before the user taps Start.
  Future<void> prepareNfcFaceEagerly(Uint8List nfcImageBytes) {
    _nfcImageBytes = nfcImageBytes;
    _nfcPrepareFuture ??= _doNfcPrep(nfcImageBytes);
    return _nfcPrepareFuture!;
  }

  Future<void> _doNfcPrep(Uint8List nfcImageBytes) async {
    try {
      final nfcImage = await _decodeNfcImage(nfcImageBytes);
      if (nfcImage == null) {
        throw StateError('Could not decode NFC image');
      }
      final encodedNfc = Uint8List.fromList(img.encodePng(nfcImage));
      final nfcFace = await _worker.detectAndCropEncoded(encodedNfc);
      if (nfcFace == null) {
        throw StateError('No face found in NFC photo');
      }
      await _worker.prepareNfcFace(nfcFace);
      _nfcFacePrepared = true;
    } catch (_) {
      _nfcPrepareFuture = null; // allow retry on next Start tap
      rethrow;
    }
  }

  Future<List<String>> start(Uint8List nfcImageBytes, {LivenessMode mode = LivenessMode.active}) async {
    _nfcImageBytes = nfcImageBytes;
    _running = true;
    _processing = false;
    _sessionFinished = false;
    _sessionStopping = false;
    _mode = mode;
    _passiveStartMs = null;
    _passiveInOvalSinceMs = null;
    _lastAlignTip = null;

    // Passive mode runs no gesture challenges — liveness comes from anti-spoof
    // and rPPG alone, so the action list stays empty.
    _pendingActions
      ..clear()
      ..addAll(mode == LivenessMode.passive ? const <LivenessAction>[] : _chooseActions());
    _completedCount = 0;
    _currentActionIndex = 0;
    _extraActionMode = false;
    _framesSinceLastAction = 0;

    _firstSelfie = null;
    _bestSelfieYaw = double.infinity;
    _selfieFrameCount = 0;

    _consistencySelfieStored = false;
    _consistencyChecked = false;
    _consistencyFailed = false;
    _consistencyCheckFuture = null;
    _consistencyCheckToken++;
    _wasWaitingForRest = false;
    _consistencyRestFrameCount = 0;
    _consistencyRestDelay = -1;
    _consistencyCheckMs = null;
    _active.reset();
    await _worker.startSession();

    // Keep NFC prep eager, but never block camera/alignment/liveness startup on it.
    if (!_nfcFacePrepared && _nfcPrepareFuture == null) {
      _nfcPrepareFuture = _doNfcPrep(nfcImageBytes);
      unawaited(_nfcPrepareFuture!.catchError((_) {}));
    }

    return _pendingActions.map((LivenessAction a) => a.wireName).toList(growable: false);
  }

  Future<void> processFrame(CameraImage cameraImage, int rotationDegrees) async {
    if (!_running || _processing || _sessionFinished || _sessionStopping) return;
    await _worker.processCameraFrame(cameraImage, rotationDegrees);
  }

  Future<void> _handleWorkerFrame(WorkerFrameResult frameResult) async {
    if (!_running || _processing || _sessionFinished || _sessionStopping) return;
    try {
      _framesSinceLastAction++;
      final face = frameResult.face;
      _updateFaceState(face);

      if (_mode == LivenessMode.passive) {
        await _processPassiveFrame(face);
        return;
      }

      if (_currentActionIndex >= _pendingActions.length) return;
      final currentAction = _pendingActions[_currentActionIndex];

      if (_active.isAligning) {
        _processAligningFrame(face, currentAction);
        return;
      }

      if (face == null) {
        if (_framesSinceLastAction > _actionTimeoutFrames) await _handleTimeout();
        return;
      }

      await _processActionFrame(face);
    } catch (e) {
      _sendEvent({'type': 'error', 'message': e.toString()});
      _running = false;
    }
  }

  void _updateFaceState(FaceObservation? face) {
    if (face == null) return;
    if (!FaceVerificationTuning.emitDebugEvents) return;
    _sendEvent({
      'type': 'debug',
      'stage': _active.isAligning ? 'aligning' : 'action',
      'action': (_currentActionIndex < _pendingActions.length) ? _pendingActions[_currentActionIndex].wireName : null,
      'yaw': face.yawDegrees,
      'smile':
          ((face.blendshapeScores['mouthSmileLeft'] ?? 0.0) + (face.blendshapeScores['mouthSmileRight'] ?? 0.0)) / 2.0,
      'mouthRatio': face.mouthRatio,
      'framesSinceLastAction': _framesSinceLastAction,
    });
  }

  void _processAligningFrame(FaceObservation? face, LivenessAction action) {
    if (_framesSinceLastAction > _actionTimeoutFrames) {
      _active.startAction(action);
      _framesSinceLastAction = 0;
      _sendNextActionEvent(action.wireName);
      return;
    }
    if (face == null) {
      _emitAlignTip('noFace');
      return;
    }
    final sizeTip = _bboxSizeTip(face);
    if (sizeTip != null) {
      _emitAlignTip(sizeTip);
      return;
    }
    final alignmentDiag = _active.diagnoseAlignmentFrame(face);
    if (!alignmentDiag.atRest) {
      _emitAlignTip(_mapRejectReason(alignmentDiag.rejectReason));
    } else {
      _emitAlignTip('holdStill');
    }
    final accepted = _active.processAlignmentFrame(face: face, action: action, timedOut: false);
    if (accepted) {
      _onAlignmentAccepted(face, action);
    }
  }

  void _onAlignmentAccepted(FaceObservation face, LivenessAction action) {
    _tryUpdateBestSelfieCandidate(face);
    // Store reference embedding once, after action 0's alignment completes.
    if (_currentActionIndex == 0 && !_consistencySelfieStored && _firstSelfie != null) {
      _consistencySelfieStored = true;
      unawaited(_worker.storeConsistencySelfie(_firstSelfie!));
    }
    _framesSinceLastAction = 0;
    _sendNextActionEvent(action.wireName);
  }

  Future<void> _processActionFrame(FaceObservation face) async {
    if (!_active.processFrame(face: face)) {
      if (_framesSinceLastAction > _actionTimeoutFrames) await _handleTimeout();
      _maybeRunConsistencyCheck(face);
      _wasWaitingForRest = _active.isWaitingForRest;
      return;
    }
    await _handleActionDetected();
  }

  void _maybeRunConsistencyCheck(FaceObservation face) {
    if (_consistencyChecked || !_consistencySelfieStored || !_active.isWaitingForRest) return;
    // On entering a new rest phase pick a random frame delay (0–14 frames).
    if (!_wasWaitingForRest) {
      _consistencyRestFrameCount = 0;
      _consistencyRestDelay = _random.nextInt(15);
    }
    if (_consistencyRestFrameCount >= _consistencyRestDelay) {
      // Only capture when the face is genuinely neutral — no open mouth,
      // no head turn, no smile — so the selfie-vs-selfie comparison is fair.
      if (_active.checkFaceAtRest(face)) {
        _startConsistencyCheck(face);
      }
    } else {
      _consistencyRestFrameCount++;
    }
  }

  int _currentTimeMs() => _debugNowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  Future<void> _processPassiveFrame(FaceObservation? face) async {
    final now = _currentTimeMs();
    final tip = _passiveCoarseTip(face);

    // Before the countdown starts: the face must be held in the oval
    // continuously for the lock-on period.
    if (_passiveStartMs == null) {
      if (_handlePassiveLockOn(tip, now)) return;
    }

    // Countdown running — fixed wall-clock duration from the start moment.
    if (tip != null) {
      // Misaligned mid-countdown: keep counting, but coach the user back.
      _emitAlignTip(tip);
    } else {
      _emitAlignTip('holdStill');
      _collectPassiveSelfieIfNeeded(face);
      _maybePassiveConsistencyCheck(face, now);
    }

    final elapsed = now - _passiveStartMs!;
    _emitPassiveProgress(started: true, elapsedMs: elapsed);

    if (elapsed >= FaceVerificationTuning.passiveTargetMs) {
      await _finishSession(true);
    }
  }

  // Returns true if the caller should return early (still in lock-on phase).
  bool _handlePassiveLockOn(String? tip, int now) {
    if (tip != null) {
      _passiveInOvalSinceMs = null;
      _emitAlignTip(tip);
      _emitPassiveProgress(started: false, elapsedMs: 0);
      return true;
    }
    _passiveInOvalSinceMs ??= now;
    if (now - _passiveInOvalSinceMs! < FaceVerificationTuning.passiveLockOnMs) {
      _emitAlignTip('holdStill');
      _emitPassiveProgress(started: false, elapsedMs: 0);
      return true;
    }
    _passiveStartMs = now;
    // Pick a random moment between 30–70% through the countdown to take the
    // consistency selfie. Set once when the countdown starts.
    const target = FaceVerificationTuning.passiveTargetMs;
    _consistencyCheckMs = now + (target * (0.3 + _random.nextDouble() * 0.4)).toInt();
    return false;
  }

  void _collectPassiveSelfieIfNeeded(FaceObservation? face) {
    if (face == null) return;
    _tryUpdateBestSelfieCandidate(face);
    // Store reference once we have the first good selfie.
    if (!_consistencySelfieStored && _firstSelfie != null) {
      _consistencySelfieStored = true;
      unawaited(_worker.storeConsistencySelfie(_firstSelfie!));
    }
  }

  /// Increments the selfie sample counter and, if [face] is more frontal than
  /// the current best, updates [_firstSelfie].
  void _tryUpdateBestSelfieCandidate(FaceObservation face) {
    if (_selfieFrameCount >= _selfieFrameSampleSize) return;
    _selfieFrameCount++;
    final absYaw = (face.yawDegrees ?? double.infinity).abs();
    if (absYaw >= _bestSelfieYaw) return;
    _bestSelfieYaw = absYaw;
    _firstSelfie = face.alignedFace112;
  }

  void _maybePassiveConsistencyCheck(FaceObservation? face, int now) {
    if (face == null || _consistencyChecked || !_consistencySelfieStored) return;
    if (_consistencyCheckMs == null || now < _consistencyCheckMs!) return;
    _startConsistencyCheck(face);
  }

  void _startConsistencyCheck(FaceObservation face) {
    _consistencyChecked = true;
    final token = ++_consistencyCheckToken;
    final future = _runConsistencyCheck(face, token);
    _consistencyCheckFuture = future;
    unawaited(
      future
          .whenComplete(() {
            if (identical(_consistencyCheckFuture, future)) {
              _consistencyCheckFuture = null;
            }
          })
          .then((_) async {
            if (token == _consistencyCheckToken && _consistencyFailed && !_sessionFinished && !_sessionStopping) {
              await _finishSession(false);
            }
          }),
    );
  }

  // Gate for passive: the face must be inside the oval (centered + right size)
  // and reasonably frontal. No eyes/mouth/smile checks — those would trip on
  // every blink. Liveness itself is covered by anti-spoof + rPPG.
  String? _passiveCoarseTip(FaceObservation? face) {
    if (face == null) return 'noFace';
    final sizeTip = _bboxSizeTip(face);
    if (sizeTip != null) return sizeTip;
    final c = face.boundingBoxCenter;
    if ((c.dx - 0.5).abs() > FaceVerificationTuning.passiveCenterMaxOffsetX ||
        (c.dy - 0.5).abs() > FaceVerificationTuning.passiveCenterMaxOffsetY) {
      return 'centerFace';
    }
    final yaw = (face.yawDegrees ?? 0.0).abs();
    if (yaw > FaceVerificationTuning.passiveMaxYawDeg) return 'lookStraight';
    return null;
  }

  void _emitPassiveProgress({required bool started, required int elapsedMs}) {
    if (_mode != LivenessMode.passive) return;
    _sendEvent({
      'type': 'passiveProgress',
      'started': started,
      'elapsedMs': elapsedMs,
      'targetMs': FaceVerificationTuning.passiveTargetMs,
    });
  }

  String? _bboxSizeTip(FaceObservation face) {
    final area = face.boundingBoxAreaRatio;
    if (area < FaceVerificationTuning.alignMinBboxArea) return 'tooFar';
    if (area > FaceVerificationTuning.alignMaxBboxArea) return 'tooClose';
    return null;
  }

  String _mapRejectReason(String? reason) {
    switch (reason) {
      case 'yaw':
        return 'lookStraight';
      case 'eyes':
        return 'openEyes';
      case 'mouth':
        return 'closeMouth';
      case 'smile':
        return 'relaxFace';
      default:
        return 'holdStill';
    }
  }

  String? _lastAlignTip;
  void _emitAlignTip(String tip) {
    if (tip == _lastAlignTip) return;
    _lastAlignTip = tip;
    _sendEvent({'type': 'align', 'tip': tip});
  }

  Future<void> stop() async {
    _running = false;
    _sessionStopping = true;
    _processing = false;
    _consistencyCheckToken++;
    await _worker.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _workerFrameSub?.cancel();
    await _worker.dispose();
    await _events.close();
  }

  @visibleForTesting
  void debugPrimeExtraScenario({
    required List<LivenessAction> pendingActions,
    required int currentActionIndex,
    required int completedCount,
    bool extraActionMode = false,
  }) {
    _pendingActions
      ..clear()
      ..addAll(pendingActions);
    _currentActionIndex = currentActionIndex;
    _completedCount = completedCount;
    _extraActionMode = extraActionMode;
  }

  @visibleForTesting
  void debugPrimeActionScenario({
    required List<LivenessAction> pendingActions,
    required int currentActionIndex,
    int completedCount = 0,
    bool extraActionMode = false,
  }) {
    debugPrimeExtraScenario(
      pendingActions: pendingActions,
      currentActionIndex: currentActionIndex,
      completedCount: completedCount,
      extraActionMode: extraActionMode,
    );
    _running = true;
    _processing = false;
    _sessionFinished = false;
    _sessionStopping = false;
    _mode = LivenessMode.active;
    _framesSinceLastAction = 0;
    _active.reset();
    if (currentActionIndex >= 0 && currentActionIndex < _pendingActions.length) {
      _active.startAction(_pendingActions[currentActionIndex]);
    }
  }

  @visibleForTesting
  void debugPrimePassiveCountdown({
    required int startMs,
    int? consistencyCheckMs,
    bool consistencySelfieStored = false,
  }) {
    _running = true;
    _processing = false;
    _sessionFinished = false;
    _sessionStopping = false;
    _mode = LivenessMode.passive;
    _passiveStartMs = startMs;
    _passiveInOvalSinceMs = startMs;
    _consistencyCheckMs = consistencyCheckMs;
    _consistencySelfieStored = consistencySelfieStored;
  }

  @visibleForTesting
  void debugSetNowProvider(int Function()? nowMs) {
    _debugNowMs = nowMs;
  }

  @visibleForTesting
  bool debugShouldStartExtra() => _shouldStartExtra();

  @visibleForTesting
  void debugStartExtra() => _startExtra();

  @visibleForTesting
  List<String> get debugPendingActionWireNames =>
      _pendingActions.map((LivenessAction action) => action.wireName).toList(growable: false);

  @visibleForTesting
  bool get debugExtraActionMode => _extraActionMode;

  @visibleForTesting
  String? debugPassiveCoarseTip(FaceObservation? face) => _passiveCoarseTip(face);

  @visibleForTesting
  String? debugBboxSizeTip(FaceObservation face) => _bboxSizeTip(face);

  @visibleForTesting
  String debugMapRejectReason(String? reason) => _mapRejectReason(reason);

  @visibleForTesting
  Future<double> debugComputeMatchScore() => _computeMatchScore();

  @visibleForTesting
  Future<img.Image?> debugDecodeNfcImage(Uint8List bytes) => _decodeNfcImage(bytes);

  @visibleForTesting
  Future<void> debugFinishSession(bool passed) => _finishSession(passed);

  @visibleForTesting
  Future<void> debugRunConsistencyCheck(FaceObservation face, int token) => _runConsistencyCheck(face, token);

  @visibleForTesting
  int get debugConsistencyCheckToken => _consistencyCheckToken;

  @visibleForTesting
  bool get debugConsistencyFailed => _consistencyFailed;

  @visibleForTesting
  void debugSetRunningState({
    required bool running,
    required bool processing,
    required bool sessionFinished,
    required bool sessionStopping,
  }) {
    _running = running;
    _processing = processing;
    _sessionFinished = sessionFinished;
    _sessionStopping = sessionStopping;
  }

  Future<void> _handleActionDetected() async {
    final completed = _pendingActions[_currentActionIndex];
    _completedCount++;
    _currentActionIndex++;
    _framesSinceLastAction = 0;
    _sendEvent({'type': 'actionDetected', 'action': completed.wireName});
    await _advanceToNextAction(useQueue: true);
  }

  Future<void> _handleTimeout() async {
    final action = (_currentActionIndex < _pendingActions.length) ? _pendingActions[_currentActionIndex] : null;
    _framesSinceLastAction = 0;
    _sendEvent({'type': 'timeout', 'action': action?.wireName});
    _currentActionIndex++;
    await _advanceToNextAction(useQueue: false);
  }

  Future<void> _advanceToNextAction({required bool useQueue}) async {
    if (_currentActionIndex >= _pendingActions.length) {
      if (_shouldStartExtra()) {
        _startExtra();
        return;
      }
      final passed = _completedCount >= (_extraActionMode ? _actionsNeededToPass + 1 : _requiredActions);
      await _finishSession(passed);
      return;
    }

    final next = _pendingActions[_currentActionIndex];
    if (useQueue) {
      _active.queueNextAction(next);
    } else {
      _active.startAction(next);
    }
    _sendNextActionEvent(next.wireName);
  }

  // If the user completed exactly the minimum to pass, add one extra challenge to confirm
  // rather than accepting on the bare minimum.
  bool _shouldStartExtra() {
    return !_extraActionMode &&
        _pendingActions.length == _requiredActions &&
        _currentActionIndex >= _requiredActions &&
        _completedCount == _actionsNeededToPass;
  }

  void _startExtra() {
    final remaining = LivenessAction.values
        .where((LivenessAction a) => !_pendingActions.contains(a))
        .toList(growable: false);
    final extra = remaining.isNotEmpty
        ? remaining[_random.nextInt(remaining.length)]
        : LivenessAction.values[_random.nextInt(LivenessAction.values.length)];
    _pendingActions.add(extra);
    _extraActionMode = true;
    _framesSinceLastAction = 0;
    _active.startAction(extra);
    _sendEvent({'type': 'extraAction', 'action': extra.wireName});
  }

  Future<void> _finishSession(bool passed) async {
    if (_sessionFinished || _sessionStopping) return;
    _sessionFinished = true;
    _processing = true;
    _sendEvent({'type': 'processing'});

    try {
      await _consistencyCheckFuture;
      final score = await _computeMatchScore();
      final passive = await _worker.getPassiveResult();
      final antiSpoofScore = passive.antiSpoofScore;
      final antiSpoofPassed = passive.antiSpoofPassed;
      final rppgPassed = passive.rppgPassed;
      final finalPassed = passed && antiSpoofPassed && rppgPassed && !_consistencyFailed;

      _sendEvent({
        'type': 'complete',
        'passed': finalPassed,
        'matchScore': score,
        'antiSpoofScore': antiSpoofScore,
        'antiSpoofPassed': antiSpoofPassed,
        'consistencyFailed': _consistencyFailed,
        'rppg': {
          'hr': passive.rppgHr,
          'passed': passive.rppgPassed,
          'sampleCount': passive.rppgSampleCount,
          'durationMs': passive.rppgDurationMs,
        },
      });
      _running = false;
    } catch (e) {
      _sendEvent({'type': 'error', 'message': 'Verification failed: $e'});
      _running = false;
    } finally {
      _processing = false;
      _sessionStopping = false;
    }
  }

  Future<double> _computeMatchScore() async {
    if (!_nfcFacePrepared) {
      final nfcImageBytes = _nfcImageBytes;
      if (nfcImageBytes == null || nfcImageBytes.isEmpty) {
        return 0.0;
      }
      try {
        await (_nfcPrepareFuture ??= _doNfcPrep(nfcImageBytes));
      } catch (e) {
        return 0.0;
      }
      if (!_nfcFacePrepared) {
        return 0.0;
      }
    }
    final selfie = _firstSelfie;
    if (selfie == null) {
      return 0.0;
    }
    return (await _worker.matchSelfie(selfie)).score;
  }

  Future<void> _runConsistencyCheck(FaceObservation face, int token) async {
    try {
      final score = await _worker.checkConsistencySelfie(face.alignedFace112);
      if (token != _consistencyCheckToken) return;
      if (score < FaceVerificationTuning.consistencyCheckThreshold) {
        _consistencyFailed = true;
      }
    } catch (_) {
      // Treat errors as a passed check — don't penalise on transient failures.
    }
  }

  void _sendEvent(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _sendNextActionEvent(String action) {
    _sendEvent({'type': 'nextAction', 'action': action});
  }

  List<LivenessAction> _chooseActions() {
    final all = LivenessAction.values.toList(growable: true)..shuffle(_random);
    return all.take(_requiredActions).toList(growable: true);
  }

  /// Decodes [bytes] to an image. Falls back to the native JP2 decoder via
  /// the image_channel method channel when the Dart decoder does not recognise
  /// the format (JPEG 2000 passport photos on iOS are handled natively by UIKit).
  Future<img.Image?> _decodeNfcImage(Uint8List bytes) async {
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
    } catch (e) {
      return null;
    }
  }
}
