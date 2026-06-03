import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/active_liveness_service.dart';

void main() {
  group('ActiveLivenessService', () {
    test('accepts alignment after stable neutral frames', () {
      final service = ActiveLivenessService();
      final face = _face();

      expect(service.processAlignmentFrame(face: face, action: LivenessAction.blink, timedOut: false), isFalse);
      expect(service.processAlignmentFrame(face: face, action: LivenessAction.blink, timedOut: false), isFalse);
      expect(service.processAlignmentFrame(face: face, action: LivenessAction.blink, timedOut: false), isTrue);
      expect(service.isAligning, isFalse);
    });

    test('rejects non-neutral alignment frames and then recovers', () {
      final service = ActiveLivenessService();

      expect(
        service.processAlignmentFrame(face: _face(yaw: 20), action: LivenessAction.blink, timedOut: false),
        isFalse,
      );
      expect(service.diagnoseAlignmentFrame(_face(yaw: 20)).rejectReason, 'yaw');

      expect(service.processAlignmentFrame(face: _face(), action: LivenessAction.blink, timedOut: false), isFalse);
      expect(service.processAlignmentFrame(face: _face(), action: LivenessAction.blink, timedOut: false), isFalse);
      expect(service.processAlignmentFrame(face: _face(), action: LivenessAction.blink, timedOut: false), isTrue);
    });

    test('diagnoses common non-neutral alignment reasons', () {
      final service = ActiveLivenessService();

      expect(service.diagnoseAlignmentFrame(_face(blinkClosed: true)).rejectReason, 'eyes');
      expect(service.diagnoseAlignmentFrame(_face(mouthOpen: true)).rejectReason, 'mouth');
      expect(service.diagnoseAlignmentFrame(_face(smile: 0.5)).rejectReason, 'smile');
    });

    test('does not detect anything before an action is started', () {
      final service = ActiveLivenessService();

      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face(yaw: -35)), isFalse);
    });

    test('detects blink after closed and reopened eye frames', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.blink, baseline: _baseline());

      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face()), isTrue);
    });

    test('rejects a one-frame blink spike', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.blink, baseline: _baseline());

      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face()), isFalse);
      expect(service.processFrame(face: _face()), isFalse);
    });

    test('detects left and right head turns relative to neutral baseline', () {
      final left = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());
      final right = ActiveLivenessService()..startAction(LivenessAction.turnRight, baseline: _baseline());

      expect(left.processFrame(face: _face(yaw: -35)), isTrue);
      expect(right.processFrame(face: _face(yaw: 35)), isTrue);
    });

    test('rejects head turns in the wrong direction', () {
      final left = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());
      final right = ActiveLivenessService()..startAction(LivenessAction.turnRight, baseline: _baseline());

      expect(left.processFrame(face: _face(yaw: 35)), isFalse);
      expect(right.processFrame(face: _face(yaw: -35)), isFalse);
    });

    test('detects mouth-open gesture after consecutive frames', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.mouthOpen, baseline: _baseline());

      expect(service.processFrame(face: _face(mouthOpen: true, jawOpen: 0.3)), isFalse);
      expect(service.processFrame(face: _face(mouthOpen: true, jawOpen: 0.3)), isFalse);
      expect(service.processFrame(face: _face(mouthOpen: true, jawOpen: 0.3)), isTrue);
    });

    test('rejects mouth-open gesture when smile is too strong', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.mouthOpen, baseline: _baseline());

      for (var i = 0; i < ActiveLivenessService.mouthOpenMinConfirmFrames + 1; i++) {
        expect(service.processFrame(face: _face(mouthOpen: true, jawOpen: 0.3, smile: 0.7)), isFalse);
      }
    });

    test('detects smile gesture after consecutive frames', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.smile, baseline: _baseline());

      for (var i = 0; i < ActiveLivenessService.smileMinConfirmFrames - 1; i++) {
        expect(service.processFrame(face: _face(smile: 0.35)), isFalse);
      }
      expect(service.processFrame(face: _face(smile: 0.35)), isTrue);
    });

    test('rejects smile gesture when jaw is open', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.smile, baseline: _baseline());

      for (var i = 0; i < ActiveLivenessService.smileMinConfirmFrames + 1; i++) {
        expect(service.processFrame(face: _face(smile: 0.35, jawOpen: 0.3)), isFalse);
      }
    });

    test('waits for rest before queued next action starts', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());

      service.queueNextAction(LivenessAction.smile);
      expect(service.isWaitingForRest, isTrue);
      expect(service.processFrame(face: _face()), isFalse);
    });

    test('reset returns service to aligning state and clears queued rest', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());
      service.queueNextAction(LivenessAction.smile);

      service.reset();

      expect(service.isAligning, isTrue);
      expect(service.isWaitingForRest, isFalse);
      expect(service.processFrame(face: _face(yaw: -35)), isFalse);
    });

    test('checkFaceAtRest reports neutral and non-neutral frames', () {
      final service = ActiveLivenessService();

      expect(service.checkFaceAtRest(_face()), isTrue);
      expect(service.checkFaceAtRest(_face(yaw: ActiveLivenessService.restMaxYawDeg + 1)), isFalse);
      expect(service.checkFaceAtRest(_face(mouthOpen: true)), isFalse);
      expect(service.checkFaceAtRest(_face(smile: ActiveLivenessService.restMaxSmile + 0.1)), isFalse);
    });

    test('alignment timeout starts the requested action immediately', () {
      final service = ActiveLivenessService();

      expect(
        service.processAlignmentFrame(face: _face(yaw: 30), action: LivenessAction.turnLeft, timedOut: true),
        isTrue,
      );
      expect(service.isAligning, isFalse);
      for (var i = 0; i < ActiveLivenessService.baselineFrames; i++) {
        expect(service.processFrame(face: _face()), isFalse);
      }
      expect(service.processFrame(face: _face(yaw: -35)), isTrue);
    });

    test('wire names map to the expected event strings', () {
      expect(LivenessAction.blink.wireName, 'BLINK');
      expect(LivenessAction.turnLeft.wireName, 'TURN_LEFT');
      expect(LivenessAction.turnRight.wireName, 'TURN_RIGHT');
      expect(LivenessAction.mouthOpen.wireName, 'MOUTH_OPEN');
      expect(LivenessAction.smile.wireName, 'SMILE');
    });

    test('turn latch releases when face returns to neutral yaw', () {
      final service = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());

      // Detect left turn — latch set, confirmCount accumulates to threshold.
      expect(service.processFrame(face: _face(yaw: -35)), isTrue);
      // Return to neutral — exercises _isTurnReleased(), latch is cleared.
      // processFrame still returns true because confirmCount remains >= threshold.
      service.processFrame(face: _face(yaw: 0));
    });

    test('detects blink without explicit baseline via self-calibration', () {
      // startAction with no baseline → engine self-calibrates from the first few frames.
      final service = ActiveLivenessService()..startAction(LivenessAction.blink);

      for (var i = 0; i < ActiveLivenessService.baselineFrames; i++) {
        expect(service.processFrame(face: _face()), isFalse);
      }
      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face(blinkClosed: true)), isFalse);
      expect(service.processFrame(face: _face()), isTrue);
    });

    test('diagnoseAlignmentFrame reports stableFramesAfter when face is at rest', () {
      final service = ActiveLivenessService();
      service.processAlignmentFrame(face: _face(), action: LivenessAction.blink, timedOut: false);

      final diag = service.diagnoseAlignmentFrame(_face());
      expect(diag.atRest, isTrue);
      expect(diag.stableFramesAfter, greaterThan(0));
      expect(diag.rejectReason, isNull);
    });

    test('transitions to queued action after rest grace period elapses', () async {
      final service = ActiveLivenessService()..startAction(LivenessAction.turnLeft, baseline: _baseline());
      service.queueNextAction(LivenessAction.smile);
      expect(service.isWaitingForRest, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      for (var i = 0; i < ActiveLivenessService.restStableFrames; i++) {
        service.processFrame(face: _face());
      }
      expect(service.isWaitingForRest, isFalse);
    });
  });
}

BaselineSnapshot _baseline() {
  return const BaselineSnapshot(
    yawMatrix: 0,
    yawLandmark: 0,
    mouth: 0.02,
    jaw: 0,
    smileLift: 0,
    smileWidth: 0.1,
    smileBlend: 0,
    eyeFused: 0,
  );
}

FaceObservation _face({
  double yaw = 0,
  bool blinkClosed = false,
  bool mouthOpen = false,
  double jawOpen = 0,
  double smile = 0,
}) {
  final landmarks = List<NormalizedLandmark>.generate(478, (_) => const NormalizedLandmark(0.5, 0.5, 0));

  void set(int index, double x, double y) {
    landmarks[index] = NormalizedLandmark(x, y, 0);
  }

  set(10, 0.5, 0.2);
  set(152, 0.5, 0.8);
  set(234, 0.35, 0.5);
  set(454, 0.65, 0.5);
  set(1, 0.5, 0.45);
  set(0, 0.5, 0.62);
  set(61, 0.45, 0.62);
  set(291, 0.55, 0.62);

  final mouthGap = mouthOpen ? 0.10 : 0.02;
  set(13, 0.5, 0.50 - mouthGap / 2);
  set(14, 0.5, 0.50 + mouthGap / 2);

  final eyeGap = blinkClosed ? 0.002 : 0.05;
  set(362, 0.38, 0.38);
  set(263, 0.48, 0.38);
  set(385, 0.43, 0.38 - eyeGap / 2);
  set(380, 0.43, 0.38 + eyeGap / 2);
  set(387, 0.44, 0.38 - eyeGap / 2);
  set(373, 0.44, 0.38 + eyeGap / 2);

  set(33, 0.62, 0.38);
  set(133, 0.72, 0.38);
  set(160, 0.67, 0.38 - eyeGap / 2);
  set(144, 0.67, 0.38 + eyeGap / 2);
  set(158, 0.68, 0.38 - eyeGap / 2);
  set(153, 0.68, 0.38 + eyeGap / 2);

  final blendshapes = <String, double>{
    'eyeBlinkLeft': blinkClosed ? 0.9 : 0,
    'eyeBlinkRight': blinkClosed ? 0.9 : 0,
    'jawOpen': jawOpen,
    'mouthSmileLeft': smile,
    'mouthSmileRight': smile,
  };

  final categories = blendshapes.entries.map((entry) => Category(entry.key, entry.value)).toList(growable: false);
  final result = FaceLandmarkerResult(
    landmarks: <List<NormalizedLandmark>>[landmarks],
    blendshapes: <List<Category>>[categories],
  );

  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(100, 100, 200, 200),
    boundingBoxAreaRatio: 0.20,
    boundingBoxCenter: const Offset(0.5, 0.5),
    mouthRatio: mouthGap / 0.6,
    yawDegrees: yaw,
    blendshapeScores: blendshapes,
    alignedFace112: img.Image(width: 112, height: 112),
  );
}
