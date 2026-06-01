import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_diagnostics.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/liveness_service.dart';

enum LivenessMode { active, passive }

class FaceVerificationEngine {
  static const int _requiredActions = FaceVerificationTuning.requiredActions;
  static const int _actionsNeededToPass = FaceVerificationTuning.actionsNeededToPass;
  static const int _actionTimeoutFrames = FaceVerificationTuning.actionTimeoutFrames;

  final FaceVerificationWorker _worker = FaceVerificationWorker();
  final ActiveLivenessService _active = ActiveLivenessService();
  final StreamController<Map<String, dynamic>> _events = StreamController<Map<String, dynamic>>.broadcast();
  final math.Random _random = math.Random();

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool _running = false;
  bool _processing = false;
  bool _sessionFinished = true;
  bool _sessionStopping = false;
  LivenessMode _mode = LivenessMode.active;
  // Wall-clock timestamp when the passive countdown began. Null until the face
  // has been held in the oval for the lock-on period. The countdown is a fixed
  // duration from here.
  int? _passiveStartMs;
  // When the face first became (and stayed) in the oval, for the lock-on hold.
  int? _passiveInOvalSinceMs;
  StreamSubscription<WorkerFrameResult>? _workerFrameSub;
  Future<void> _workerFrameChain = Future<void>.value();

  final List<LivenessAction> _pendingActions = <LivenessAction>[];
  int _completedCount = 0;
  int _currentActionIndex = 0;
  bool _extraActionMode = false;
  int _framesSinceLastAction = 0;

  bool _nfcFacePrepared = false;
  Future<void>? _nfcPrepareFuture;
  Uint8List? _nfcImageBytes;
  img.Image? _firstSelfie;
  double _bestSelfieYaw = double.infinity;
  int _selfieFrameCount = 0;
  static const int _selfieFrameSampleSize = 5;

  // Mid-liveness consistency check — selfie captured at a random neutral-face
  // moment and compared against _firstSelfie to detect face swaps mid-session.
  bool _consistencySelfieStored = false;
  bool _consistencyChecked = false;
  bool _consistencyFailed = false;
  bool _wasWaitingForRest = false;
  int _consistencyRestFrameCount = 0;
  int _consistencyRestDelay = -1;
  // For passive mode: wall-clock ms at which to take the mid-liveness selfie.
  int? _consistencyCheckMs;
  Uint8List? _debugNfcMatchInputPng;
  Uint8List? _debugSelfieMatchInputPng;
  // Each entry: (label, aligned112png, framePng, landmarkInputPng)
  // framePng         = annotated frame thumbnail (bbox + landmarks + crop box).
  // landmarkInputPng = 256×256 model input PNG (what the model actually saw).
  final List<(String, Uint8List, Uint8List?, Uint8List?)> _debugSelfieStepPngs = [];
  Uint8List? _latestDebugFramePng;
  Uint8List? _latestDebugLandmarkInputPng;
  bool _diagSawFirstPipelineResult = false;
  bool _diagSawFirstFaceResult = false;
  bool _diagSawFirstNextAction = false;
  int _diagAligningFrameCount = 0;

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
    _debugNfcMatchInputPng = null;

    _consistencySelfieStored = false;
    _consistencyChecked = false;
    _consistencyFailed = false;
    _wasWaitingForRest = false;
    _consistencyRestFrameCount = 0;
    _consistencyRestDelay = -1;
    _consistencyCheckMs = null;
    _debugSelfieMatchInputPng = null;
    _debugSelfieStepPngs.clear();
    _latestDebugFramePng = null;
    _latestDebugLandmarkInputPng = null;
    _diagSawFirstPipelineResult = false;
    _diagSawFirstFaceResult = false;
    _diagSawFirstNextAction = false;
    _diagAligningFrameCount = 0;
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
      if (frameResult.debugFramePng != null) _latestDebugFramePng = frameResult.debugFramePng;
      if (frameResult.debugLandmarkInputPng != null) _latestDebugLandmarkInputPng = frameResult.debugLandmarkInputPng;
      final face = frameResult.face;
      if (FaceVerificationDiagnostics.enabled && !_diagSawFirstPipelineResult) {
        _diagSawFirstPipelineResult = true;
        FaceVerificationDiagnostics.log('first pipeline result received hasFace=${face != null}');
      }
      if (FaceVerificationDiagnostics.enabled && face != null && !_diagSawFirstFaceResult) {
        _diagSawFirstFaceResult = true;
        FaceVerificationDiagnostics.log(
          'first pipeline result with face '
          'bboxArea=${face.boundingBoxAreaRatio.toStringAsFixed(3)} '
          'yaw=${_fmt(face.yawDegrees)} mouth=${face.mouthRatio.toStringAsFixed(3)}',
        );
      }
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
    if (FaceVerificationDiagnostics.enabled) {
      _diagAligningFrameCount++;
      final stableAfter = accepted ? alignmentDiag.baselineFrames : alignmentDiag.stableFramesAfter;
      FaceVerificationDiagnostics.log(
        'align frame #$_diagAligningFrameCount '
        'bboxArea=${face.boundingBoxAreaRatio.toStringAsFixed(3)} '
        'yaw=${_fmt(face.yawDegrees)} mouth=${face.mouthRatio.toStringAsFixed(3)} '
        'rest=${alignmentDiag.atRest} reason=${alignmentDiag.rejectReason ?? 'ok'} '
        'stable=${alignmentDiag.stableFramesBefore}->$stableAfter/${alignmentDiag.baselineFrames} '
        'accepted=$accepted',
      );
    }
    if (accepted) {
      if (_selfieFrameCount < _selfieFrameSampleSize) {
        _selfieFrameCount++;
        final absYaw = (face.yawDegrees ?? double.infinity).abs();
        if (absYaw < _bestSelfieYaw) {
          _bestSelfieYaw = absYaw;
          _firstSelfie = face.alignedFace112;
          _debugSelfieStepPngs.add((
            'Aligned #$_selfieFrameCount yaw=${absYaw.toStringAsFixed(1)}°',
            Uint8List.fromList(img.encodePng(face.alignedFace112)),
            _latestDebugFramePng,
            _latestDebugLandmarkInputPng,
          ));
          debugPrint(
            '[FaceVerification] Selfie candidate updated: yaw=${absYaw.toStringAsFixed(1)}° sample=$_selfieFrameCount/$_selfieFrameSampleSize',
          );
        }
      }
      // Store reference embedding once, after action 0's alignment completes.
      if (_currentActionIndex == 0 && !_consistencySelfieStored && _firstSelfie != null) {
        _consistencySelfieStored = true;
        unawaited(_worker.storeConsistencySelfie(_firstSelfie!));
      }
      _framesSinceLastAction = 0;
      _sendNextActionEvent(action.wireName);
    }
  }

  Future<void> _processActionFrame(FaceObservation face) async {
    if (!_active.processFrame(face: face)) {
      if (_framesSinceLastAction > _actionTimeoutFrames) await _handleTimeout();
      if (!_consistencyChecked && _consistencySelfieStored && _active.isWaitingForRest) {
        // On entering a new rest phase pick a random frame delay (0–14 frames).
        if (!_wasWaitingForRest) {
          _consistencyRestFrameCount = 0;
          _consistencyRestDelay = _random.nextInt(15);
        }
        if (_consistencyRestFrameCount >= _consistencyRestDelay) {
          // Only capture when the face is genuinely neutral — no open mouth,
          // no head turn, no smile — so the selfie-vs-selfie comparison is fair.
          if (_active.checkFaceAtRest(face)) {
            _consistencyChecked = true;
            unawaited(_runConsistencyCheck(face));
          }
        } else {
          _consistencyRestFrameCount++;
        }
      }
      _wasWaitingForRest = _active.isWaitingForRest;
      return;
    }
    await _handleActionDetected();
  }

  Future<void> _processPassiveFrame(FaceObservation? face) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tip = _passiveCoarseTip(face);

    // Before the countdown starts: the face must be held in the oval
    // continuously for the lock-on period. This shows guidance only (no
    // countdown card yet) and guarantees the countdown never fires on a single
    // already-aligned frame, e.g. when the user is still positioned on retry.
    if (_passiveStartMs == null) {
      if (tip != null) {
        _passiveInOvalSinceMs = null;
        _emitAlignTip(tip);
        _emitPassiveProgress(started: false, elapsedMs: 0);
        return;
      }
      _passiveInOvalSinceMs ??= now;
      if (now - _passiveInOvalSinceMs! < FaceVerificationTuning.passiveLockOnMs) {
        _emitAlignTip('holdStill');
        _emitPassiveProgress(started: false, elapsedMs: 0);
        return;
      }
      _passiveStartMs = now;
      // Pick a random moment between 30–70% through the countdown to take the
      // consistency selfie. Set once when the countdown starts.
      final target = FaceVerificationTuning.passiveTargetMs;
      _consistencyCheckMs = now + (target * (0.3 + _random.nextDouble() * 0.4)).toInt();
    }

    // Countdown running — fixed wall-clock duration from the start moment.
    if (tip != null) {
      // Misaligned mid-countdown: keep counting, but coach the user back.
      _emitAlignTip(tip);
    } else {
      _emitAlignTip('holdStill');
      // Keep the best (most frontal) selfie among aligned frames for matching.
      if (_selfieFrameCount < _selfieFrameSampleSize && face != null) {
        _selfieFrameCount++;
        final absYaw = (face.yawDegrees ?? double.infinity).abs();
        if (absYaw < _bestSelfieYaw) {
          _bestSelfieYaw = absYaw;
          _firstSelfie = face.alignedFace112;
          _debugSelfieStepPngs.add((
            'Passive #$_selfieFrameCount yaw=${absYaw.toStringAsFixed(1)}°',
            Uint8List.fromList(img.encodePng(face.alignedFace112)),
            _latestDebugFramePng,
            _latestDebugLandmarkInputPng,
          ));
        }
        // Store reference once we have the first good selfie.
        if (!_consistencySelfieStored && _firstSelfie != null) {
          _consistencySelfieStored = true;
          unawaited(_worker.storeConsistencySelfie(_firstSelfie!));
        }
      }
      // Consistency check: take a second selfie at the random time point.
      if (face != null &&
          !_consistencyChecked &&
          _consistencySelfieStored &&
          _consistencyCheckMs != null &&
          now >= _consistencyCheckMs!) {
        _consistencyChecked = true;
        unawaited(_runConsistencyCheck(face));
      }
    }

    final elapsed = now - _passiveStartMs!;
    _emitPassiveProgress(started: true, elapsedMs: elapsed);

    if (elapsed >= FaceVerificationTuning.passiveTargetMs) {
      await _finishSession(true);
    }
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
    await _worker.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _workerFrameSub?.cancel();
    await _worker.dispose();
    await _events.close();
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
        'debugNfcInputPng': _debugNfcMatchInputPng,
        'debugSelfieInputPng': _debugSelfieMatchInputPng,
        'debugSelfieSteps': _debugSelfieStepPngs
            .map((s) => <String, dynamic>{
              'label': s.$1,
              'alignedPng': s.$2,
              'framePng': s.$3,
              'landmarkInputPng': s.$4,
            })
            .toList(growable: false),
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
    debugPrint(
      '[FaceVerification] Match score start: nfcPrepared=$_nfcFacePrepared '
      'nfcFuture=${_nfcPrepareFuture != null} nfcBytes=${_nfcImageBytes?.length ?? 0} '
      'hasSelfie=${_firstSelfie != null}',
    );
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
    final match = await _worker.matchSelfie(selfie);
    _debugNfcMatchInputPng = match.nfcInputPng;
    _debugSelfieMatchInputPng = match.selfieInputPng;
    final score = match.score;
    debugPrint('[FaceVerification] Match finished: score=${(score * 100).toStringAsFixed(2)}%');
    return score;
  }

  Future<void> _runConsistencyCheck(FaceObservation face) async {
    try {
      final score = await _worker.checkConsistencySelfie(face.alignedFace112);
      final threshold = FaceVerificationTuning.consistencyCheckThreshold;
      if (score < threshold) {
        debugPrint(
          '[FaceVerification] Consistency check FAILED: score=${(score * 100).toStringAsFixed(1)}% threshold=${(threshold * 100).toStringAsFixed(0)}%',
        );
        _consistencyFailed = true;
      } else {
        debugPrint('[FaceVerification] Consistency check passed: score=${(score * 100).toStringAsFixed(1)}%');
      }
    } catch (e) {
      debugPrint('[FaceVerification] Consistency check error: $e');
    }
  }

  void _sendEvent(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _sendNextActionEvent(String action) {
    if (FaceVerificationDiagnostics.enabled && !_diagSawFirstNextAction) {
      _diagSawFirstNextAction = true;
      FaceVerificationDiagnostics.log('first nextAction action=$action');
    }
    _sendEvent({'type': 'nextAction', 'action': action});
  }

  String _fmt(double? value) => value == null ? 'n/a' : value.toStringAsFixed(3);

  List<LivenessAction> _chooseActions() {
    final all = LivenessAction.values.toList(growable: true)..shuffle(_random);
    return all.take(_requiredActions).toList(growable: true);
  }

  Future<img.Image?> _decodeNfcImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      return decoded;
    }

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) {
        return null;
      }
      final fallbackDecoded = img.decodeImage(converted);
      if (fallbackDecoded == null) {
        return null;
      }
      return fallbackDecoded;
    } catch (e) {
      return null;
    }
  }
}
