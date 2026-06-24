import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/services/face_verification_client.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

// Remote face-verification screen tests. The recognition + liveness run on the
// remote service; these drive the screen through its UI states using the
// test-only constructor and debug hooks (no camera, TFLite runtime, or network).

FlutterFaceVerificationScreenState _state(WidgetTester tester) =>
    tester.state<FlutterFaceVerificationScreenState>(find.byType(FlutterFaceVerificationScreen));

FaceVerificationArgs _verifiableArgs() => FaceVerificationArgs(
  portraitImageBytes: Uint8List.fromList([1, 2, 3]),
  referencePhotoBytes: Uint8List.fromList([4, 5, 6]),
  faceSession: FaceSession(
    faceSessionId: 'fs_test',
    websocketUrl: 'wss://example.test/stream/fs_test',
    bindingKeyReady: true,
  ),
);

Widget _app({VoidCallback? onBack, FaceVerificationArgs? args}) => MaterialApp(
  home: FlutterFaceVerificationScreen.test(args: args ?? _verifiableArgs(), onBackPressed: onBack ?? () {}),
);

FaceVerificationComplete _completion({bool success = true}) => FaceVerificationComplete(
  result: success ? 'success' : 'failed',
  matchConfidence: 0.92,
  livenessPassed: success,
  framesProcessed: 7,
  verificationDurationMs: 2500,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // _retry() reopens the camera; no devices in the test environment.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async => call.method == 'availableCameras' ? <dynamic>[] : null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      null,
    );
  });

  testWidgets('starts on the idle screen once models are ready', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(); // post-frame callback marks models ready

    expect(_state(tester).debugState, VerifyState.idle);
    expect(find.text('Verify my face'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
  });

  testWidgets('shows the unavailable screen when no session is present', (tester) async {
    await tester.pumpWidget(_app(args: const FaceVerificationArgs()));
    await tester.pump();

    expect(find.text('Face verification is not available'), findsOneWidget);
    expect(find.text('Verify my face'), findsNothing);
  });

  testWidgets('result screen shows a successful verification', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(_completion(success: true));
    await tester.pump();

    expect(_state(tester).debugState, VerifyState.result);
    expect(find.text('Face verified'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
  });

  testWidgets('result screen shows a failed verification', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(_completion(success: false));
    await tester.pump();

    expect(find.text('Verification failed'), findsOneWidget);
  });

  testWidgets('Try Again returns to the idle state', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(_completion());
    await tester.pump();
    expect(_state(tester).debugState, VerifyState.result);

    await tester.tap(find.text('Try Again'));
    // pump (not pumpAndSettle): the idle camera-preview placeholder spins forever.
    await tester.pump();
    await tester.pump();

    expect(_state(tester).debugState, VerifyState.idle);
  });

  testWidgets('back button invokes the onBackPressed callback', (tester) async {
    var backCalled = false;
    await tester.pumpWidget(_app(onBack: () => backCalled = true));
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump();

    expect(backCalled, isTrue);
  });
}
