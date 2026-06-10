import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(imageChannel, null);
  });

  test('returns decoded bytes when the platform channel succeeds', () async {
    messenger.setMockMethodCallHandler(imageChannel, (call) async {
      expect(call.method, 'decodeImage');
      return Uint8List.fromList([1, 2, 3, 4]);
    });

    final result = await decodeImage(Uint8List.fromList([9, 9]), null);
    expect(result, isNotNull);
    expect(result, [1, 2, 3, 4]);
  });

  test('returns null when the platform channel throws', () async {
    messenger.setMockMethodCallHandler(imageChannel, (call) async {
      throw PlatformException(code: 'ERR');
    });

    final result = await decodeImage(Uint8List.fromList([9, 9]), null);
    expect(result, isNull);
  });

  test('returns null when no handler is registered', () async {
    final result = await decodeImage(Uint8List.fromList([9, 9]), null);
    expect(result, isNull);
  });
}
