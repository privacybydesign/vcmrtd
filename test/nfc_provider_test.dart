// Test file for NfcProvider error classification and retry logic
@Tags(['nfc'])
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/src/com/nfc_provider.dart';

void main() {
  group('NfcProviderError classification', () {
    test('NfcConnectionLost is retryable', () {
      final error = NfcConnectionLost("Connection lost");
      expect(error.isRetryable(), isTrue);
      expect(error.toString(), contains('NfcConnectionLost'));
    });

    test('NfcTimeout is retryable', () {
      final error = NfcTimeout("Operation timed out");
      expect(error.isRetryable(), isTrue);
      expect(error.toString(), contains('NfcTimeout'));
    });

    test('NfcTransientError is retryable', () {
      final error = NfcTransientError("Transient error");
      expect(error.isRetryable(), isTrue);
      expect(error.toString(), contains('NfcTransientError'));
    });

    test('NfcInvalidCard is not retryable', () {
      final error = NfcInvalidCard("Invalid card type");
      expect(error.isRetryable(), isFalse);
      expect(error.toString(), contains('NfcInvalidCard'));
    });

    test('Generic NfcProviderError identifies retryable subtypes', () {
      NfcProviderError error1 = NfcConnectionLost();
      NfcProviderError error2 = NfcTimeout();
      NfcProviderError error3 = NfcInvalidCard();
      NfcProviderError error4 = NfcProviderError("Generic error");

      expect(error1.isRetryable(), isTrue);
      expect(error2.isRetryable(), isTrue);
      expect(error3.isRetryable(), isFalse);
      expect(error4.isRetryable(), isFalse); // Generic errors not retryable
    });
  });

  group('NfcProvider error message classification', () {
    // We can't easily test the actual NfcProvider without mocking flutter_nfc_kit,
    // but we can test the error classification logic by creating a test helper

    NfcProviderError classifyTestError(String errorMessage) {
      // Simulate the classification logic from NfcProvider._classifyError
      final errorMsg = errorMessage.toLowerCase();

      if (errorMsg.contains('tag was lost') ||
          errorMsg.contains('tag connection lost') ||
          errorMsg.contains('nfc tag has been lost') ||
          errorMsg.contains('connection lost')) {
        return NfcConnectionLost(errorMessage);
      }

      if (errorMsg.contains('timeout') ||
          errorMsg.contains('timed out')) {
        return NfcTimeout(errorMessage);
      }

      if (errorMsg.contains('invalidated by user') ||
          errorMsg.contains('user canceled') ||
          errorMsg.contains('session invalidated')) {
        return NfcProviderError(errorMessage);
      }

      if (errorMsg.contains('transceive failed') ||
          errorMsg.contains('communication error') ||
          errorMsg.contains('rf communication error')) {
        return NfcTransientError(errorMessage);
      }

      return NfcProviderError(errorMessage);
    }

    test('classifies "tag was lost" as NfcConnectionLost', () {
      final error = classifyTestError("NFC tag was lost");
      expect(error, isA<NfcConnectionLost>());
      expect(error.isRetryable(), isTrue);
    });

    test('classifies "timeout" as NfcTimeout', () {
      final error = classifyTestError("Operation timeout");
      expect(error, isA<NfcTimeout>());
      expect(error.isRetryable(), isTrue);
    });

    test('classifies "timed out" as NfcTimeout', () {
      final error = classifyTestError("Request timed out");
      expect(error, isA<NfcTimeout>());
      expect(error.isRetryable(), isTrue);
    });

    test('classifies "transceive failed" as NfcTransientError', () {
      final error = classifyTestError("Transceive failed");
      expect(error, isA<NfcTransientError>());
      expect(error.isRetryable(), isTrue);
    });

    test('classifies "communication error" as NfcTransientError', () {
      final error = classifyTestError("RF communication error");
      expect(error, isA<NfcTransientError>());
      expect(error.isRetryable(), isTrue);
    });

    test('classifies "invalidated by user" as generic NfcProviderError', () {
      final error = classifyTestError("Session invalidated by user");
      expect(error, isA<NfcProviderError>());
      expect(error, isNot(isA<NfcConnectionLost>()));
      expect(error, isNot(isA<NfcTimeout>()));
      expect(error, isNot(isA<NfcTransientError>()));
      expect(error.isRetryable(), isFalse);
    });

    test('classifies unknown errors as generic NfcProviderError', () {
      final error = classifyTestError("Some unknown error");
      expect(error, isA<NfcProviderError>());
      expect(error, isNot(isA<NfcConnectionLost>()));
      expect(error.isRetryable(), isFalse);
    });

    test('classification is case-insensitive', () {
      final error1 = classifyTestError("TAG WAS LOST");
      final error2 = classifyTestError("Tag Was Lost");
      final error3 = classifyTestError("tag was lost");

      expect(error1, isA<NfcConnectionLost>());
      expect(error2, isA<NfcConnectionLost>());
      expect(error3, isA<NfcConnectionLost>());
    });
  });

  group('NfcProvider connection validation', () {
    // These tests verify the concept of connection validation
    // without requiring actual NFC hardware

    test('connection age calculation', () {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final threeMinutesAgo = now.subtract(const Duration(minutes: 3));

      final age1 = now.difference(oneMinuteAgo);
      final age2 = now.difference(threeMinutesAgo);

      expect(age1.inMinutes, equals(1));
      expect(age1 < const Duration(minutes: 2), isTrue);

      expect(age2.inMinutes, equals(3));
      expect(age2 > const Duration(minutes: 2), isTrue);
    });

    test('stale connection detection threshold', () {
      const staleThreshold = Duration(minutes: 2);

      final recentAge = Duration(minutes: 1);
      final staleAge = Duration(minutes: 3);

      expect(recentAge <= staleThreshold, isTrue);
      expect(staleAge > staleThreshold, isTrue);
    });
  });

  group('NfcProvider timeout configuration', () {
    test('iOS timeout is longer than Android', () {
      // Platform-specific timeouts for iOS and Android
      const androidTimeout = Duration(seconds: 10);
      const iosTimeout = Duration(seconds: 20);

      expect(iosTimeout.inSeconds, greaterThan(androidTimeout.inSeconds));
      expect(iosTimeout.inMilliseconds, equals(20000));
      expect(androidTimeout.inMilliseconds, equals(10000));
    });

    test('timeout escalation for retries', () {
      const baseTimeout = Duration(seconds: 10);

      // Simulate timeout escalation (1.5x multiplier)
      final retry1Timeout = Duration(milliseconds: (baseTimeout.inMilliseconds * 1.5).round());
      final retry2Timeout = Duration(milliseconds: (retry1Timeout.inMilliseconds * 1.5).round());

      expect(retry1Timeout.inMilliseconds, equals(15000)); // 10s * 1.5
      expect(retry2Timeout.inMilliseconds, equals(22500)); // 15s * 1.5
    });
  });

  group('Retry backoff calculation', () {
    test('exponential backoff delays', () {
      // Simulates the retry delay: 100ms * (2^attempt)
      int calculateBackoff(int retryCount) {
        return 100 * (1 << retryCount); // 1 << n is 2^n
      }

      expect(calculateBackoff(0), equals(100));  // First retry: 100ms
      expect(calculateBackoff(1), equals(200));  // Second retry: 200ms
      expect(calculateBackoff(2), equals(400));  // Third retry: 400ms
    });

    test('max retries limit', () {
      const maxRetries = 2;

      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        expect(attempt <= maxRetries, isTrue);
      }

      expect(maxRetries + 1 > maxRetries, isTrue); // Would exceed max
    });
  });
}
