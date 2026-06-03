import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';

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

    test('keeps debug event emission disabled by default', () {
      expect(FaceVerificationTuning.emitDebugEvents, isFalse);
    });
  });
}
