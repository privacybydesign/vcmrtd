import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';

void main() {
  test('faceActionLabel maps known actions', () {
    expect(faceActionLabel('BLINK'), 'Blink your eyes');
    expect(faceActionLabel('TURN_LEFT'), 'Turn your head left');
    expect(faceActionLabel('TURN_RIGHT'), 'Turn your head right');
    expect(faceActionLabel('MOUTH_OPEN'), 'Open your mouth and hold');
    expect(faceActionLabel('SMILE'), 'Smile and hold');
  });

  test('faceActionLabel returns input for unknown actions', () {
    expect(faceActionLabel('FOO_BAR'), 'FOO_BAR');
  });

  test('faceActionIcon maps known actions to sensible icons', () {
    expect(faceActionIcon('BLINK'), Icons.visibility_off);
    expect(faceActionIcon('TURN_LEFT'), Icons.arrow_back);
    expect(faceActionIcon('TURN_RIGHT'), Icons.arrow_forward);
    expect(faceActionIcon('MOUTH_OPEN'), Icons.sentiment_neutral);
    expect(faceActionIcon('SMILE'), Icons.sentiment_satisfied);
  });

  test('faceMatchThreshold returns expected thresholds by photo age', () {
    final now = DateTime.now();
    // No date -> default 0.60
    expect(faceMatchThreshold(null), 0.60);

    // Recent photo (1 year ago) -> 0.65
    final oneYear = now.subtract(const Duration(days: 365));
    expect(faceMatchThreshold(oneYear), closeTo(0.65, 1e-9));

    // 5 years ago -> 0.60
    final fiveYears = now.subtract(const Duration(days: 365 * 5));
    expect(faceMatchThreshold(fiveYears), closeTo(0.60, 1e-9));

    // 10 years ago -> 0.55
    final tenYears = now.subtract(const Duration(days: 365 * 10));
    expect(faceMatchThreshold(tenYears), closeTo(0.55, 1e-9));
  });

  test('VerificationResult holds provided values', () {
    final r = VerificationResult(
      matchScore: 0.72,
      isLive: true,
      antiSpoofScore: 0.8,
      antiSpoofPassed: true,
      rppgHr: 60.0,
      rppgPassed: true,
      rppgSampleCount: 30,
      consistencyFailed: false,
    );

    expect(r.matchScore, 0.72);
    expect(r.isLive, isTrue);
    expect(r.antiSpoofScore, closeTo(0.8, 1e-9));
    expect(r.antiSpoofPassed, isTrue);
    expect(r.rppgHr, closeTo(60.0, 1e-9));
    expect(r.rppgPassed, isTrue);
    expect(r.rppgSampleCount, 30);
    expect(r.consistencyFailed, isFalse);
  });
}
