import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';
import 'package:vcmrtdapp/features/face_verification/tflite_tensor_utils.dart';

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
    required this.jaw,
    required this.smileLift,
    required this.smileWidth,
    required this.smileBlend,
    required this.eyeFused,
  });

  final double? yawMatrix;
  final double yawLandmark;
  final double mouth;
  final double jaw;
  final double smileLift;
  final double smileWidth;
  final double smileBlend;
  final double eyeFused;
}

class AlignmentFrameDiagnostics {
  const AlignmentFrameDiagnostics({
    required this.atRest,
    required this.rejectReason,
    required this.stableFramesBefore,
    required this.stableFramesAfter,
    required this.baselineFrames,
    required this.yaw,
    required this.mouth,
    required this.smile,
    required this.avgEar,
  });

  final bool atRest;
  final String? rejectReason;
  final int stableFramesBefore;
  final int stableFramesAfter;
  final int baselineFrames;
  final double yaw;
  final double mouth;
  final double smile;
  final double avgEar;
}

class ActiveLivenessService {
  static const int confirmThreshold = 2;
  static const int confirmIncrement = 2;
  static const int confirmDecay = 0;
  static const int baselineFrames = 3;

  static const int restStableFrames = 2;
  static const double restMaxYawDeg = 12.0;
  static const int restGraceMs = 300;
  static const double restMaxEar = 0.10;
  static const double restMaxMouth = 0.05;
  static const double restMaxSmile = 0.35;

  static const double earOpenThreshold = 0.25;
  static const double blendEyeClosedThreshold = 0.45;
  static const double earWeight = 0.3;
  static const double blendWeight = 0.7;
  // Relative blink: how much the fused eye-close score must rise above the person's own baseline.
  // Lowered 0.28 → 0.20: fast blinks are often captured mid-closure (not at peak),
  // so a lower threshold catches the partial-closure frames the camera actually sees.
  static const double blinkRelativeClosedDelta = 0.20;
  static const double blinkRelativeOpenDelta = 0.10;

  static final double mouthOpenThreshold = FaceVerificationTuning.mouthOpenThreshold;
  static const double jawOpenRelativeDelta = 0.15;
  static const double smileSuppressesMouthBlend = 0.60;

  static const double smileRelativeBlendDelta = 0.20;
  static const double smileWidthThreshold = 0.018;
  static const double smileLiftThreshold = 0.010;
  static const double mouthSuppressesSmileBlend = 0.25;

  static final double yawThresholdDeg = FaceVerificationTuning.turnYawThreshold;
  static const double landmarkTurnThreshold = 0.10;
  static const double landmarkTurnRelease = 0.05;
  static const double yawReleaseDeg = 5.0;

  bool isAligning = true;

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
  double? _neutralJaw;
  double? _neutralSmileLift;
  double? _neutralSmileWidth;
  double? _neutralSmileBlend;
  bool _actionBaselineReady = false;

  final _BaselineAccumulator _actionAccumulator = _BaselineAccumulator();
  final _BaselineAccumulator _restAccumulator = _BaselineAccumulator();
  final _BaselineAccumulator _alignAccumulator = _BaselineAccumulator();
  final _BaselineAccumulator _eyeBaselineAccumulator = _BaselineAccumulator();
  double? _eyeOpenBaseline;

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
    _neutralJaw = null;
    _neutralSmileLift = null;
    _neutralSmileWidth = null;
    _neutralSmileBlend = null;
    _actionBaselineReady = false;

    _actionAccumulator.clear();
    _restAccumulator.clear();
    _alignAccumulator.clear();
    _eyeBaselineAccumulator.clear();
    _eyeOpenBaseline = null;
    isAligning = true;
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
    _eyeBaselineAccumulator.clear();
    _eyeOpenBaseline = null;

    _neutralYawMatrix = null;
    _neutralYawLandmark = null;
    _neutralMouth = null;
    _neutralJaw = null;
    _neutralSmileLift = null;
    _neutralSmileWidth = null;
    _neutralSmileBlend = null;

    if (baseline != null) {
      switch (action) {
        case LivenessAction.turnLeft:
        case LivenessAction.turnRight:
          _neutralYawMatrix = baseline.yawMatrix;
          _neutralYawLandmark = baseline.yawLandmark;
        case LivenessAction.mouthOpen:
          _neutralMouth = baseline.mouth;
          _neutralJaw = baseline.jaw;
        case LivenessAction.smile:
          _neutralSmileLift = baseline.smileLift;
          _neutralSmileWidth = baseline.smileWidth;
          _neutralSmileBlend = baseline.smileBlend;
        case LivenessAction.blink:
          _eyeOpenBaseline = baseline.eyeFused;
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
    _alignAccumulator.add(face);
    if (_alignAccumulator.size >= baselineFrames) {
      final snap = _alignAccumulator.computeSnapshot();
      _alignAccumulator.clear();
      startAction(action, baseline: snap);
      return true;
    }
    return false;
  }

  AlignmentFrameDiagnostics diagnoseAlignmentFrame(FaceObservation face) {
    final lm = face.result.landmarks.first;
    final yaw = (face.yawDegrees ?? 0.0).abs();
    final avgEar = (_ear(lm, true) + _ear(lm, false)) / 2.0;
    final mouth = _mouthRatio(lm);
    final smile = ((_blend(face, 'mouthSmileLeft')) + (_blend(face, 'mouthSmileRight'))) / 2.0;

    String? rejectReason;
    if (yaw > restMaxYawDeg) {
      rejectReason = 'yaw';
    } else if (avgEar < restMaxEar) {
      rejectReason = 'eyes';
    } else if (mouth > restMaxMouth) {
      rejectReason = 'mouth';
    } else if (smile > restMaxSmile) {
      rejectReason = 'smile';
    }

    final stableBefore = _alignAccumulator.size;
    final atRest = rejectReason == null;
    return AlignmentFrameDiagnostics(
      atRest: atRest,
      rejectReason: rejectReason,
      stableFramesBefore: stableBefore,
      stableFramesAfter: atRest ? stableBefore + 1 : 0,
      baselineFrames: baselineFrames,
      yaw: yaw,
      mouth: mouth,
      smile: smile,
      avgEar: avgEar,
    );
  }

  bool processFrame({required FaceObservation face}) {
    final action = _currentAction;
    if (action == null) return false;

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
      _restAccumulator.add(face);
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

  // Fuses EAR and blendshape, then compares against the person's own resting eye state.
  // This makes detection work regardless of natural eye shape — narrow eyes, thick eyelids, glasses, etc.
  // If no alignment baseline was captured (e.g., timeout), the first few frames self-calibrate.
  bool _detectBlink(FaceObservation face, List<NormalizedLandmark> lm) {
    // Compute a fused eye-close score per eye, then take the STRONGER one.
    // Averaging both eyes flattens the signal for fast or asymmetric blinks —
    // one eye may show significantly more closure than the other.
    double _eyeFused(double ear, double blend) {
      final earScore = 1.0 - (ear / earOpenThreshold).clamp(0.0, 1.0);
      final blendScore = (blend / blendEyeClosedThreshold).clamp(0.0, 1.0);
      return earWeight * earScore + blendWeight * blendScore;
    }

    final fusedL = _eyeFused(_ear(lm, true), _blend(face, 'eyeBlinkLeft').clamp(0.0, 1.0));
    final fusedR = _eyeFused(_ear(lm, false), _blend(face, 'eyeBlinkRight').clamp(0.0, 1.0));
    final fused = math.max(fusedL, fusedR);

    if (_eyeOpenBaseline == null) {
      _eyeBaselineAccumulator.add(face);
      if (_eyeBaselineAccumulator.size < baselineFrames) return false;
      _eyeOpenBaseline = _eyeBaselineAccumulator.computeSnapshot().eyeFused;
    }

    final base = _eyeOpenBaseline!;
    final closed = fused >= base + blinkRelativeClosedDelta;
    final open = fused <= base + blinkRelativeOpenDelta;

    switch (_blinkPhase) {
      case _BlinkPhase.open:
        // A single frame above the closed threshold is enough to enter the closed
        // state — fast blinks peak for only 1 frame at 30 fps and were previously
        // reset on frame 2 by the old 'closing' intermediate step.
        if (closed) {
          _blinkClosedFrames = 1;
          _blinkPhase = _BlinkPhase.closed;
        }
      case _BlinkPhase.closed:
        if (closed) {
          _blinkClosedFrames++;
        } else if (open) {
          _blinkPhase = _BlinkPhase.detected;
        }
      // In the range between open and closed thresholds: stay in closed and wait.
      case _BlinkPhase.detected:
        break;
    }
    return _blinkPhase == _BlinkPhase.detected;
  }

  // Latch pattern: once the yaw threshold is crossed, hold "detected" until the face returns
  // near neutral. Without this, a slow turn would fire and immediately un-fire on the same frame.
  bool _detectTurn(FaceObservation face, List<NormalizedLandmark> lm, {required bool left}) {
    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face);
      return false;
    }
    final matYaw = face.yawDegrees;
    final lmYaw = _landmarkYaw(lm);
    final matD = matYaw == null ? null : matYaw - (_neutralYawMatrix ?? 0.0);
    final lmD = lmYaw - (_neutralYawLandmark ?? 0.0);

    if (!_turnDetectedLatch) {
      final hit =
          _yawThresholdCrossed(matD, left) ||
          (matYaw == null && (left ? lmD <= -landmarkTurnThreshold : lmD >= landmarkTurnThreshold));
      if (hit) _turnDetectedLatch = true;
      return hit;
    }

    if (_isTurnReleased(matD, lmD)) {
      _turnDetectedLatch = false;
      return false;
    }
    return true;
  }

  bool _yawThresholdCrossed(double? matD, bool left) {
    if (matD == null) return false;
    return left ? matD <= -yawThresholdDeg : matD >= yawThresholdDeg;
  }

  bool _isTurnReleased(double? matD, double lmD) {
    return (matD == null || matD.abs() < yawReleaseDeg) && lmD.abs() < landmarkTurnRelease;
  }

  bool _detectMouthOpen(FaceObservation face, List<NormalizedLandmark> lm) {
    final smile = (_blend(face, 'mouthSmileLeft') + _blend(face, 'mouthSmileRight')) / 2.0;
    if (smile >= smileSuppressesMouthBlend) return false;

    final jawBlend = _blend(face, 'jawOpen');
    final ratio = _mouthRatio(lm);
    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face);
      return false;
    }
    final jawDelta = jawBlend - (_neutralJaw ?? 0.0);
    final ratioDelta = ratio - (_neutralMouth ?? 0.0);
    return jawDelta >= jawOpenRelativeDelta || ratioDelta >= mouthOpenThreshold;
  }

  bool _detectSmile(FaceObservation face, List<NormalizedLandmark> lm) {
    final jaw = _blend(face, 'jawOpen');
    if (jaw >= mouthSuppressesSmileBlend) return false;
    final sBlend = (_blend(face, 'mouthSmileLeft') + _blend(face, 'mouthSmileRight')) / 2.0;

    final fH = _landmarkDist(lm[10], lm[152]).clamp(1e-6, 1e6);
    final fW = _landmarkDist(lm[234], lm[454]).clamp(1e-6, 1e6);
    final cornerY = (lm[61].y + lm[291].y) / 2.0;
    final lift = (lm[0].y - cornerY) / fH;
    final width = _landmarkDist(lm[61], lm[291]) / fW;

    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face);
      return false;
    }
    final liftD = lift - (_neutralSmileLift ?? 0.0);
    final widthD = width - (_neutralSmileWidth ?? 0.0);
    final blendD = sBlend - (_neutralSmileBlend ?? 0.0);
    return blendD >= smileRelativeBlendDelta || (widthD >= smileWidthThreshold && liftD >= smileLiftThreshold);
  }

  // Collects a short neutral baseline before relative gesture detection begins.
  // Absolute thresholds would fail for faces that naturally rest off-center or with a
  // slightly open mouth, so gestures are measured as deltas from this personal baseline.
  void _accumulateActionBaseline(FaceObservation face) {
    _actionAccumulator.add(face);
    if (_actionAccumulator.size < baselineFrames) return;
    final snap = _actionAccumulator.computeSnapshot();
    switch (_currentAction) {
      case LivenessAction.turnLeft:
      case LivenessAction.turnRight:
        _neutralYawMatrix = snap.yawMatrix;
        _neutralYawLandmark = snap.yawLandmark;
      case LivenessAction.mouthOpen:
        _neutralMouth = snap.mouth;
        _neutralJaw = snap.jaw;
      case LivenessAction.smile:
        _neutralSmileLift = snap.smileLift;
        _neutralSmileWidth = snap.smileWidth;
        _neutralSmileBlend = snap.smileBlend;
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
    final fH = _landmarkDist(lm[10], lm[152]).clamp(1e-6, 1e6);
    return _landmarkDist(lm[13], lm[14]) / fH;
  }

  double _ear(List<NormalizedLandmark> lm, bool left) => _computeEar(lm, left);
}

// Eye Aspect Ratio: (vertical openness) / (horizontal span), MediaPipe face mesh indices.
// Extracted top-level so _BaselineAccumulator can use it without referencing ActiveLivenessService.
double _computeEar(List<NormalizedLandmark> lm, bool left) {
  if (left) {
    final a = _landmarkDist(lm[385], lm[380]);
    final b = _landmarkDist(lm[387], lm[373]);
    final c = _landmarkDist(lm[362], lm[263]);
    return (a + b) / ((2.0 * c) + 1e-6);
  } else {
    final a = _landmarkDist(lm[160], lm[144]);
    final b = _landmarkDist(lm[158], lm[153]);
    final c = _landmarkDist(lm[33], lm[133]);
    return (a + b) / ((2.0 * c) + 1e-6);
  }
}

double _landmarkDist(NormalizedLandmark a, NormalizedLandmark b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

enum _BlinkPhase { open, closed, detected }

class _BaselineAccumulator {
  final List<double> _yawMatrix = <double>[];
  final List<double> _yawLandmark = <double>[];
  final List<double> _mouth = <double>[];
  final List<double> _jaw = <double>[];
  final List<double> _smileLift = <double>[];
  final List<double> _smileWidth = <double>[];
  final List<double> _smileBlend = <double>[];
  final List<double> _eyeFused = <double>[];

  int get size => _yawLandmark.length;

  void clear() {
    _yawMatrix.clear();
    _yawLandmark.clear();
    _mouth.clear();
    _jaw.clear();
    _smileLift.clear();
    _smileWidth.clear();
    _smileBlend.clear();
    _eyeFused.clear();
  }

  void add(FaceObservation face) {
    final lm = face.result.landmarks.first;
    final matrixYaw = face.yawDegrees;
    final fH = _landmarkDist(lm[10], lm[152]).clamp(1e-6, 1e6);
    final fW = _landmarkDist(lm[234], lm[454]).clamp(1e-6, 1e6);
    final cornerY = (lm[61].y + lm[291].y) / 2.0;
    if (matrixYaw != null) _yawMatrix.add(matrixYaw);
    _yawLandmark.add((lm[1].x - ((lm[234].x + lm[454].x) / 2.0)) / (lm[454].x - lm[234].x).abs().clamp(1e-6, 1e6));
    _mouth.add(_landmarkDist(lm[13], lm[14]) / fH);
    _jaw.add((face.blendshapeScores['jawOpen'] ?? 0.0).clamp(0.0, 1.0));
    _smileLift.add((lm[0].y - cornerY) / fH);
    _smileWidth.add(_landmarkDist(lm[61], lm[291]) / fW);
    _smileBlend.add(
      (((face.blendshapeScores['mouthSmileLeft'] ?? 0.0) + (face.blendshapeScores['mouthSmileRight'] ?? 0.0)) / 2.0)
          .clamp(0.0, 1.0),
    );
    // Eye-close fused score at rest — baseline for relative blink detection.
    // Uses max of both eyes to match the per-eye-max used during detection.
    final bL = (face.blendshapeScores['eyeBlinkLeft'] ?? 0.0).clamp(0.0, 1.0);
    final bR = (face.blendshapeScores['eyeBlinkRight'] ?? 0.0).clamp(0.0, 1.0);
    double _eyeFusedScore(double ear, double blend) {
      final earScore = 1.0 - (ear / ActiveLivenessService.earOpenThreshold).clamp(0.0, 1.0);
      final blendScore = (blend / ActiveLivenessService.blendEyeClosedThreshold).clamp(0.0, 1.0);
      return ActiveLivenessService.earWeight * earScore + ActiveLivenessService.blendWeight * blendScore;
    }

    final fusedL = _eyeFusedScore(_computeEar(lm, true), bL);
    final fusedR = _eyeFusedScore(_computeEar(lm, false), bR);
    _eyeFused.add(math.max(fusedL, fusedR));
  }

  BaselineSnapshot computeSnapshot() {
    return BaselineSnapshot(
      yawMatrix: _yawMatrix.isEmpty ? null : _median(_yawMatrix),
      yawLandmark: _median(_yawLandmark),
      mouth: _median(_mouth),
      jaw: _jaw.isEmpty ? 0.0 : _median(_jaw),
      smileLift: _median(_smileLift),
      smileWidth: _median(_smileWidth),
      smileBlend: _smileBlend.isEmpty ? 0.0 : _median(_smileBlend),
      eyeFused: _eyeFused.isEmpty ? 0.0 : _median(_eyeFused),
    );
  }

  double _median(List<double> values) {
    final sorted = <double>[...values]..sort();
    final m = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[m];
    return (sorted[m - 1] + sorted[m]) / 2.0;
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
  static const int _liveClassIdx = 1; // MiniFASNet softmax output: 0 = spoof (depth), 1 = live, 2 = spoof (clip)
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
  double _scoresSum = 0.0;

  final _BigSmallService _bigSmall = _BigSmallService();
  final List<_RppgFrame> _rppgFrameBuffer = <_RppgFrame>[];
  final Queue<double> _bvpSamples = Queue<double>();
  final Queue<int> _bvpSampleTimes = Queue<int>();
  int _lastFrameBufferedMs = 0;

  Future<void> initialize() async {
    debugPrint('[FaceVerification] Passive service: loading minifasnet_v1se.tflite interpreter');
    _v1 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v1se.tflite', options: _cpuOptions(2));
    debugPrint('[FaceVerification] Passive service: loading minifasnet_v2.tflite interpreter');
    _v2 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v2.tflite', options: _cpuOptions(2));

    _readAntiSpoofShapes();
    await _bigSmall.initialize();
  }

  void initializeFromAddresses({required int v1Addr, required int v2Addr, required List<int> bigSmallAddrs}) {
    debugPrint('[FaceVerification] Passive service: adopting MiniFASNet v1 from address');
    _v1 = Interpreter.fromAddress(v1Addr);
    debugPrint('[FaceVerification] Passive service: adopting MiniFASNet v2 from address');
    _v2 = Interpreter.fromAddress(v2Addr);
    _readAntiSpoofShapes();
    _bigSmall.initializeFromAddresses(bigSmallAddrs);
  }

  void initializeFromBuffers({required Uint8List v1, required Uint8List v2, required List<Uint8List> bigSmall}) {
    debugPrint('[FaceVerification] Passive service: initializing minifasnet_v1se.tflite from buffer');
    _v1 = Interpreter.fromBuffer(v1, options: _cpuOptions(2));
    debugPrint('[FaceVerification] Passive service: initializing minifasnet_v2.tflite from buffer');
    _v2 = Interpreter.fromBuffer(v2, options: _cpuOptions(2));

    _readAntiSpoofShapes();
    _bigSmall.initializeFromBuffers(bigSmall);
  }

  void _readAntiSpoofShapes() {
    final s1 = _v1!.getInputTensor(0).shape;
    final s2 = _v2!.getInputTensor(0).shape;
    _v1Nchw = s1.length == 4 && s1[1] == 3;
    _v2Nchw = s2.length == 4 && s2[1] == 3;
    debugPrint('[FaceVerification] Passive service: MiniFASNet v1 input shape=$s1');
    debugPrint('[FaceVerification] Passive service: MiniFASNet v2 input shape=$s2');
  }

  void reset() {
    _scores.clear();
    _scoreTimes.clear();
    _scoresSum = 0.0;
    _rppgFrameBuffer.clear();
    _bvpSamples.clear();
    _bvpSampleTimes.clear();
    _lastFrameBufferedMs = 0;
  }

  void collectPassiveMetrics(img.Image frame, FaceObservation face) {
    _sampleAntiSpoof(frame, face);
    _sampleRppg(frame, face);
  }

  double? getAntiSpoofScore() {
    if (_scores.isEmpty) return null;
    return _scoresSum / _scores.length;
  }

  bool isAntiSpoofPassed() {
    if (_scores.length < _minAntiSpoofSamples) return false;
    final avg = getAntiSpoofScore();
    if (avg == null) return false;
    return avg >= antiSpoofMinScore;
  }

  RppgResult? getRppgResult() {
    if (_bvpSamples.length < _minBvpSamples || _bvpSampleTimes.length < 2) return null;
    final durationMs = (_bvpSampleTimes.last - _bvpSampleTimes.first).clamp(1, 1 << 30);
    if (durationMs < _minDurationMs) return null;
    final fps = (((_bvpSamples.length - 1) * 1000) / durationMs).clamp(1, 1000).toInt();
    return _evaluateBvp(_bvpSamples.toList(growable: false), fps);
  }

  void _sampleAntiSpoof(img.Image frame, FaceObservation face) {
    if (_random.nextDouble() >= _antiSpoofSampleRate) return;
    final yaw = face.yawDegrees;
    final isFrontal = yaw == null || yaw.abs() < _antiSpoofMaxYawDeg;
    if (!isFrontal) return;
    final score = _scoreFrame(frame, face.result);
    if (score != null) {
      _scores.add(score);
      _scoresSum += score;
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
          _bvpSamples.removeFirst();
          _bvpSampleTimes.removeFirst();
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

  // MiniFASNet was trained on OpenCV BGR images, so channels are written in reverse order
  // relative to the RGB bytes returned by the image library.
  ByteBuffer _preprocess(img.Image image, {required bool nchw}) {
    final rawBytes = image.getBytes(order: img.ChannelOrder.rgb);
    const planeSize = _inputSize * _inputSize;
    final buf = Float32List(planeSize * 3);
    if (nchw) {
      for (var i = 0; i < planeSize; i++) {
        buf[i] = rawBytes[i * 3 + 2].toDouble(); // B
        buf[planeSize + i] = rawBytes[i * 3 + 1].toDouble(); // G
        buf[2 * planeSize + i] = rawBytes[i * 3].toDouble(); // R
      }
    } else {
      for (var i = 0; i < planeSize; i++) {
        buf[i * 3] = rawBytes[i * 3 + 2].toDouble(); // B
        buf[i * 3 + 1] = rawBytes[i * 3 + 1].toDouble(); // G
        buf[i * 3 + 2] = rawBytes[i * 3].toDouble(); // R
      }
    }
    return buf.buffer;
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
      debugPrint('[FaceVerification] BigSmall service: loading ${_modelFiles[i]} interpreter');
      try {
        _interpreters[i] = await Interpreter.fromAsset(_modelFiles[i], options: _makeInterpOptions(2, useGpu: true));
      } catch (_) {
        _interpreters[i]?.close();
        _interpreters[i] = await Interpreter.fromAsset(_modelFiles[i], options: _makeInterpOptions(2, useGpu: false));
      }
      _loadShapes(i);
    }
  }

  void initializeFromAddresses(List<int> addrs) {
    for (var i = 0; i < addrs.length && i < _modelFiles.length; i++) {
      if (_interpreters[i] != null) continue;
      debugPrint('[FaceVerification] BigSmall service: adopting ${_modelFiles[i]} from address');
      _interpreters[i] = Interpreter.fromAddress(addrs[i]);
      _loadShapes(i);
    }
  }

  void initializeFromBuffers(List<Uint8List> modelBuffers) {
    for (var i = 0; i < modelBuffers.length; i++) {
      if (_interpreters[i] != null) continue;
      debugPrint('[FaceVerification] BigSmall service: initializing ${_modelFiles[i]} from buffer');
      try {
        _interpreters[i] = Interpreter.fromBuffer(modelBuffers[i], options: _makeInterpOptions(2, useGpu: true));
      } catch (_) {
        _interpreters[i]?.close();
        _interpreters[i] = Interpreter.fromBuffer(modelBuffers[i], options: _makeInterpOptions(2, useGpu: false));
      }
      _loadShapes(i);
    }
  }

  void _loadShapes(int i) {
    _appearanceShapes[i] = _interpreters[i]!.getInputTensor(0).shape;
    _motionShapes[i] = _interpreters[i]!.getInputTensor(1).shape;
    _outputShapes[i] = _interpreters[i]!.getOutputTensor(0).shape;
    debugPrint(
      '[FaceVerification] BigSmall service: ${_modelFiles[i]} shapes '
      'appearance=${_appearanceShapes[i]} motion=${_motionShapes[i]} output=${_outputShapes[i]}',
    );
  }

  List<double>? runInference(List<_RppgFrame> framesBatch) {
    if (framesBatch.length != bufferFrames) return null;
    if (_interpreters.every((Interpreter? i) => i == null)) return null;

    final appearanceBuf = _buildAppearanceBuf(framesBatch);
    final motionBuf = _buildMotionBuf(framesBatch);

    final sum = List<double>.filled(frames, 0.0);
    var count = 0;

    for (var i = 0; i < _interpreters.length; i++) {
      final interp = _interpreters[i];
      final oShape = _outputShapes[i];
      if (interp == null || oShape == null) continue;

      final outTensor = tfliteMakeTensor(oShape);
      interp.runForMultipleInputs(<Object>[appearanceBuf.buffer, motionBuf.buffer], <int, Object>{0: outTensor});
      final out = tfliteFlatFloatArray(outTensor);
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

  // Packs frames as planar channels (all R pixels, then G, then B) as required by the
  // BigSmall model's appearance stream input layout.
  Float32List _buildAppearanceBuf(List<_RppgFrame> batch) {
    const planeSize = appearanceSize * appearanceSize;
    final buf = Float32List(frames * 3 * planeSize);
    var offset = 0;
    for (var fi = 1; fi <= frames; fi++) {
      final rawBytes = batch[fi].appearance.getBytes(order: img.ChannelOrder.rgb);
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3] / 255.0;
      }
      offset += planeSize;
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3 + 1] / 255.0;
      }
      offset += planeSize;
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3 + 2] / 255.0;
      }
      offset += planeSize;
    }
    return buf;
  }

  // Normalized frame-to-frame pixel difference (nv - cv) / (nv + cv + ε) as a proxy for
  // optical flow. This is the "motion" stream expected by the BigSmall rPPG model.
  Float32List _buildMotionBuf(List<_RppgFrame> batch) {
    const planeSize = motionSize * motionSize;
    const eps = 1e-7;
    final buf = Float32List(frames * 3 * planeSize);
    var offset = 0;
    for (var fi = 0; fi < frames; fi++) {
      final currBytes = batch[fi].motion.getBytes(order: img.ChannelOrder.rgb);
      final nextBytes = batch[fi + 1].motion.getBytes(order: img.ChannelOrder.rgb);
      for (var c = 0; c < 3; c++) {
        for (var i = 0; i < planeSize; i++) {
          final cv = currBytes[i * 3 + c].toDouble();
          final nv = nextBytes[i * 3 + c].toDouble();
          buf[offset++] = (nv - cv) / (nv + cv + eps);
        }
      }
    }
    return buf;
  }
}

InterpreterOptions _makeInterpOptions(int threads, {required bool useGpu}) {
  final opts = InterpreterOptions()..threads = threads;
  if (useGpu && Platform.isAndroid) {
    try {
      opts.addDelegate(GpuDelegateV2());
    } catch (_) {}
  } else if (useGpu && Platform.isIOS) {
    try {
      opts.addDelegate(GpuDelegate());
    } catch (_) {}
  }
  return opts;
}

// MiniFASNet models have TRANSPOSE ops for NCHW input — GPU delegate produces
// incorrect outputs for NCHW layouts, so these models must run on CPU only.
InterpreterOptions _cpuOptions(int threads) => InterpreterOptions()..threads = threads;
