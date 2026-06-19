import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/on_device_face_verification_screen.dart';

FaceVerificationArgs _remoteCapableArgs() => FaceVerificationArgs(
  portraitImageBytes: Uint8List.fromList(<int>[1, 2, 3]),
  referencePhotoBytes: Uint8List.fromList(<int>[4, 5, 6]),
  faceSession: FaceSession(
    faceSessionId: 'fs_1',
    websocketUrl: 'wss://test.local/stream/fs_1',
    bindingKeyReady: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No camera devices in the test environment: the screens handle this
    // gracefully instead of throwing during bootstrap.
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

  testWidgets('renders the method chooser with both options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FaceVerificationEntryScreen(
          args: FaceVerificationArgs(portraitImageBytes: Uint8List(1)),
          onBackPressed: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('On-device (open source)'), findsOneWidget);
    expect(find.text('Remote (face service)'), findsOneWidget);
    // Neither verification screen is shown until a method is chosen.
    expect(find.byType(FlutterFaceVerificationScreen), findsNothing);
    expect(find.byType(OnDeviceFaceVerificationScreen), findsNothing);
  });

  testWidgets('selecting remote shows the remote screen and forwards args', (tester) async {
    final args = _remoteCapableArgs();
    await tester.pumpWidget(
      MaterialApp(home: FaceVerificationEntryScreen(args: args, onBackPressed: () {})),
    );
    await tester.pump();

    await tester.tap(find.text('Remote (face service)'));
    await tester.pump();

    final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
    expect(screen.args, same(args));
  });

  // Note: selecting on-device mounts OnDeviceFaceVerificationScreen, whose
  // initState boots the TFLite engine — not runnable in the headless test VM.
  // The on-device screen needs its own mock-engine harness (as the pre-removal
  // screen had); the selector wiring is covered by the cases above.
}
