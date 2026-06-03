import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/passive_liveness_service.dart';

void main() {
  group('PassiveLivenessService (debug helpers)', () {
    test('debugAddAntiSpoofScore affects score and pass decision', () {
      final svc = PassiveLivenessService();

      // Add enough samples to reach the minimum sample count.
      svc.debugAddAntiSpoofScore(0.8);
      svc.debugAddAntiSpoofScore(0.9);
      svc.debugAddAntiSpoofScore(0.85);
      svc.debugAddAntiSpoofScore(0.9);

      final avg = svc.getAntiSpoofScore();
      expect(avg, isNotNull);
      expect(avg! > 0.7, isTrue);
      expect(svc.isAntiSpoofPassed(), isTrue);
    });

    test('debugAddBvpSample and debugEvaluateBvp produce RppgResult', () {
      final svc = PassiveLivenessService();

      // Add 15 samples spanning >= 2000ms to satisfy duration and sample count.
      final start = 1000;
      for (var i = 0; i < 15; i++) {
        svc.debugAddBvpSample(0.5 + (i % 3) * 0.01, start + i * 150);
      }

      final r = svc.debugEvaluateBvp();
      expect(r, isNotNull);
      expect(r!.sampleCount, greaterThanOrEqualTo(15));
      // hr may be null if signal is poor; at least duration should be >= 2000ms
      expect(r.durationMs, greaterThanOrEqualTo(2000));
    });
  });
}
