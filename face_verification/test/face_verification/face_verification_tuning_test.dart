import 'package:flutter_test/flutter_test.dart';
import 'package:face_verification/src/face_verification/face_verification_tuning.dart';

void main() {
  group('FaceVerificationTuning', () {
    test('uses expected active liveness defaults', () {
      expect(FaceVerificationTuning.requiredActions, 3);
      expect(FaceVerificationTuning.actionsNeededToPass, 2);
      expect(FaceVerificationTuning.actionTimeoutFrames, 240);
    });

    test('uses expected passive and anti-spoof defaults', () {
      expect(FaceVerificationTuning.antiSpoofSampleRate, 0.70);
      expect(FaceVerificationTuning.antiSpoofMaxYawDeg, 20.0);
      expect(FaceVerificationTuning.antiSpoofMinScore, 0.65);
      expect(FaceVerificationTuning.passiveTargetMs, 5000);
      expect(FaceVerificationTuning.passiveLockOnMs, 600);
    });

    test('uses expected gesture detection and alignment defaults', () {
      expect(FaceVerificationTuning.antiSpoofMinSamples, 4);
      expect(FaceVerificationTuning.turnYawThreshold, 28.0);
      expect(FaceVerificationTuning.mouthOpenThreshold, 0.028);
      expect(FaceVerificationTuning.alignMinBboxArea, 0.04);
      expect(FaceVerificationTuning.alignMaxBboxArea, 0.45);
      expect(FaceVerificationTuning.passiveMaxYawDeg, 22.0);
      expect(FaceVerificationTuning.passiveCenterMaxOffsetX, 0.18);
      expect(FaceVerificationTuning.passiveCenterMaxOffsetY, 0.22);
      expect(FaceVerificationTuning.consistencyCheckThreshold, 0.50);
      expect(FaceVerificationTuning.consistencyMaxSmile, 0.15);
    });

    test('keeps debug event emission disabled by default', () {
      expect(FaceVerificationTuning.emitDebugEvents, isFalse);
    });
  });
}
