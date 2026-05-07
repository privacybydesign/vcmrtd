import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/camera/camera_frame_mapper.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/liveness_service.dart';
import 'package:vcmrtdapp/features/face_verification/recognition/face_recognizer.dart';

class FaceVerificationEngine {
  static const int _requiredActions = FaceVerificationTuning.requiredActions;
  static const int _actionsNeededToPass = FaceVerificationTuning.actionsNeededToPass;
  static const int _actionTimeoutFrames = FaceVerificationTuning.actionTimeoutFrames;

  final FaceVerificationWorker _worker = FaceVerificationWorker();
  final FaceRecognizer _recognizer = FaceRecognizer();
  final ActiveLivenessService _active = ActiveLivenessService();
  final StreamController<Map<String, dynamic>> _events = StreamController<Map<String, dynamic>>.broadcast();
  final math.Random _random = math.Random();

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool _running = false;
  bool _frameBusy = false;
  bool _processing = false;
  bool _sessionFinished = true;
  bool _sessionStopping = false;

  final List<LivenessAction> _pendingActions = <LivenessAction>[];
  int _completedCount = 0;
  int _currentActionIndex = 0;
  bool _extraActionMode = false;
  int _framesSinceLastAction = 0;

  List<double>? _nfcEmbedding;
  img.Image? _firstSelfie;
  img.Image? _bestSelfie;
  double _bestSelfieQuality = -1.0;

  Future<void> initialize() async {
    await _worker.initialize();
    await _recognizer.initialize();
  }

  Future<List<String>> start(Uint8List nfcImageBytes) async {
    _running = true;
    _frameBusy = false;
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
    _bestSelfie = null;
    _bestSelfieQuality = -1.0;
    _active.reset();
    await _worker.startSession();

    final nfcImage = await _decodeNfcImage(nfcImageBytes);
    if (nfcImage == null) {
      throw StateError('Could not decode NFC image');
    }
    final encodedNfc = Uint8List.fromList(img.encodePng(nfcImage));
    final nfcFace = await _worker.detectAndCropEncoded(encodedNfc);
    if (nfcFace == null) {
      throw StateError('No face found in NFC photo');
    }
    _nfcEmbedding = _recognizer.generateEmbedding(nfcFace);

    return _pendingActions.map((LivenessAction a) => a.wireName).toList(growable: false);
  }

  Future<void> processFrame(CameraImage cameraImage, int rotationDegrees) async {
    if (!_running || _processing || _frameBusy || _sessionFinished || _sessionStopping) return;
    _frameBusy = true;
    try {
      final mapped = CameraFrameMapper.map(cameraImage);
      if (mapped == null) return;
      final frame = CameraFrameMapper.rotateToUpright(mapped.rgbImage, rotationDegrees);

      _framesSinceLastAction++;
      final frameResult = await _worker.processFrame(frame);
      final face = frameResult.face;
      if (face == null) {
        _active.lastFacePresent = false;
      } else {
        _captureSelfie(face);
        if (FaceVerificationTuning.emitDebugEvents) {
          _sendEvent({
            'type': 'debug',
            'stage': _active.isAligning ? 'aligning' : 'action',
            'action': (_currentActionIndex < _pendingActions.length)
                ? _pendingActions[_currentActionIndex].wireName
                : null,
            'yaw': face.yawDegrees,
            'smile':
                ((face.blendshapeScores['mouthSmileLeft'] ?? 0.0) + (face.blendshapeScores['mouthSmileRight'] ?? 0.0)) /
                2.0,
            'leftEyeOpen': null,
            'rightEyeOpen': null,
            'mouthRatio': face.mouthRatio,
            'framesSinceLastAction': _framesSinceLastAction,
          });
        }
      }

      if (_currentActionIndex >= _pendingActions.length) return;
      final currentAction = _pendingActions[_currentActionIndex];

      if (_active.isAligning) {
        final timedOut = _framesSinceLastAction > _actionTimeoutFrames;
        if (timedOut) {
          _active.startAction(currentAction);
          _framesSinceLastAction = 0;
          _sendEvent({'type': 'nextAction', 'action': currentAction.wireName});
          return;
        }
        if (face == null) return;
        final alignDone = _active.processAlignmentFrame(face: face, action: currentAction, timedOut: false);
        if (alignDone) {
          _framesSinceLastAction = 0;
          _sendEvent({'type': 'nextAction', 'action': currentAction.wireName});
        }
        return;
      }

      if (face == null) {
        if (_framesSinceLastAction > _actionTimeoutFrames) {
          await _handleTimeout();
        }
        return;
      }

      final actionDone = _active.processFrame(face: face);
      if (!actionDone) {
        if (_framesSinceLastAction > _actionTimeoutFrames) {
          await _handleTimeout();
        }
        return;
      }

      await _handleActionDetected();
    } catch (e) {
      _sendEvent({'type': 'error', 'message': e.toString()});
      _running = false;
    } finally {
      _frameBusy = false;
    }
  }

  Future<void> stop() async {
    _running = false;
    _sessionStopping = true;
    _processing = false;
    await _worker.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _worker.dispose();
    await _recognizer.dispose();
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
    _sendEvent({'type': 'nextAction', 'action': next.wireName});
  }

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
    final nfc = _nfcEmbedding;
    if (nfc == null) return 0.0;
    final selfie = _bestSelfie ?? _firstSelfie;
    if (selfie == null) return 0.0;
    final emb = _recognizer.generateEmbedding(selfie);
    return _recognizer.cosineSimilarity(nfc, emb);
  }

  void _captureSelfie(FaceObservation face) {
    final yaw = (face.yawDegrees ?? 0.0).abs();
    final quality = face.boundingBox.width * face.boundingBox.height * (1.0 / (1.0 + yaw));
    _firstSelfie ??= face.alignedFace112;
    if (quality > _bestSelfieQuality) {
      _bestSelfie = face.alignedFace112;
      _bestSelfieQuality = quality;
    }
  }

  void _sendEvent(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }

  List<LivenessAction> _chooseActions() {
    final all = LivenessAction.values.toList(growable: true)..shuffle(_random);
    return all.take(_requiredActions).toList(growable: true);
  }

  Future<img.Image?> _decodeNfcImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) return decoded;

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) return null;
      return img.decodeImage(converted);
    } catch (_) {
      return null;
    }
  }
}
