import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

// Face-alignment-only screen tests. The verification/liveness engine has been
// removed, so these drive the screen through its UI states using the
// test-only constructor and debug hooks (no camera or TFLite runtime needed).

Uint8List _png() => Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

FlutterFaceVerificationScreenState _state(WidgetTester tester) =>
    tester.state<FlutterFaceVerificationScreenState>(find.byType(FlutterFaceVerificationScreen));

Widget _app({VoidCallback? onBack}) => MaterialApp(
  home: FlutterFaceVerificationScreen.test(nfcImageBytes: Uint8List(1), onBackPressed: onBack ?? () {}),
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

    expect(_state(tester).debugState, AlignmentState.idle);
    expect(find.text('Align my face'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
  });

  testWidgets('result screen shows both aligned faces', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(selfiePng: _png(), nfcPng: _png());
    await tester.pump();

    expect(_state(tester).debugState, AlignmentState.result);
    expect(find.text('Aligned faces'), findsOneWidget);
    expect(find.text('Document (NFC)'), findsOneWidget);
    expect(find.text('Selfie'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('result screen shows a placeholder when a face is missing', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(selfiePng: _png(), nfcPng: null);
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No face found'), findsOneWidget);
  });

  testWidgets('Try Again returns to the idle state', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _state(tester).debugShowResult(selfiePng: _png(), nfcPng: _png());
    await tester.pump();
    expect(_state(tester).debugState, AlignmentState.result);

    await tester.tap(find.text('Try Again'));
    // pump (not pumpAndSettle): the idle camera-preview placeholder spins forever.
    await tester.pump();
    await tester.pump();

    expect(_state(tester).debugState, AlignmentState.idle);
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
