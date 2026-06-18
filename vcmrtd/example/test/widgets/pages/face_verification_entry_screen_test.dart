import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No camera devices in the test environment: the screen handles this
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

  testWidgets('renders the face alignment screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FaceVerificationEntryScreen(nfcImageBytes: Uint8List(1), onBackPressed: () {})),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);
  });

  testWidgets('forwards nfcImageBytes to the screen', (tester) async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    await tester.pumpWidget(
      MaterialApp(home: FaceVerificationEntryScreen(nfcImageBytes: bytes, onBackPressed: () {})),
    );
    await tester.pump();

    final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
    expect(screen.nfcImageBytes, bytes);
  });
}
