// Test file for ICC connection validation
@Tags(['icc'])
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/proto/iso7816/icc.dart';

// Mock ComProvider for testing ICC
class MockComProviderForICC extends ComProvider {
  bool _connected = false;
  bool shouldThrowOnTransceive = false;
  int transceiveCallCount = 0;

  MockComProviderForICC() : super(Logger('mock.com.icc'));

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(Uint8List data) async {
    transceiveCallCount++;

    if (!_connected) {
      throw ComProviderError("Not connected");
    }

    if (shouldThrowOnTransceive) {
      throw ComProviderError("Transceive failed");
    }

    // Return a mock success response with 8 bytes of challenge data + SW: 9000
    // This simulates a proper APDU response for GET CHALLENGE
    return Uint8List.fromList([
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, // 8 bytes challenge
      0x90, 0x00 // Status word success
    ]);
  }
}

void main() {
  group('ICC connection validation', () {
    test('transceive throws error when not connected', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      // Attempt to transceive without connecting
      expect(
        () async => await icc.getChallenge(challengeLength: 8),
        throwsA(isA<ComProviderError>()),
      );
    });

    test('transceive succeeds when connected', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      await mockCom.connect();
      expect(mockCom.isConnected(), isTrue);

      // This should succeed with our mock response
      final challenge = await icc.getChallenge(challengeLength: 8);

      // Verify we got the challenge data
      expect(challenge.length, equals(8));
      expect(mockCom.transceiveCallCount, equals(1));
    });

    test('connection check happens before transceive', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      // Not connected
      expect(mockCom.isConnected(), isFalse);

      try {
        await icc.getChallenge(challengeLength: 8);
        fail('Should have thrown ComProviderError');
      } on ComProviderError catch (e) {
        expect(e.message, contains("not connected"));
        // Transceive should not have been called
        expect(mockCom.transceiveCallCount, equals(0));
      }
    });

    test('connection error during transceive is properly propagated', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      await mockCom.connect();
      mockCom.shouldThrowOnTransceive = true;

      try {
        await icc.getChallenge(challengeLength: 8);
        fail('Should have thrown ComProviderError');
      } on ComProviderError catch (e) {
        expect(e.message, contains("Transceive failed"));
        expect(mockCom.transceiveCallCount, equals(1));
      }
    });

    test('multiple operations check connection each time', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      await mockCom.connect();

      // First operation - should succeed (connection check passes)
      try {
        await icc.getChallenge(challengeLength: 8);
      } catch (e) {
        // Ignore mock response errors
      }

      expect(mockCom.transceiveCallCount, equals(1));

      // Disconnect
      await mockCom.disconnect();

      // Second operation - should fail at connection check
      try {
        await icc.getChallenge(challengeLength: 8);
        fail('Should have thrown ComProviderError');
      } on ComProviderError catch (e) {
        expect(e.message, contains("not connected"));
        // Transceive count should not increase
        expect(mockCom.transceiveCallCount, equals(1));
      }
    });
  });

  group('ICC error handling', () {
    test('ComProviderError is logged and rethrown', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      await mockCom.connect();
      mockCom.shouldThrowOnTransceive = true;

      expect(
        () async => await icc.getChallenge(challengeLength: 8),
        throwsA(isA<ComProviderError>()),
      );
    });

    test('connection state is checked before each ICC operation', () async {
      final mockCom = MockComProviderForICC();
      final icc = ICC(mockCom);

      // Verify multiple ICC operations check connection
      final operations = [
        () async => icc.getChallenge(challengeLength: 8),
        () async => icc.externalAuthenticate(data: Uint8List(8), ne: 8),
      ];

      for (final operation in operations) {
        try {
          await operation();
          fail('Should have thrown ComProviderError');
        } on ComProviderError catch (e) {
          expect(e.message, contains("not connected"));
        }
      }

      // No transceive should have been called
      expect(mockCom.transceiveCallCount, equals(0));
    });
  });
}
