import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/services/proofing_deeplink_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('proofing_deeplink');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('ProofingDeepLinkChannel.getInitialLink', () {
    test('returns the link reported by the native side', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInitialLink');
        return 'vcmrtd://verify?token=tok&api=https://example.com';
      });

      final link = await ProofingDeepLinkChannel.getInitialLink();

      expect(link, 'vcmrtd://verify?token=tok&api=https://example.com');
    });

    test('returns null when the native side has no link', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => null,
      );

      expect(await ProofingDeepLinkChannel.getInitialLink(), isNull);
    });

    test('returns null when the platform channel throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });

      expect(await ProofingDeepLinkChannel.getInitialLink(), isNull);
    });
  });

  group('ProofingDeepLinkChannel.listen', () {
    test('invokes onLink for an onLink call carrying a String', () async {
      String? received;
      ProofingDeepLinkChannel.listen((link) => received = link);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'proofing_deeplink',
        channel.codec.encodeMethodCall(const MethodCall('onLink', 'vcmrtd://verify?token=tok&api=https://a.example')),
        (data) {},
      );

      expect(received, 'vcmrtd://verify?token=tok&api=https://a.example');
    });

    test('ignores a call that is not onLink', () async {
      String? received;
      ProofingDeepLinkChannel.listen((link) => received = link);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'proofing_deeplink',
        channel.codec.encodeMethodCall(const MethodCall('somethingElse', 'ignored')),
        (data) {},
      );

      expect(received, isNull);
    });

    test('ignores an onLink call whose argument is not a String', () async {
      String? received;
      ProofingDeepLinkChannel.listen((link) => received = link);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'proofing_deeplink',
        channel.codec.encodeMethodCall(const MethodCall('onLink', 42)),
        (data) {},
      );

      expect(received, isNull);
    });
  });
}
