// NEW tests for lib/src/com/com_provider.dart and the pure / constructable
// parts of lib/src/com/nfc_provider.dart. NFC methods that call FlutterNfcKit
// require a platform channel and are not exercised here (see notes in report).

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vcmrtd/src/com/com_provider.dart';
import 'package:vcmrtd/src/com/nfc_provider.dart';

/// Concrete trivial ComProvider to exercise the abstract base constructor.
class _StubComProvider extends ComProvider {
  bool connected = false;
  _StubComProvider() : super(Logger('stub'));
  @override
  Future<void> connect() async => connected = true;
  @override
  Future<void> reconnect() async {}
  @override
  Future<void> disconnect() async => connected = false;
  @override
  bool isConnected() => connected;
  @override
  Future<Uint8List> transceive(Uint8List data) async => data;
}

void main() {
  group('ComProviderError', () {
    test('default message is empty and toString is prefixed', () {
      const e = ComProviderError();
      expect(e.message, '');
      expect(e.toString(), 'ComProviderError: ');
    });

    test('custom message is preserved in toString', () {
      const e = ComProviderError('disconnected');
      expect(e.message, 'disconnected');
      expect(e.toString(), 'ComProviderError: disconnected');
    });
  });

  group('ComProvider abstract base', () {
    test('subclass can be constructed and round-trips transceive', () async {
      final p = _StubComProvider();
      expect(p.isConnected(), isFalse);
      await p.connect();
      expect(p.isConnected(), isTrue);
      expect(await p.transceive(Uint8List.fromList([1, 2, 3])), Uint8List.fromList([1, 2, 3]));
      await p.disconnect();
      expect(p.isConnected(), isFalse);
    });
  });

  group('NfcProvider pure parts', () {
    test('constructor sets default 10s timeout and not connected', () {
      final p = NfcProvider();
      expect(p.timeout, const Duration(seconds: 10));
      expect(p.isConnected(), isFalse);
    });

    test('timeout is mutable', () {
      final p = NfcProvider();
      p.timeout = const Duration(seconds: 30);
      expect(p.timeout, const Duration(seconds: 30));
    });
  });

  group('NfcProviderError', () {
    test('default message and toString prefix', () {
      final e = NfcProviderError();
      expect(e.toString(), 'NfcProviderError: ');
    });

    test('custom message', () {
      final e = NfcProviderError('tag lost');
      expect(e.message, 'tag lost');
      expect(e.toString(), 'NfcProviderError: tag lost');
    });

    test('fromException wraps the exception string', () {
      final e = NfcProviderError.fromException(const FormatException('bad'));
      expect(e.toString(), contains('FormatException'));
      expect(e.toString(), startsWith('NfcProviderError: '));
    });

    test('is a ComProviderError subtype', () {
      expect(NfcProviderError('x'), isA<ComProviderError>());
    });
  });
}
