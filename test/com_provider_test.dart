// Test file for ComProvider connection state callbacks
@Tags(['com'])
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/src/com/com_provider.dart';

// Mock ComProvider implementation for testing
class MockComProvider extends ComProvider {
  bool _connected = false;
  int connectCallCount = 0;
  int disconnectCallCount = 0;

  MockComProvider() : super(Logger('mock.com'));

  @override
  Future<void> connect() async {
    connectCallCount++;
    _connected = true;
    notifyConnected();
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    _connected = false;
    notifyDisconnected();
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<Uint8List> transceive(Uint8List data) async {
    if (!_connected) {
      throw ComProviderError("Not connected");
    }
    return data; // Echo back for testing
  }
}

void main() {
  group('ComProvider callbacks', () {
    test('onConnected callback is invoked when connection is established', () async {
      final provider = MockComProvider();
      var callbackInvoked = false;

      provider.onConnected = () {
        callbackInvoked = true;
      };

      await provider.connect();

      expect(callbackInvoked, isTrue);
      expect(provider.isConnected(), isTrue);
    });

    test('onDisconnected callback is invoked when disconnected', () async {
      final provider = MockComProvider();
      var callbackInvoked = false;

      await provider.connect();

      provider.onDisconnected = () {
        callbackInvoked = true;
      };

      await provider.disconnect();

      expect(callbackInvoked, isTrue);
      expect(provider.isConnected(), isFalse);
    });

    test('callbacks can be null without causing errors', () async {
      final provider = MockComProvider();
      provider.onConnected = null;
      provider.onDisconnected = null;

      await provider.connect();
      await provider.disconnect();

      expect(provider.connectCallCount, equals(1));
      expect(provider.disconnectCallCount, equals(1));
    });

    test('multiple callbacks can be set and replaced', () async {
      final provider = MockComProvider();
      var firstCallbackCount = 0;
      var secondCallbackCount = 0;

      provider.onConnected = () {
        firstCallbackCount++;
      };

      await provider.connect();
      expect(firstCallbackCount, equals(1));

      await provider.disconnect();

      // Replace callback
      provider.onConnected = () {
        secondCallbackCount++;
      };

      await provider.connect();
      expect(firstCallbackCount, equals(1)); // Unchanged
      expect(secondCallbackCount, equals(1)); // New callback invoked
    });

    test('callbacks preserve state across multiple connections', () async {
      final provider = MockComProvider();
      var connectionCount = 0;
      var disconnectionCount = 0;

      provider.onConnected = () {
        connectionCount++;
      };

      provider.onDisconnected = () {
        disconnectionCount++;
      };

      // Multiple connect/disconnect cycles
      for (int i = 0; i < 3; i++) {
        await provider.connect();
        await provider.disconnect();
      }

      expect(connectionCount, equals(3));
      expect(disconnectionCount, equals(3));
    });
  });
}
