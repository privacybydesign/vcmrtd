import 'package:face_verification_iris/face_verification_iris.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('face_verification_iris');
  final verifier = IrisFaceVerifier();
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'version':
          return '1.2.3';
        case 'verify':
          return {'outcome': 'matched', 'face': Uint8List.fromList([1, 2, 3])};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('sdkVersion forwards to the version method call', () async {
    expect(await verifier.sdkVersion, '1.2.3');
    expect(log.single.method, 'version');
  });

  test('verify sends the portrait bytes and parses a matched result', () async {
    final portrait = Uint8List.fromList([9, 9, 9]);

    final result = await verifier.verify(portrait);

    expect(log.single.method, 'verify');
    expect(log.single.arguments, portrait);
    expect(result.outcome, IrisVerificationOutcome.matched);
    expect(result.face, Uint8List.fromList([1, 2, 3]));
  });
}
