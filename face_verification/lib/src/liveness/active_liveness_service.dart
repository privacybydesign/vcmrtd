import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:face_verification/face_verification.dart';

// The five gesture challenges used in active liveness verification.
enum LivenessAction { blink, turnLeft, turnRight, mouthOpen, smile }

// Converts [LivenessAction] values to the wire-format strings sent over the
// event channel to Flutter (e.g. 'BLINK', 'TURN_LEFT').
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
  // A shake spike typically lasts only 1 frame. Require the eye to stay above
  // the closed threshold for this many frames before the blink can be confirmed.
  static const int blinkMinClosedFrames = 2;

  static final double mouthOpenThreshold = FaceVerificationTuning.mouthOpenThreshold;
  static const double jawOpenRelativeDelta = 0.15;
  static const double smileSuppressesMouthBlend = 0.60;

  static const double smileRelativeBlendDelta = 0.20;
  static const double smileWidthThreshold = 0.025;
  static const double smileLiftThreshold = 0.015;
  // Geometry-only smile detection requires blendshapes to confirm actual smile musculature.
  static const double smileGeometryMinBlend = 0.15;
  static const double mouthSuppressesSmileBlend = 0.25;

  static final double yawThresholdDeg = FaceVerificationTuning.turnYawThreshold;
  static const double landmarkTurnThreshold = 0.10;
  static const double landmarkTurnRelease = 0.05;
  static const double yawReleaseDeg = 5.0;
  // Phone shake causes 1–2 frame landmark jitter that can mimic gestures. Require
  // consecutive detected frames before confirming. Smile uses more frames because
  // natural resting expressions can sit close to the threshold.
  static const int mouthOpenMinConfirmFrames = 3;
  static const int smileMinConfirmFrames = 5;

  bool isAligning = true;
  bool get isWaitingForRest => _waitingForRest;

  LivenessAction? _currentAction;
  int _confirmCount = 0;

  _BlinkPhase _blinkPhase = _BlinkPhase.open;
  int _blinkClosedFrames = 0;
  bool _turnDetectedLatch = false;

  bool _waitingForRest = false;
  LivenessAction? _queuedNextAction;
  int _restStableCount = 0;
  int _restGraceUntilMs = 0;
  int _gestureConfirmFrames = 0;

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
    _gestureConfirmFrames = 0;

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
    _gestureConfirmFrames = 0;

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
    final avgEar = (_computeEar(lm, true) + _computeEar(lm, false)) / 2.0;
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

    final avgEar = (_computeEar(lm, true) + _computeEar(lm, false)) / 2.0;
    if (avgEar < restMaxEar) return false;

    final mouth = _mouthRatio(lm);
    if (mouth > restMaxMouth) return false;

    final smile = ((_blend(face, 'mouthSmileLeft')) + (_blend(face, 'mouthSmileRight'))) / 2.0;
    if (smile > restMaxSmile) return false;
    return true;
  }

  bool checkFaceAtRest(FaceObservation face) {
    final lm = face.result.landmarks.first;
    return _isFaceAtRest(face, lm);
  }

  // Fuses EAR and blendshape, then compares against the person's own resting eye state.
  // This makes detection work regardless of natural eye shape — narrow eyes, thick eyelids, glasses, etc.
  // If no alignment baseline was captured (e.g., timeout), the first few frames self-calibrate.
  bool _detectBlink(FaceObservation face, List<NormalizedLandmark> lm) {
    // Compute a fused eye-close score per eye, then take the STRONGER one.
    // Averaging both eyes flattens the signal for fast or asymmetric blinks —
    // one eye may show significantly more closure than the other.
    double fuseEye(double ear, double blend) {
      final earScore = 1.0 - (ear / earOpenThreshold).clamp(0.0, 1.0);
      final blendScore = (blend / blendEyeClosedThreshold).clamp(0.0, 1.0);
      return earWeight * earScore + blendWeight * blendScore;
    }

    final fusedL = fuseEye(_computeEar(lm, true), _blend(face, 'eyeBlinkLeft').clamp(0.0, 1.0));
    final fusedR = fuseEye(_computeEar(lm, false), _blend(face, 'eyeBlinkRight').clamp(0.0, 1.0));
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
        if (closed) {
          _blinkPhase = _BlinkPhase.closed;
          _blinkClosedFrames = 1;
        }
      case _BlinkPhase.closed:
        if (closed) {
          _blinkClosedFrames++;
        } else if (open) {
          // Require the eye to have been closed for at least blinkMinClosedFrames.
          // A single-frame spike from phone shake produces closed=1 then open,
          // which is rejected here and resets to open phase.
          if (_blinkClosedFrames >= blinkMinClosedFrames) {
            _blinkPhase = _BlinkPhase.detected;
          } else {
            _blinkPhase = _BlinkPhase.open;
            _blinkClosedFrames = 0;
          }
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

  // The pose matrix yaw sign convention differs between iOS (ARKit) and Android
  // (Camera2 / OpenCV): a left turn produces a positive delta on iOS and a
  // negative delta on Android. The sign flip is applied here per platform so
  // the rest of the detection logic stays platform-agnostic.
  bool _yawThresholdCrossed(double? matD, bool left) {
    if (matD == null) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return left ? matD >= yawThresholdDeg : matD <= -yawThresholdDeg;
    }
    return left ? matD <= -yawThresholdDeg : matD >= yawThresholdDeg;
  }

  bool _isTurnReleased(double? matD, double lmD) {
    return (matD == null || matD.abs() < yawReleaseDeg) && lmD.abs() < landmarkTurnRelease;
  }

  bool _detectMouthOpen(FaceObservation face, List<NormalizedLandmark> lm) {
    final smile = (_blend(face, 'mouthSmileLeft') + _blend(face, 'mouthSmileRight')) / 2.0;
    if (smile >= smileSuppressesMouthBlend) {
      _gestureConfirmFrames = 0;
      return false;
    }

    final jawBlend = _blend(face, 'jawOpen');
    final ratio = _mouthRatio(lm);
    if (!_actionBaselineReady) {
      _accumulateActionBaseline(face);
      return false;
    }
    final jawDelta = jawBlend - (_neutralJaw ?? 0.0);
    final ratioDelta = ratio - (_neutralMouth ?? 0.0);
    if (jawDelta >= jawOpenRelativeDelta || ratioDelta >= mouthOpenThreshold) {
      _gestureConfirmFrames++;
      return _gestureConfirmFrames >= mouthOpenMinConfirmFrames;
    }
    _gestureConfirmFrames = 0;
    return false;
  }

  bool _detectSmile(FaceObservation face, List<NormalizedLandmark> lm) {
    final jaw = _blend(face, 'jawOpen');
    if (jaw >= mouthSuppressesSmileBlend) {
      _gestureConfirmFrames = 0;
      return false;
    }
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
    final geometryHit = sBlend >= smileGeometryMinBlend && widthD >= smileWidthThreshold && liftD >= smileLiftThreshold;
    if (blendD >= smileRelativeBlendDelta || geometryHit) {
      _gestureConfirmFrames++;
      return _gestureConfirmFrames >= smileMinConfirmFrames;
    }
    _gestureConfirmFrames = 0;
    return false;
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

  // Landmark-based yaw proxy: (nose tip X − face centre X) / face width.
  // lm[234] = left ear, lm[454] = right ear, lm[1] = nose tip.
  // Positive values indicate a rightward turn. Used as a fallback when the
  // pose matrix yaw is unavailable and as a secondary confirmation for turns.
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
}

// Eye Aspect Ratio (EAR) = (vertical openness) / (horizontal span).
// Formula: (||p2−p6|| + ||p3−p5||) / (2 × ||p1−p4||)
// Uses MediaPipe face mesh indices (478-landmark model):
//   Left eye  — vertical: 385↔380, 387↔373; horizontal: 362↔263
//   Right eye — vertical: 160↔144, 158↔153; horizontal: 33↔133
// Extracted as a module-level function so _BaselineAccumulator can call it
// without creating a circular dependency on ActiveLivenessService.
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

// Euclidean distance between two normalized landmarks (XY plane only).
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
    // The fusion formula is duplicated from _detectBlink intentionally:
    // _BaselineAccumulator cannot call instance methods of ActiveLivenessService
    // without introducing a circular dependency, so the logic is inlined here.
    final bL = (face.blendshapeScores['eyeBlinkLeft'] ?? 0.0).clamp(0.0, 1.0);
    final bR = (face.blendshapeScores['eyeBlinkRight'] ?? 0.0).clamp(0.0, 1.0);
    double fuseEyeScore(double ear, double blend) {
      final earScore = 1.0 - (ear / ActiveLivenessService.earOpenThreshold).clamp(0.0, 1.0);
      final blendScore = (blend / ActiveLivenessService.blendEyeClosedThreshold).clamp(0.0, 1.0);
      return ActiveLivenessService.earWeight * earScore + ActiveLivenessService.blendWeight * blendScore;
    }

    final fusedL = fuseEyeScore(_computeEar(lm, true), bL);
    final fusedR = fuseEyeScore(_computeEar(lm, false), bR);
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
