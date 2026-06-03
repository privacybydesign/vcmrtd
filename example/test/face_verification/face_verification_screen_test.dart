import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';

void main() {
  group('face action presentation helpers', () {
    test('maps action wire names to user-facing labels', () {
      expect(faceActionLabel('BLINK'), 'Blink your eyes');
      expect(faceActionLabel('TURN_LEFT'), 'Turn your head left');
      expect(faceActionLabel('TURN_RIGHT'), 'Turn your head right');
      expect(faceActionLabel('MOUTH_OPEN'), 'Open your mouth and hold');
      expect(faceActionLabel('SMILE'), 'Smile and hold');
      expect(faceActionLabel('UNKNOWN'), 'UNKNOWN');
    });

    test('maps action wire names to icons', () {
      expect(faceActionIcon('BLINK'), Icons.visibility_off);
      expect(faceActionIcon('TURN_LEFT'), Icons.arrow_back);
      expect(faceActionIcon('TURN_RIGHT'), Icons.arrow_forward);
      expect(faceActionIcon('MOUTH_OPEN'), Icons.sentiment_neutral);
      expect(faceActionIcon('SMILE'), Icons.sentiment_satisfied);
      expect(faceActionIcon('UNKNOWN'), Icons.face);
    });
  });

  group('faceMatchThreshold', () {
    test('uses default threshold when issue date is unknown', () {
      expect(faceMatchThreshold(null), 0.60);
    });

    test('is strict for recent document photos', () {
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365))), 0.65);
    });

    test('relaxes threshold for older document photos', () {
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365 * 5))), 0.60);
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365 * 9))), 0.55);
    });
  });

  test('VerificationResult defaults passive detail fields for active mode', () {
    const result = VerificationResult(matchScore: 0.72, isLive: true);

    expect(result.matchScore, 0.72);
    expect(result.isLive, isTrue);
    expect(result.antiSpoofScore, isNull);
    expect(result.antiSpoofPassed, isFalse);
    expect(result.rppgHr, isNull);
    expect(result.rppgPassed, isFalse);
    expect(result.rppgSampleCount, 0);
    expect(result.consistencyFailed, isFalse);
  });
}
