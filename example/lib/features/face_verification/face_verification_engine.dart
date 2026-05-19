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
  Uint8List? _debugNfcMatchInputPng;
  Uint8List? _debugSelfieMatchInputPng;
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
      debugPrint('[FaceVerification] NFC prep started: bytes=${nfcImageBytes.length}');
      final nfcImage = await _decodeNfcImage(nfcImageBytes);
      if (nfcImage == null) {
        debugPrint('[FaceVerification] NFC prep failed: could not decode image');
        throw StateError('Could not decode NFC image');
      }
      debugPrint('[FaceVerification] NFC image decoded: ${nfcImage.width}x${nfcImage.height}');
      final encodedNfc = Uint8List.fromList(img.encodePng(nfcImage));
      final nfcFace = await _worker.detectAndCropEncoded(encodedNfc);
      if (nfcFace == null) {
        debugPrint('[FaceVerification] NFC prep failed: no face found in NFC photo');
        throw StateError('No face found in NFC photo');
      }
      debugPrint('[FaceVerification] NFC face crop ready: ${nfcFace.width}x${nfcFace.height}');
      await _worker.prepareNfcFace(nfcFace);
      _nfcFacePrepared = true;
      debugPrint('[FaceVerification] NFC embedding prepared');
    } catch (_) {
      _nfcPrepareFuture = null; // allow retry on next Start tap
      rethrow;
    }
  }

  Future<List<String>> start(Uint8List nfcImageBytes) async {
    _nfcImageBytes = nfcImageBytes;
    _running = true;
    _processing = false;
    _sessionFinished = false;
    _sessionStopping = false;

    _pendingActions
      ..clear()
      ..addAll(_chooseActions());
    _completedCount = 0;
    _currentActionIndex = 0;
    _extraActionMode = false;
    _framesSinceLastAction = 0;

    _firstSelfie = null;
    _debugNfcMatchInputPng = null;
    _debugSelfieMatchInputPng = null;
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
      'leftEyeOpen': null,
      'rightEyeOpen': null,
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
    if (face == null) return;
    final alignmentDiag = FaceVerificationDiagnostics.enabled ? _active.diagnoseAlignmentFrame(face) : null;
    final accepted = _active.processAlignmentFrame(face: face, action: action, timedOut: false);
    if (FaceVerificationDiagnostics.enabled) {
      _diagAligningFrameCount++;
      final stableAfter = accepted ? alignmentDiag!.baselineFrames : alignmentDiag!.stableFramesAfter;
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
      if (_firstSelfie == null) {
        _firstSelfie = face.alignedFace112;
        debugPrint(
          '[FaceVerification] Initial alignment selfie face crop captured: ${_firstSelfie!.width}x${_firstSelfie!.height}',
        );
      }
      _framesSinceLastAction = 0;
      _sendNextActionEvent(action.wireName);
    }
  }

  Future<void> _processActionFrame(FaceObservation face) async {
    if (!_active.processFrame(face: face)) {
      if (_framesSinceLastAction > _actionTimeoutFrames) await _handleTimeout();
      return;
    }
    await _handleActionDetected();
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

  // If the user completed exactly the borderline number of actions (neither clearly passed
  // nor clearly failed), add one extra challenge as a tiebreaker rather than deciding on the edge.
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
      final finalPassed = passed && antiSpoofPassed && rppgPassed;

      _sendEvent({
        'type': 'complete',
        'passed': finalPassed,
        'matchScore': score,
        'antiSpoofScore': antiSpoofScore,
        'antiSpoofPassed': antiSpoofPassed,
        'debugNfcInputPng': _debugNfcMatchInputPng,
        'debugSelfieInputPng': _debugSelfieMatchInputPng,
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
        debugPrint('[FaceVerification] Match skipped: no NFC image available for embedding prep');
        return 0.0;
      }
      try {
        await (_nfcPrepareFuture ??= _doNfcPrep(nfcImageBytes));
      } catch (e) {
        debugPrint('[FaceVerification] Match skipped: NFC embedding prep failed: $e');
        return 0.0;
      }
      debugPrint('[FaceVerification] Match score after NFC wait: nfcPrepared=$_nfcFacePrepared');
      if (!_nfcFacePrepared) {
        debugPrint('[FaceVerification] Match skipped: NFC embedding prep did not complete');
        return 0.0;
      }
    }
    final selfie = _firstSelfie;
    if (selfie == null) {
      debugPrint('[FaceVerification] Match skipped: no initial neutral selfie face crop captured');
      return 0.0;
    }
    debugPrint('[FaceVerification] Match started: selfie=${selfie.width}x${selfie.height}');
    final match = await _worker.matchSelfie(selfie);
    _debugNfcMatchInputPng = match.nfcInputPng;
    _debugSelfieMatchInputPng = match.selfieInputPng;
    final score = match.score;
    debugPrint('[FaceVerification] Match finished: score=${(score * 100).toStringAsFixed(2)}%');
    return score;
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
      debugPrint('[FaceVerification] NFC decode: dart decode ok ${decoded.width}x${decoded.height}');
      return decoded;
    }
    debugPrint('[FaceVerification] NFC decode: dart decode failed, trying image_channel fallback');

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) {
        debugPrint('[FaceVerification] NFC decode: image_channel returned null');
        return null;
      }
      final fallbackDecoded = img.decodeImage(converted);
      if (fallbackDecoded == null) {
        debugPrint('[FaceVerification] NFC decode: fallback bytes not decodeable, bytes=${converted.length}');
        return null;
      }
      debugPrint(
        '[FaceVerification] NFC decode: fallback decode ok ${fallbackDecoded.width}x${fallbackDecoded.height}',
      );
      return fallbackDecoded;
    } catch (e) {
      debugPrint('[FaceVerification] NFC decode: image_channel failed ${e.runtimeType}: $e');
      return null;
    }
  }
}
