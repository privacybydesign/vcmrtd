import 'dart:async';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Steps in the liveness verification process.
/// Reimplements multipaz's SelfieCheckStep enum.
enum LivenessStep {
  initial,
  centerFace,
  rotateHeadLeft,
  rotateHeadRight,
  rotateHeadUp,
  rotateHeadDown,
  circularGaze,
  closeEyes,
  smile,
  lookStraight,
  completed,
  failed,
}

/// Feedback event types driving the UI.
enum FeedbackId {
  initial,
  centerFace,
  moveHorizontally,
  moveVertically,
  rotateHeadLeft,
  rotateHeadRight,
  rotateHeadUp,
  rotateHeadDown,
  circularGazeStart,
  circularGazeRemaining,
  sectorHit,
  keepHeadLevel,
  closeEyes,
  closeFirmly,
  smile,
  clearSmile,
  lookStraight,
  completed,
  failedTimeout,
}

class LivenessFeedback {
  final FeedbackId id;
  final String message;
  final String? param;

  const LivenessFeedback(this.id, this.message, {this.param});
}

/// Liveness detection service that reimplements multipaz's SelfieCheckViewModel.
///
/// Orchestrates a randomised sequence of face-based checks to verify the user
/// is a live person: centering, head rotations, circular gaze, eye closure,
/// smile, and a final straight-ahead gaze.
class SelfieLivenessService {
  // ── Constants (from multipaz) ────────────────────────────────
  static const double _faceCenterTolerance = 0.1;
  static const double _headRotationThreshold = 20.0;
  static const double _headStraightThreshold = 5.0;
  static const double _eyeOpenThreshold = 0.3;
  static const double _eyeClosedThreshold = 0.2;
  static const int _eyesClosedDuration = 30; // frames
  static const double _smilingThreshold = 0.7;
  static const int _stepTimeoutSec = 10;
  static const double _gazePitchTolerance = 25.0;
  static const double _gazeYawMax = 35.0;
  static const int _gazeMinConsecutiveHits = 3;
  static const int gazeCircleSectors = 4;
  static const int _enoughTimePassedSec = 1;

  // ── State ────────────────────────────────────────────────────
  LivenessStep _currentStep = LivenessStep.initial;
  LivenessStep get currentStep => _currentStep;

  final List<LivenessStep> _shuffledSteps = [];
  int _stepIndex = -1;

  int _eyesClosedCounter = 0;
  final Set<int> _gazeSectorsHit = {};
  int _lastGazeSector = -1;
  int _candidateGazeSector = -1;
  int _consecutiveGazeHits = 0;
  bool _allSectorsCovered = false;
  bool _isEnoughTimePassed = false;

  int _countdownSeconds = _stepTimeoutSec;
  int get countdownSeconds => _countdownSeconds;
  double _countdownProgress = 1.0;
  double get countdownProgress => _countdownProgress;

  Timer? _countdownTimer;

  List<bool> get gazeSectorStates {
    return List.generate(
      gazeCircleSectors,
      (i) => _gazeSectorsHit.contains(i),
    );
  }

  // ── Callbacks ────────────────────────────────────────────────
  void Function(LivenessStep step)? onStepChanged;
  void Function(LivenessFeedback feedback)? onFeedbackChanged;
  void Function()? onStepSuccess;
  void Function()? onCompleted;
  void Function()? onFailed;
  void Function(int seconds, double progress)? onCountdownTick;

  // ── Public API ───────────────────────────────────────────────

  void initialize() {
    _shuffledSteps.clear();
    _shuffledSteps.addAll([
      LivenessStep.rotateHeadLeft,
      LivenessStep.rotateHeadRight,
      LivenessStep.rotateHeadUp,
      LivenessStep.rotateHeadDown,
      LivenessStep.circularGaze,
      LivenessStep.closeEyes,
      LivenessStep.smile,
    ]..shuffle(Random()));
    _stepIndex = -1;
    _currentStep = LivenessStep.initial;
    _emitFeedback(FeedbackId.initial,
        'To verify your identity you will be asked to perform a series of '
        'head movements. All analysis happens on your device.');
  }

  void startVerification() {
    _resetStepState();
    _currentStep = LivenessStep.centerFace;
    onStepChanged?.call(_currentStep);
    _emitFeedback(FeedbackId.centerFace, 'Center your face in the frame');
    _startCountdown();
  }

  void resetForRetry() {
    _cancelCountdown();
    _resetStepState();
    initialize();
    onStepChanged?.call(_currentStep);
  }

  void dispose() {
    _cancelCountdown();
  }

  /// Called for every camera frame with a detected face.
  void onFaceDetected(Face face, Size imageSize) {
    if (_currentStep == LivenessStep.initial ||
        _currentStep == LivenessStep.failed ||
        _currentStep == LivenessStep.completed) {
      return;
    }

    switch (_currentStep) {
      case LivenessStep.centerFace:
        _processCenterFace(face, imageSize);
      case LivenessStep.rotateHeadLeft:
      case LivenessStep.rotateHeadRight:
      case LivenessStep.rotateHeadUp:
      case LivenessStep.rotateHeadDown:
        _processHeadRotation(face);
      case LivenessStep.circularGaze:
        _processCircularGaze(face);
      case LivenessStep.closeEyes:
        _processCloseEyes(face);
      case LivenessStep.smile:
        _processSmile(face);
      case LivenessStep.lookStraight:
        _processLookStraight(face, imageSize);
      default:
        break;
    }
  }

  // ── Step processors ──────────────────────────────────────────

  void _processCenterFace(Face face, Size imageSize) {
    if (imageSize.width < 1 || imageSize.height < 1) return;

    final box = face.boundingBox;
    final cx = (box.left + box.width / 2) / imageSize.width;
    final cy = (box.top + box.height / 2) / imageSize.height;
    final hCentered = (cx - 0.5).abs() < _faceCenterTolerance;
    final vCentered = (cy - 0.5).abs() < _faceCenterTolerance;

    if (hCentered && vCentered && _isEnoughTimePassed) {
      _proceedToNextStep();
    } else if (!vCentered) {
      _emitFeedback(FeedbackId.moveVertically, 'Move your face up or down');
    } else {
      _emitFeedback(
          FeedbackId.moveHorizontally, 'Move your face left or right');
    }
  }

  void _processHeadRotation(Face face) {
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    if (yaw == null || pitch == null) return;

    bool achieved = false;
    switch (_currentStep) {
      case LivenessStep.rotateHeadLeft:
        achieved = yaw > _headRotationThreshold;
      case LivenessStep.rotateHeadRight:
        achieved = yaw < -_headRotationThreshold;
      case LivenessStep.rotateHeadUp:
        achieved = pitch > _headRotationThreshold;
      case LivenessStep.rotateHeadDown:
        achieved = pitch < -_headRotationThreshold;
      default:
        break;
    }

    if (achieved) {
      _proceedToNextStep();
    }
  }

  void _processCircularGaze(Face face) {
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    if (yaw == null || pitch == null) return;

    // Skip frame if head is tilted too much, but don't reset progress.
    if (pitch.abs() > _gazePitchTolerance) {
      _emitFeedback(
          FeedbackId.keepHeadLevel, 'Keep your head level while looking');
      return;
    }

    final effectiveYaw = yaw.clamp(-_gazeYawMax, _gazeYawMax);
    final mapped = effectiveYaw + _gazeYawMax;
    final sectorSize = 2 * _gazeYawMax / gazeCircleSectors;
    final sector =
        (mapped / sectorSize).floor().clamp(0, gazeCircleSectors - 1);

    // Track how many consecutive frames the user stays in the SAME sector.
    if (sector == _candidateGazeSector) {
      _consecutiveGazeHits++;
    } else {
      _candidateGazeSector = sector;
      _consecutiveGazeHits = 1;
    }

    // Only register a sector after the user has looked at it steadily.
    if (_consecutiveGazeHits >= _gazeMinConsecutiveHits) {
      if (_gazeSectorsHit.add(sector)) {
        _emitFeedback(FeedbackId.sectorHit,
            'Keep looking around... ${gazeCircleSectors - _gazeSectorsHit.length} areas remaining',
            param: sector.toString());
      }
      _lastGazeSector = sector;
    }

    if (_gazeSectorsHit.length >= gazeCircleSectors) {
      if (_allSectorsCovered) {
        _proceedToNextStep();
      } else {
        _allSectorsCovered = true;
        _emitFeedback(FeedbackId.sectorHit, 'Almost done...',
            param: sector.toString());
      }
    }
  }

  void _processCloseEyes(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;

    if (left != null &&
        right != null &&
        left < _eyeClosedThreshold &&
        right < _eyeClosedThreshold &&
        _eyesClosedCounter > _eyesClosedDuration) {
      _proceedToNextStep();
    } else {
      _emitFeedback(FeedbackId.closeFirmly,
          'Please close both eyes firmly but relaxed');
      _eyesClosedCounter++;
    }
  }

  void _processSmile(Face face) {
    final prob = face.smilingProbability;
    if (prob != null && prob > _smilingThreshold) {
      _proceedToNextStep();
    } else {
      _emitFeedback(FeedbackId.clearSmile, 'Please give a clear smile');
    }
  }

  void _processLookStraight(Face face, Size imageSize) {
    if (imageSize.width < 1 || imageSize.height < 1) return;

    final box = face.boundingBox;
    final cx = (box.left + box.width / 2) / imageSize.width;
    final cy = (box.top + box.height / 2) / imageSize.height;
    final hCentered = (cx - 0.5).abs() < _faceCenterTolerance;
    final vCentered = (cy - 0.5).abs() < _faceCenterTolerance;

    final pitch = face.headEulerAngleX ?? 999;
    final yaw = face.headEulerAngleY ?? 999;
    final roll = face.headEulerAngleZ ?? 999;
    final straight = pitch.abs() < _headStraightThreshold &&
        yaw.abs() < _headStraightThreshold &&
        roll.abs() < _headStraightThreshold;

    final left = face.leftEyeOpenProbability ?? 0;
    final right = face.rightEyeOpenProbability ?? 0;
    final eyesOpen = left > _eyeOpenThreshold && right > _eyeOpenThreshold;

    if (hCentered && vCentered && straight && eyesOpen && _isEnoughTimePassed) {
      _proceedToNextStep();
    } else {
      _emitFeedback(FeedbackId.lookStraight,
          'Look straight ahead with eyes open');
    }
  }

  // ── Step management ──────────────────────────────────────────

  void _proceedToNextStep() {
    _cancelCountdown();

    if (_currentStep == LivenessStep.centerFace) {
      _stepIndex = 0;
      if (_shuffledSteps.isNotEmpty) {
        _currentStep = _shuffledSteps[_stepIndex];
      } else {
        _currentStep = LivenessStep.lookStraight;
      }
    } else if (_currentStep == LivenessStep.lookStraight) {
      _currentStep = LivenessStep.completed;
      onStepChanged?.call(_currentStep);
      _emitFeedback(FeedbackId.completed, 'Verification complete!');
      onCompleted?.call();
      return;
    } else {
      _stepIndex++;
      if (_stepIndex < _shuffledSteps.length) {
        _currentStep = _shuffledSteps[_stepIndex];
      } else {
        _currentStep = LivenessStep.lookStraight;
      }
    }

    // Reset per-step state.
    _isEnoughTimePassed = false;
    _eyesClosedCounter = 0;
    if (_currentStep == LivenessStep.circularGaze) {
      _resetGaze();
    }

    onStepSuccess?.call();
    onStepChanged?.call(_currentStep);
    _emitStepFeedback();
    _startCountdown();
  }

  void _failCheck() {
    _cancelCountdown();
    _resetGaze();
    _currentStep = LivenessStep.failed;
    onStepChanged?.call(_currentStep);
    _emitFeedback(FeedbackId.failedTimeout,
        'Verification timed out. Please try again.');
    onFailed?.call();
  }

  void _resetStepState() {
    _eyesClosedCounter = 0;
    _resetGaze();
    _isEnoughTimePassed = false;
    _countdownSeconds = _stepTimeoutSec;
    _countdownProgress = 1.0;
  }

  void _resetGaze() {
    _gazeSectorsHit.clear();
    _lastGazeSector = -1;
    _candidateGazeSector = -1;
    _consecutiveGazeHits = 0;
    _allSectorsCovered = false;
  }

  // ── Countdown ────────────────────────────────────────────────

  void _startCountdown() {
    _cancelCountdown();

    final timeout = _currentStep == LivenessStep.circularGaze
        ? _stepTimeoutSec * 2
        : _stepTimeoutSec;
    _countdownSeconds = timeout;
    _countdownProgress = 1.0;
    _isEnoughTimePassed = false;

    int elapsed = 0;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      final remaining = timeout - elapsed;

      if (remaining <= timeout - _enoughTimePassedSec) {
        _isEnoughTimePassed = true;
      }

      _countdownSeconds = remaining.clamp(0, timeout);
      _countdownProgress = remaining / timeout;
      onCountdownTick?.call(_countdownSeconds, _countdownProgress);

      if (remaining <= 0) {
        timer.cancel();
        if (_currentStep != LivenessStep.completed &&
            _currentStep != LivenessStep.failed) {
          _failCheck();
        }
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isEnoughTimePassed = false;
  }

  // ── Feedback helpers ─────────────────────────────────────────

  void _emitFeedback(FeedbackId id, String message, {String? param}) {
    onFeedbackChanged?.call(LivenessFeedback(id, message, param: param));
  }

  void _emitStepFeedback() {
    switch (_currentStep) {
      case LivenessStep.centerFace:
        _emitFeedback(FeedbackId.centerFace, 'Center your face in the frame');
      case LivenessStep.rotateHeadLeft:
        _emitFeedback(
            FeedbackId.rotateHeadLeft, 'Slowly turn your head to the left');
      case LivenessStep.rotateHeadRight:
        _emitFeedback(
            FeedbackId.rotateHeadRight, 'Slowly turn your head to the right');
      case LivenessStep.rotateHeadUp:
        _emitFeedback(
            FeedbackId.rotateHeadUp, 'Slowly tilt your head upward');
      case LivenessStep.rotateHeadDown:
        _emitFeedback(
            FeedbackId.rotateHeadDown, 'Slowly tilt your head downward');
      case LivenessStep.circularGaze:
        _emitFeedback(FeedbackId.circularGazeStart,
            'Slowly look from left to right and back');
      case LivenessStep.closeEyes:
        _emitFeedback(FeedbackId.closeEyes, 'Please close both eyes');
      case LivenessStep.smile:
        _emitFeedback(FeedbackId.smile, 'Please smile');
      case LivenessStep.lookStraight:
        _emitFeedback(FeedbackId.lookStraight,
            'Look straight ahead with eyes open');
      default:
        break;
    }
  }
}
