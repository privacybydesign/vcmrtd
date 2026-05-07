import 'dart:math' as math;

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';

enum LivenessAction { blink, turnLeft, turnRight, mouthOpen, smile }

extension LivenessActionWire on LivenessAction {
  String get wireName => switch (this) {
    LivenessAction.blink => 'BLINK',
    LivenessAction.turnLeft => 'TURN_LEFT',
    LivenessAction.turnRight => 'TURN_RIGHT',
    LivenessAction.mouthOpen => 'MOUTH_OPEN',
    LivenessAction.smile => 'SMILE',
  };
}

class BaselineSnapshot {
  const BaselineSnapshot({
    required this.yawMatrix,
    required this.yawLandmark,
    required this.mouth,
    required this.smileLift,
    required this.smileWidth,
  });

  final double? yawMatrix;
  final double yawLandmark;
  final double mouth;
  final double smileLift;
  final double smileWidth;
}

class ActiveLivenessService {
  static const int confirmThreshold = 4;
  static const int confirmIncrement = 2;
  static const int confirmDecay = 1;
  static const int baselineFrames = 6;

  static const int restStableFrames = 4;
  static const double restMaxYawDeg = 12.0;
  static const int restGraceMs = 700;
  static const double restMaxEar = 0.15;
  static const double restMaxMouth = 0.05;
  static const double restMaxSmile = 0.25;

  static const double earOpenThreshold = 0.25;
  static const double blendEyeClosedThreshold = 0.45;
  static const double earWeight = 0.3;
  static const double blendWeight = 0.7;
  static const double fusedBlinkClosed = 0.55;
  static const double fusedBlinkOpen = 0.45;
  static const int minClosedFrames = 1;

  static final double mouthOpenThreshold = FaceVerificationTuning.mouthOpenThreshold;
  static const double jawOpenBlendThreshold = 0.10;
  static const double smileSuppressesMouthBlend = 0.45;

  static final double smileBlendThreshold = FaceVerificationTuning.smileThreshold;
  static const double smileWidthThreshold = 0.018;
  static const double smileLiftThreshold = 0.010;
  static const double mouthSuppressesSmileBlend = 0.25;

  static final double yawThresholdDeg = FaceVerificationTuning.turnYawThreshold;
  static const double landmarkTurnThreshold = 0.10;
  static const double landmarkTurnRelease = 0.05;
  static const double yawReleaseDeg = 5.0;

  bool isAligning = true;
  bool lastFacePresent = false;

  LivenessAction? _currentAction;
  int _confirmCount = 0;

  _BlinkPhase _blinkPhase = _BlinkPhase.open;
  int _blinkClosedFrames = 0;
  bool _turnDetectedLatch = false;

  bool _waitingForRest = false;
  LivenessAction? _queuedNextAction;
  int _restStableCount = 0;
  int _restGraceUntilMs = 0;

  double? _neutralYawMatrix;
  double? _neutralYawLandmark;
  double? _neutralMouth;
  double? _neutralSmileLift;
  double? _neutralSmileWidth;
  bool _actionBaselineReady = false;

  final _BaselineAccumulator _actionAccumulator = _BaselineAccumulator();
  final _BaselineAccumulator _restAccumulator = _BaselineAccumulator();
  final _BaselineAccumulator _alignAccumulator = _BaselineAccumulator();

  void reset() {
    _currentAction = null;
    _confirmCount = 0;
    _blinkPhase = _BlinkPhase.open;
    _blinkClosedFrames = 0;
    _turnDetectedLatch = false;
    _waitingForRest = false;
    _queuedNextAction = null;
    _restStableCount = 0;
    _restGraceUntilMs = 0;

    _neutralYawMatrix = null;
    _neutralYawLandmark = null;
    _neutralMouth = null;
    _neutralSmileLift = null;
    _neutralSmileWidth = null;
    _actionBaselineReady = false;

    _actionAccumulator.clear();
    _restAccumulator.clear();
    _alignAccumulator.clear();
    isAligning = true;
    lastFacePresent = false;
  }

  void startAction(LivenessAction action, {BaselineSnapshot? baseline}) {
    isAligning = false;
    _currentAction = action;
    _confirmCount = 0;
    _blinkPhase = _BlinkPhase.open;
    _blinkClosedFrames = 0;
    _turnDetectedLatch = false;
    _waitingForRest = false;
    _queuedNextAction = null;
    _restStableCount = 0;

    _actionAccumulator.clear();
    _restAccumulator.clear();

    _neutralYawMatrix = null;
    _neutralYawLandmark = null;
    _neutralMouth = null;
    _neutralSmileLift = null;
    _neutralSmileWidth = null;

    if (baseline != null) {
      switch (action) {
        case LivenessAction.turnLeft:
        case LivenessAction.turnRight:
          _neutralYawMatrix = baseline.yawMatrix;
          _neutralYawLandmark = baseline.yawLandmark;
        case LivenessAction.mouthOpen:
          _neutralMouth = baseline.mouth;
        case LivenessAction.smile:
          _neutralSmileLift = baseline.smileLift;
          _neutralSmileWidth = baseline.smileWidth;
        case LivenessAction.blink:
          break;
      }
      _actionBaselineReady = true;
    } else {
      _actionBaselineReady = false;
    }
  }

  void queueNextAction(LivenessAction action) {
    _waitingForRest = true;
    _queuedNextAction = action;
    _restStableCount = 0;
    _restAccumulator.clear();
    _restGraceUntilMs = DateTime.now().millisecondsSinceEpoch + restGraceMs;
  }

  bool processAlignmentFrame({required FaceObservation face, required LivenessAction action, required bool timedOut}) {
    if (!isAligning) return false;
    if (timedOut) {
      _alignAccumulator.clear();
      startAction(action);
      return true;
    }

    final lm = face.result.landmarks.first;
    if (!_isFaceAtRest(face, lm)) {
      _alignAccumulator.clear();
      return false;
    }
    _alignAccumulator.add(lm, face.yawDegrees);
    if (_alignAccumulator.size >= baselineFrames) {
      final snap = _alignAccumulator.computeSnapshot();
      _alignAccumulator.clear();
      startAction(action, baseline: snap);
      return true;
    }
    return false;
  }

  bool processFrame({required FaceObservation face}) {
    final action = _currentAction;
    if (action == null) return false;
    lastFacePresent = true;

    final lm = face.result.landmarks.first;
    if (_waitingForRest) {
      _handleRestPhase(face, lm);
      return false;
    }

    final detected = switch (action) {
      LivenessAction.blink => _detectBlink(face, lm),
      LivenessAction.turnLeft => _detectTurn(face, lm, left: true),
      LivenessAction.turnRight => _detectTurn(face, lm, left: false),
      LivenessAction.mouthOpen => _detectMouthOpen(face, lm),
      LivenessAction.smile => _detectSmile(face, lm),
    };

    if (detected) {
      _confirmCount = (_confirmCount + confirmIncrement).clamp(0, confirmThreshold + 2);
    } else if (_confirmCount > 0) {
      _confirmCount = (_confirmCount - confirmDecay).clamp(0, confirmThreshold + 2);
    }
    return _confirmCount >= confirmThreshold;
  }

  void _handleRestPhase(FaceObservation face, List<NormalizedLandmark> lm) {
    if (DateTime.now().millisecondsSinceEpoch < _restGraceUntilMs) return;
    if (_isFaceAtRest(face, lm)) {
      _restStableCount++;
      _restAccumulator.add(lm, face.yawDegrees);
    } else {
      _restStableCount = 0;
      _restAccumulator.clear();
    }
    if (_restStableCount >= restStableFrames) {
      final next = _queuedNextAction;
      if (next != null) {
        startAction(next, baseline: _restAccumulator.computeSnapshot());
      }
    }
  }

  bool _isFaceAtRest(FaceObservation face, List<NormalizedLandmark> lm) {
    final yaw = (face.yawDegrees ?? 0.0).abs();
    if (yaw > restMaxYawDeg) return false;

    final avgEar = (_ear(lm, true) + _ear(lm, false)) / 2.0;
    if (avgEar < restMaxEar) return false;

    final mouth = _mouthRatio(lm);
    if (mouth > restMaxMouth) return false;

    final smile = ((_blend(face, 'mouthSmileLeft')) + (_blend(face, 'mouthSmileRight'))) / 2.0;
    if (smile > restMaxSmile) return false;
    return true;
  }

  bool _detectBlink(FaceObservation face, List<NormalizedLandmark> lm) {
    final avgEar = (_ear(lm, true) + _ear(lm, false)) / 2.0;
    final bL = _blend(face, 'eyeBlinkLeft').clamp(0.0, 1.0);
    final bR = _blend(face, 'eyeBlinkRight').clamp(0.0, 1.0);
    final blend = (bL + bR) / 2.0;

    final earScore = 1.0 - (avgEar / earOpenThreshold).clamp(0.0, 1.0);
    final blendScore = (blend / blendEyeClosedThreshold).clamp(0.0, 1.0);
    final fused = earWeight * earScore + blendWeight * blendScore;

    final closed = fused >= fusedBlinkClosed;
    final open = fused <= fusedBlinkOpen;

    switch (_blinkPhase) {
      case _BlinkPhase.open:
        if (closed) {
          _blinkClosedFrames = 1;
          _blinkPhase = _BlinkPhase.closing;
        }
      case _BlinkPhase.closing:
        if (closed) {
          _blinkClosedFrames++;
          if (_blinkClosedFrames >= minClosedFrames) {
            _blinkPhase = _BlinkPhase.closed;
          }
        } else {
          _blinkClosedFrames = 0;
          _blinkPhase = _BlinkPhase.open;
        }
      case _BlinkPhase.closed:
        if (open) _blinkPhase = _BlinkPhase.detected;
      case _BlinkPhase.detected:
        break;
    }
    return _blinkPhase == _BlinkPhase.detected;
  }

  bool _detectTurn(FaceObservation face, List<NormalizedLandmark> lm, {required bool left}) {
    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face, lm);
      return false;
    }
    final matYaw = face.yawDegrees;
    final lmYaw = _landmarkYaw(lm);
    final matD = matYaw == null ? null : matYaw - (_neutralYawMatrix ?? 0.0);
    final lmD = lmYaw - (_neutralYawLandmark ?? 0.0);

    if (!_turnDetectedLatch) {
      final matOk = matD == null ? false : (left ? matD <= -yawThresholdDeg : matD >= yawThresholdDeg);
      final lmOk = matYaw == null && (left ? lmD <= -landmarkTurnThreshold : lmD >= landmarkTurnThreshold);
      final hit = matOk || lmOk;
      if (hit) _turnDetectedLatch = true;
      return hit;
    }

    final back = ((matD == null) || matD.abs() < yawReleaseDeg) && lmD.abs() < landmarkTurnRelease;
    if (back) {
      _turnDetectedLatch = false;
      return false;
    }
    return true;
  }

  bool _detectMouthOpen(FaceObservation face, List<NormalizedLandmark> lm) {
    final smile = (_blend(face, 'mouthSmileLeft') + _blend(face, 'mouthSmileRight')) / 2.0;
    if (smile >= smileSuppressesMouthBlend) return false;

    final jawBlend = _blend(face, 'jawOpen');
    final ratio = _mouthRatio(lm);
    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face, lm);
      return false;
    }
    final delta = ratio - (_neutralMouth ?? 0.0);
    return jawBlend >= jawOpenBlendThreshold || delta >= mouthOpenThreshold;
  }

  bool _detectSmile(FaceObservation face, List<NormalizedLandmark> lm) {
    final jaw = _blend(face, 'jawOpen');
    if (jaw >= mouthSuppressesSmileBlend) return false;
    final sBlend = (_blend(face, 'mouthSmileLeft') + _blend(face, 'mouthSmileRight')) / 2.0;

    final fH = _dist(lm[10], lm[152]).clamp(1e-6, 1e6);
    final fW = _dist(lm[234], lm[454]).clamp(1e-6, 1e6);
    final cornerY = (lm[61].y + lm[291].y) / 2.0;
    final lift = (lm[0].y - cornerY) / fH;
    final width = _dist(lm[61], lm[291]) / fW;

    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face, lm);
      return false;
    }
    final liftD = lift - (_neutralSmileLift ?? 0.0);
    final widthD = width - (_neutralSmileWidth ?? 0.0);
    return sBlend >= smileBlendThreshold || (widthD >= smileWidthThreshold && liftD >= smileLiftThreshold);
  }

  void _accumulateActionBaseline(FaceObservation face, List<NormalizedLandmark> lm) {
    _actionAccumulator.add(lm, face.yawDegrees);
    if (_actionAccumulator.size < baselineFrames) return;
    final snap = _actionAccumulator.computeSnapshot();
    switch (_currentAction) {
      case LivenessAction.turnLeft:
      case LivenessAction.turnRight:
        _neutralYawMatrix = snap.yawMatrix;
        _neutralYawLandmark = snap.yawLandmark;
      case LivenessAction.mouthOpen:
        _neutralMouth = snap.mouth;
      case LivenessAction.smile:
        _neutralSmileLift = snap.smileLift;
        _neutralSmileWidth = snap.smileWidth;
      case LivenessAction.blink:
      case null:
        break;
    }
    _actionBaselineReady = true;
  }

  double _landmarkYaw(List<NormalizedLandmark> lm) {
    final lx = lm[234].x;
    final rx = lm[454].x;
    final w = (rx - lx).abs().clamp(1e-6, 1e6);
    return (lm[1].x - ((lx + rx) / 2.0)) / w;
  }

  double _blend(FaceObservation face, String name) => face.blendshapeScores[name] ?? 0.0;

  double _mouthRatio(List<NormalizedLandmark> lm) {
    final fH = _dist(lm[10], lm[152]).clamp(1e-6, 1e6);
    return _dist(lm[13], lm[14]) / fH;
  }

  double _ear(List<NormalizedLandmark> lm, bool left) {
    late final int p1;
    late final int p2;
    late final int p3;
    late final int p4;
    late final int p5;
    late final int p6;
    if (left) {
      p1 = 362;
      p2 = 385;
      p3 = 387;
      p4 = 263;
      p5 = 373;
      p6 = 380;
    } else {
      p1 = 33;
      p2 = 160;
      p3 = 158;
      p4 = 133;
      p5 = 153;
      p6 = 144;
    }
    final a = _dist(lm[p2], lm[p6]);
    final b = _dist(lm[p3], lm[p5]);
    final c = _dist(lm[p1], lm[p4]);
    return (a + b) / ((2.0 * c) + 1e-6);
  }

  double _dist(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

enum _BlinkPhase { open, closing, closed, detected }

class _BaselineAccumulator {
  final List<double> _yawMatrix = <double>[];
  final List<double> _yawLandmark = <double>[];
  final List<double> _mouth = <double>[];
  final List<double> _smileLift = <double>[];
  final List<double> _smileWidth = <double>[];

  int get size => _yawLandmark.length;

  void clear() {
    _yawMatrix.clear();
    _yawLandmark.clear();
    _mouth.clear();
    _smileLift.clear();
    _smileWidth.clear();
  }

  void add(List<NormalizedLandmark> lm, double? matrixYaw) {
    final fH = _dist(lm[10], lm[152]).clamp(1e-6, 1e6);
    final fW = _dist(lm[234], lm[454]).clamp(1e-6, 1e6);
    final cornerY = (lm[61].y + lm[291].y) / 2.0;
    if (matrixYaw != null) _yawMatrix.add(matrixYaw);
    _yawLandmark.add((lm[1].x - ((lm[234].x + lm[454].x) / 2.0)) / (lm[454].x - lm[234].x).abs().clamp(1e-6, 1e6));
    _mouth.add(_dist(lm[13], lm[14]) / fH);
    _smileLift.add((lm[0].y - cornerY) / fH);
    _smileWidth.add(_dist(lm[61], lm[291]) / fW);
  }

  BaselineSnapshot computeSnapshot() {
    return BaselineSnapshot(
      yawMatrix: _yawMatrix.isEmpty ? null : _median(_yawMatrix),
      yawLandmark: _median(_yawLandmark),
      mouth: _median(_mouth),
      smileLift: _median(_smileLift),
      smileWidth: _median(_smileWidth),
    );
  }

  double _median(List<double> values) {
    final sorted = <double>[...values]..sort();
    final m = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[m];
    return (sorted[m - 1] + sorted[m]) / 2.0;
  }

  double _dist(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class RppgResult {
  const RppgResult({required this.hr, required this.passed, required this.sampleCount, required this.durationMs});

  final double? hr;
  final bool passed;
  final int sampleCount;
  final int durationMs;
}

class PassiveLivenessService {
  static final double antiSpoofMinScore = FaceVerificationTuning.antiSpoofMinScore;

  static const int _inputSize = 80;
  static const int _liveClassIdx = 1;
  static const double _scaleV2 = 2.7;
  static const int _minAntiSpoofSamples = FaceVerificationTuning.antiSpoofMinSamples;
  static const double _antiSpoofSampleRate = 0.70;
  static const double _antiSpoofMaxYawDeg = 20.0;
  static const int _minBvpSamples = 15;
  static const int _minDurationMs = 2000;
  static const double _rppgFrontalMaxYaw = 15.0;
  static const int _rppgMaxGapMs = 1000;

  final math.Random _random = math.Random();

  Interpreter? _v1;
  Interpreter? _v2;
  bool _v1Nchw = false;
  bool _v2Nchw = false;

  final List<double> _scores = <double>[];
  final List<int> _scoreTimes = <int>[];
  int _attempts = 0;
  int _totalFrames = 0;

  final _BigSmallService _bigSmall = _BigSmallService();
  final List<_RppgFrame> _rppgFrameBuffer = <_RppgFrame>[];
  final List<double> _bvpSamples = <double>[];
  final List<int> _bvpSampleTimes = <int>[];
  int _lastFrameBufferedMs = 0;

  Future<void> initialize() async {
    final options = InterpreterOptions()..threads = 1;

    _v1 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v1se.tflite', options: options);
    _v2 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v2.tflite', options: options);

    final s1 = _v1!.getInputTensor(0).shape;
    final s2 = _v2!.getInputTensor(0).shape;
    _v1Nchw = s1.length == 4 && s1[1] == 3;
    _v2Nchw = s2.length == 4 && s2[1] == 3;

    await _bigSmall.initialize();
  }

  void reset() {
    _scores.clear();
    _scoreTimes.clear();
    _attempts = 0;
    _totalFrames = 0;
    _rppgFrameBuffer.clear();
    _bvpSamples.clear();
    _bvpSampleTimes.clear();
    _lastFrameBufferedMs = 0;
  }

  void collectPassiveMetrics(img.Image frame, FaceObservation face) {
    _totalFrames++;
    _sampleAntiSpoof(frame, face);
    _sampleRppg(frame, face);
  }

  double? getAntiSpoofScore() {
    if (_scores.isEmpty) return null;
    return _scores.reduce((double a, double b) => a + b) / _scores.length;
  }

  bool isAntiSpoofPassed() {
    if (_scores.length < _minAntiSpoofSamples) return false;
    final avg = getAntiSpoofScore();
    if (avg == null) return false;
    return avg >= antiSpoofMinScore;
  }

  int getAntiSpoofAttempts() => _attempts;

  int getTotalFrames() => _totalFrames;

  RppgResult? getRppgResult() {
    if (_bvpSamples.length < _minBvpSamples || _bvpSampleTimes.length < 2) return null;
    final durationMs = (_bvpSampleTimes.last - _bvpSampleTimes.first).clamp(1, 1 << 30);
    if (durationMs < _minDurationMs) return null;
    final fps = (((_bvpSamples.length - 1) * 1000) / durationMs).clamp(1, 1000).toInt();
    return _evaluateBvp(_bvpSamples, fps);
  }

  Future<void> awaitRppgIdle() async {}

  void _sampleAntiSpoof(img.Image frame, FaceObservation face) {
    if (_random.nextDouble() >= _antiSpoofSampleRate) return;
    _attempts++;
    final yaw = face.yawDegrees;
    final isFrontal = yaw == null || yaw.abs() < _antiSpoofMaxYawDeg;
    if (!isFrontal) return;
    final score = _scoreFrame(frame, face.result);
    if (score != null) {
      _scores.add(score);
      _scoreTimes.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  double? _scoreFrame(img.Image frame, FaceLandmarkerResult result) {
    final v1 = _v1;
    final v2 = _v2;
    if (v1 == null || v2 == null) return null;

    final rois = _extractRois(result);
    if (rois == null) return null;
    final bbox = _faceBoxPixels(rois, frame.width, frame.height);
    if (bbox == null) return null;

    final whole = img.copyResize(frame, width: _inputSize, height: _inputSize, interpolation: img.Interpolation.linear);
    final cropV2 = _scaledCrop(frame, bbox, _scaleV2);
    if (cropV2 == null) return null;
    final scaledFace = img.copyResize(
      cropV2,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final in1 = _preprocess(whole, nchw: _v1Nchw);
    final in2 = _preprocess(scaledFace, nchw: _v2Nchw);

    final out1 = <List<double>>[List<double>.filled(3, 0.0)];
    final out2 = <List<double>>[List<double>.filled(3, 0.0)];
    v1.run(in1, out1);
    v2.run(in2, out2);

    final sm1 = _softmax(out1.first);
    final sm2 = _softmax(out2.first);
    final combined = List<double>.generate(3, (int i) => sm1[i] + sm2[i], growable: false);
    final liveConfidence = combined[_liveClassIdx] / 2.0;
    final label = combined.indexOf(combined.reduce(math.max));
    return label == _liveClassIdx ? liveConfidence : 0.0;
  }

  void _sampleRppg(img.Image frame, FaceObservation face) {
    final yaw = face.yawDegrees;
    if (yaw != null && yaw.abs() > _rppgFrontalMaxYaw) return;
    final rois = _extractRois(face.result);
    if (rois == null) return;

    final crops = _cropFaceForBigSmall(frame, rois);
    if (crops == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_rppgFrameBuffer.isNotEmpty && now - _lastFrameBufferedMs > _rppgMaxGapMs) {
      _rppgFrameBuffer.clear();
    }

    _rppgFrameBuffer.add(_RppgFrame(appearance: crops.$1, motion: crops.$2, timestampMs: now));
    _lastFrameBufferedMs = now;

    if (_rppgFrameBuffer.length >= _BigSmallService.bufferFrames) {
      final batch = List<_RppgFrame>.from(_rppgFrameBuffer);
      _rppgFrameBuffer.clear();
      final bvp = _bigSmall.runInference(batch);
      if (bvp != null) {
        final count = math.min(bvp.length, batch.length - 1);
        for (var i = 0; i < count; i++) {
          _bvpSamples.add(bvp[i]);
          final t0 = batch[i].timestampMs;
          final t1 = batch[i + 1].timestampMs;
          _bvpSampleTimes.add(t0 + ((t1 - t0) ~/ 2));
        }
        while (_bvpSamples.length > 900) {
          _bvpSamples.removeAt(0);
          _bvpSampleTimes.removeAt(0);
        }
      }
    }
  }

  Map<String, List<double>>? _extractRois(FaceLandmarkerResult result) {
    if (result.landmarks.isEmpty) return null;
    final lm = result.landmarks.first;
    final fw = (lm[338].x - lm[109].x).abs();
    final s = fw * 0.15;
    return <String, List<double>>{
      'forehead': <double>[lm[10].x, lm[10].y - s * 0.3, s],
      'right_cheek': <double>[lm[205].x, lm[205].y, s],
      'left_cheek': <double>[lm[425].x, lm[425].y, s],
      'nose': <double>[lm[4].x, lm[4].y, s * 0.8],
      'lips': <double>[(lm[0].x + lm[17].x) / 2.0, (lm[0].y + lm[17].y) / 2.0, s],
    };
  }

  List<int>? _faceBoxPixels(Map<String, List<double>> rois, int imgW, int imgH) {
    final l = rois['left_cheek'];
    final r = rois['right_cheek'];
    final f = rois['forehead'];
    final p = rois['lips'];
    if (l == null || r == null || f == null || p == null) return null;

    final minX = math.min(l[0], r[0]);
    final maxX = math.max(l[0], r[0]);
    final minY = math.min(f[1], p[1]);
    final maxY = math.max(f[1], p[1]);

    final x = (minX * imgW).toInt().clamp(0, imgW - 1);
    final y = (minY * imgH).toInt().clamp(0, imgH - 1);
    final w = ((maxX - minX) * imgW).toInt().clamp(1, imgW);
    final h = ((maxY - minY) * imgH).toInt().clamp(1, imgH);
    if (w <= 1 || h <= 1) return null;
    return <int>[x, y, w, h];
  }

  img.Image? _scaledCrop(img.Image source, List<int> bbox, double scale) {
    final srcW = source.width;
    final srcH = source.height;
    final s = math.min((srcH - 1.0) / bbox[3], math.min((srcW - 1.0) / bbox[2], scale));
    final cx = bbox[2] / 2.0 + bbox[0];
    final cy = bbox[3] / 2.0 + bbox[1];
    var ltX = cx - bbox[2] * s / 2.0;
    var ltY = cy - bbox[3] * s / 2.0;
    var rbX = cx + bbox[2] * s / 2.0;
    var rbY = cy + bbox[3] * s / 2.0;

    if (ltX < 0.0) {
      rbX -= ltX;
      ltX = 0.0;
    }
    if (ltY < 0.0) {
      rbY -= ltY;
      ltY = 0.0;
    }
    if (rbX > srcW - 1.0) {
      ltX -= rbX - srcW + 1.0;
      rbX = srcW - 1.0;
    }
    if (rbY > srcH - 1.0) {
      ltY -= rbY - srcH + 1.0;
      rbY = srcH - 1.0;
    }

    final x1 = ltX.toInt().clamp(0, srcW - 1);
    final y1 = ltY.toInt().clamp(0, srcH - 1);
    final x2 = rbX.toInt().clamp(0, srcW - 1);
    final y2 = rbY.toInt().clamp(0, srcH - 1);
    if (x2 <= x1 || y2 <= y1) return null;
    return img.copyCrop(source, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
  }

  Object _preprocess(img.Image image, {required bool nchw}) {
    if (nchw) {
      final ch0 = List<double>.filled(_inputSize * _inputSize, 0.0);
      final ch1 = List<double>.filled(_inputSize * _inputSize, 0.0);
      final ch2 = List<double>.filled(_inputSize * _inputSize, 0.0);
      var i = 0;
      for (var y = 0; y < _inputSize; y++) {
        for (var x = 0; x < _inputSize; x++) {
          final px = image.getPixel(x, y);
          ch0[i] = px.b.toDouble();
          ch1[i] = px.g.toDouble();
          ch2[i] = px.r.toDouble();
          i++;
        }
      }
      return <List<List<double>>>[
        <List<double>>[ch0, ch1, ch2],
      ];
    }

    return <dynamic>[
      List<dynamic>.generate(
        _inputSize,
        (int y) => List<dynamic>.generate(_inputSize, (int x) {
          final px = image.getPixel(x, y);
          return <double>[px.b.toDouble(), px.g.toDouble(), px.r.toDouble()];
        }, growable: false),
        growable: false,
      ),
    ];
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(math.max);
    final exps = logits.map((double v) => math.exp(v - maxVal)).toList(growable: false);
    final sum = exps.reduce((double a, double b) => a + b);
    return exps.map((double e) => e / (sum == 0 ? 1 : sum)).toList(growable: false);
  }

  (img.Image, img.Image)? _cropFaceForBigSmall(img.Image bitmap, Map<String, List<double>> rois) {
    final l = rois['left_cheek'];
    final r = rois['right_cheek'];
    final f = rois['forehead'];
    final p = rois['lips'];
    if (l == null || r == null || f == null || p == null) return null;

    final imgW = bitmap.width;
    final imgH = bitmap.height;
    final x1 = ((math.min(l[0], r[0]) - l[2]) * imgW).toInt().clamp(0, imgW - 1);
    final x2 = ((math.max(l[0], r[0]) + r[2]) * imgW).toInt().clamp(0, imgW - 1);
    final y1 = ((f[1] - f[2]) * imgH).toInt().clamp(0, imgH - 1);
    final y2 = ((p[1] + p[2]) * imgH).toInt().clamp(0, imgH - 1);
    if (x2 <= x1 || y2 <= y1) return null;

    final cropped = img.copyCrop(bitmap, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    final appearance = img.copyResize(
      cropped,
      width: _BigSmallService.appearanceSize,
      height: _BigSmallService.appearanceSize,
      interpolation: img.Interpolation.linear,
    );
    final motion = img.copyResize(
      cropped,
      width: _BigSmallService.motionSize,
      height: _BigSmallService.motionSize,
      interpolation: img.Interpolation.linear,
    );
    return (appearance, motion);
  }

  RppgResult _evaluateBvp(List<double> samples, int fps) {
    if (samples.isEmpty || fps <= 0) {
      return const RppgResult(hr: null, passed: false, sampleCount: 0, durationMs: 0);
    }
    final hr = _estimateHeartRate(samples, fps);
    final passed = hr != null && hr >= 45.0 && hr <= 110.0;
    final durationMs = fps > 0 ? (((samples.length - 1) * 1000) / fps).round() : 0;
    return RppgResult(hr: hr, passed: passed, sampleCount: samples.length, durationMs: durationMs);
  }

  double? _estimateHeartRate(List<double> signal, int fps) {
    if (signal.length < 3) return null;
    final peaks = _findPeaks(signal, (fps * 0.4).clamp(1.0, 1000000.0).toInt());
    if (peaks.length < 2) return null;
    final intervals = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final sec = (peaks[i] - peaks[i - 1]) / fps;
      if (sec >= 0.4 && sec <= 1.5) intervals.add(sec);
    }
    if (intervals.isEmpty) return null;
    final avg = intervals.reduce((double a, double b) => a + b) / intervals.length;
    return 60.0 / avg;
  }

  List<int> _findPeaks(List<double> signal, int minDist) {
    final peaks = <int>[];
    for (var i = 1; i < signal.length - 1; i++) {
      if (signal[i] > signal[i - 1] && signal[i] > signal[i + 1]) {
        if (peaks.isEmpty || i - peaks.last >= minDist) {
          peaks.add(i);
        } else if (signal[i] > signal[peaks.last]) {
          peaks[peaks.length - 1] = i;
        }
      }
    }
    return peaks;
  }

  Future<void> dispose() async {
    _v1?.close();
    _v2?.close();
    _v1 = null;
    _v2 = null;
    _bigSmall.close();
  }
}

class _RppgFrame {
  const _RppgFrame({required this.appearance, required this.motion, required this.timestampMs});

  final img.Image appearance;
  final img.Image motion;
  final int timestampMs;
}

class _BigSmallService {
  static const List<String> _modelFiles = <String>[
    'assets/face_verification/bigsmall_1.tflite',
    'assets/face_verification/bigsmall_2.tflite',
    'assets/face_verification/bigsmall_3.tflite',
  ];
  static const int frames = 3;
  static const int bufferFrames = frames + 1;
  static const int appearanceSize = 144;
  static const int motionSize = 9;

  final List<Interpreter?> _interpreters = List<Interpreter?>.filled(_modelFiles.length, null);
  final List<List<int>?> _appearanceShapes = List<List<int>?>.filled(_modelFiles.length, null);
  final List<List<int>?> _motionShapes = List<List<int>?>.filled(_modelFiles.length, null);
  final List<List<int>?> _outputShapes = List<List<int>?>.filled(_modelFiles.length, null);

  Future<void> initialize() async {
    for (var i = 0; i < _modelFiles.length; i++) {
      if (_interpreters[i] != null) continue;
      final options = InterpreterOptions()..threads = 2;
      _interpreters[i] = await Interpreter.fromAsset(_modelFiles[i], options: options);
      _appearanceShapes[i] = _interpreters[i]!.getInputTensor(0).shape;
      _motionShapes[i] = _interpreters[i]!.getInputTensor(1).shape;
      _outputShapes[i] = _interpreters[i]!.getOutputTensor(0).shape;
    }
  }

  List<double>? runInference(List<_RppgFrame> framesBatch) {
    if (framesBatch.length != bufferFrames) return null;
    if (_interpreters.every((Interpreter? i) => i == null)) return null;

    final appearanceFlat = _buildAppearanceFlat(framesBatch);
    final motionFlat = _buildMotionFlat(framesBatch);

    final sum = List<double>.filled(frames, 0.0);
    var count = 0;

    for (var i = 0; i < _interpreters.length; i++) {
      final interp = _interpreters[i];
      final aShape = _appearanceShapes[i];
      final mShape = _motionShapes[i];
      final oShape = _outputShapes[i];
      if (interp == null || aShape == null || mShape == null || oShape == null) continue;

      final appearanceInput = _reshapeToShape(appearanceFlat, aShape);
      final motionInput = _reshapeToShape(motionFlat, mShape);
      final outTensor = _makeTensor(oShape);
      interp.runForMultipleInputs(<Object>[appearanceInput, motionInput], <int, Object>{0: outTensor});
      final out = _flatFloatArray(outTensor);
      if (out.isEmpty) continue;
      final take = math.min(frames, out.length);
      for (var f = 0; f < take; f++) {
        sum[f] += out[f];
      }
      count++;
    }

    if (count == 0) return null;
    return List<double>.generate(frames, (int i) => sum[i] / count, growable: false);
  }

  void close() {
    for (var i = 0; i < _interpreters.length; i++) {
      _interpreters[i]?.close();
      _interpreters[i] = null;
    }
  }

  List<double> _buildAppearanceFlat(List<_RppgFrame> batch) {
    final out = <double>[];
    for (var fi = 1; fi <= frames; fi++) {
      final frame = batch[fi].appearance;
      for (var y = 0; y < appearanceSize; y++) {
        for (var x = 0; x < appearanceSize; x++) {
          out.add(frame.getPixel(x, y).r / 255.0);
        }
      }
      for (var y = 0; y < appearanceSize; y++) {
        for (var x = 0; x < appearanceSize; x++) {
          out.add(frame.getPixel(x, y).g / 255.0);
        }
      }
      for (var y = 0; y < appearanceSize; y++) {
        for (var x = 0; x < appearanceSize; x++) {
          out.add(frame.getPixel(x, y).b / 255.0);
        }
      }
    }
    return out;
  }

  List<double> _buildMotionFlat(List<_RppgFrame> batch) {
    final out = <double>[];
    const eps = 1e-7;
    for (var fi = 0; fi < frames; fi++) {
      final curr = batch[fi].motion;
      final next = batch[fi + 1].motion;
      for (var y = 0; y < motionSize; y++) {
        for (var x = 0; x < motionSize; x++) {
          final c = curr.getPixel(x, y).r.toDouble();
          final n = next.getPixel(x, y).r.toDouble();
          out.add((n - c) / (n + c + eps));
        }
      }
      for (var y = 0; y < motionSize; y++) {
        for (var x = 0; x < motionSize; x++) {
          final c = curr.getPixel(x, y).g.toDouble();
          final n = next.getPixel(x, y).g.toDouble();
          out.add((n - c) / (n + c + eps));
        }
      }
      for (var y = 0; y < motionSize; y++) {
        for (var x = 0; x < motionSize; x++) {
          final c = curr.getPixel(x, y).b.toDouble();
          final n = next.getPixel(x, y).b.toDouble();
          out.add((n - c) / (n + c + eps));
        }
      }
    }
    return out;
  }

  dynamic _makeTensor(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    dynamic build(int dim) {
      final size = shape[dim];
      if (dim == shape.length - 1) {
        return List<double>.filled(size, 0.0, growable: false);
      }
      return List<dynamic>.generate(size, (_) => build(dim + 1), growable: false);
    }

    return build(0);
  }

  List<double> _flatFloatArray(dynamic arr) {
    if (arr is num) return <double>[arr.toDouble()];
    if (arr is List) {
      final out = <double>[];
      for (final item in arr) {
        out.addAll(_flatFloatArray(item));
      }
      return out;
    }
    return <double>[];
  }

  dynamic _reshapeToShape(List<double> values, List<int> shape) {
    final total = shape.fold<int>(1, (int p, int v) => p * v);
    List<double> normalized = values;
    if (normalized.length < total) {
      normalized = <double>[...normalized, ...List<double>.filled(total - normalized.length, 0.0)];
    } else if (normalized.length > total) {
      normalized = normalized.sublist(0, total);
    }
    var idx = 0;
    dynamic build(int dim) {
      if (dim == shape.length - 1) {
        final out = List<double>.filled(shape[dim], 0.0, growable: false);
        for (var i = 0; i < out.length; i++) {
          out[i] = normalized[idx++];
        }
        return out;
      }
      return List<dynamic>.generate(shape[dim], (_) => build(dim + 1), growable: false);
    }

    return build(0);
  }
}
