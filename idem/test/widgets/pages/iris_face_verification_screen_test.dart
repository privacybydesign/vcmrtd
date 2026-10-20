import 'dart:async';
import 'package:idem/l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/widgets/pages/iris_face_verification_screen.dart';

Uint8List _fakePortraitPng() {
  final image = img.Image(width: 2, height: 2);
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _startVerification(WidgetTester tester) async {
  expect(find.text('Start selfie check'), findsOneWidget);
  await tester.tap(find.text('Start selfie check'));
  await tester.pump();
}

void main() {
  const channel = MethodChannel('iris_sdk_flutter');
  const imageChannel = MethodChannel('image_channel');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(imageChannel, null);
  });

  testWidgets('shows an intro screen before the native flow starts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();

    expect(find.text('Start selfie check'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a spinner while the native flow is running', (tester) async {
    final completer = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) => completer.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();
    await _startVerification(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete({'outcome': 'failed', 'face': null});
    await tester.pumpAndSettle();
  });

  testWidgets('a match continues straight away under a spinner, no result screen', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return {'outcome': 'matched', 'face': _fakePortraitPng()};
    });
    var backCount = 0;
    var verifiedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(
          nfcImageBytes: _fakePortraitPng(),
          onBackPressed: () => backCount++,
          onVerified: (_) => verifiedCount++,
        ),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pump();
    await tester.pump();

    expect(verifiedCount, 1);
    expect(backCount, 0);
    expect(find.text('Continuing…'), findsOneWidget);
    expect(find.text('Live capture'), findsNothing);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('renders a failure result when the SDK reports no match', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return {'outcome': 'failed', 'face': null};
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pumpAndSettle();

    expect(find.text('Verification Failed'), findsOneWidget);
    expect(find.text('Document photo'), findsOneWidget);
    expect(find.text('Live capture'), findsNothing);
  });

  testWidgets('renders a cancelled result when the user cancels the SDK flow', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return {'outcome': 'cancelled', 'face': null};
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('renders a friendly message when the Iris SDK plugin is missing', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pumpAndSettle();

    expect(find.text('Something Went Wrong'), findsOneWidget);
    expect(find.textContaining('not available on this device'), findsOneWidget);
  });

  testWidgets('renders an error result when the portrait cannot be decoded', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      imageChannel,
      (call) async => null,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(
          nfcImageBytes: Uint8List.fromList([1, 2, 3]),
          onBackPressed: () {},
          onVerified: (_) {},
        ),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pumpAndSettle();

    expect(find.text('Something Went Wrong'), findsOneWidget);
    expect(find.textContaining('reference portrait'), findsOneWidget);
  });

  testWidgets('falls back to the native JP2 decoder when the portrait is not a Dart-decodable format', (tester) async {
    final pngBytes = _fakePortraitPng();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(imageChannel, (
      call,
    ) async {
      expect(call.method, 'decodeImage');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['jp2ImageData'], orderedEquals([1, 2, 3]));
      return pngBytes;
    });
    Uint8List? verifiedPortrait;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      verifiedPortrait = call.arguments as Uint8List;
      return {'outcome': 'matched', 'face': pngBytes};
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(
          nfcImageBytes: Uint8List.fromList([1, 2, 3]),
          onBackPressed: () {},
          onVerified: (_) {},
        ),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Continuing…'), findsOneWidget);
    expect(verifiedPortrait, isNotNull);
  });

  testWidgets('Try Again re-runs the verification', (tester) async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      callCount++;
      return {'outcome': 'failed', 'face': null};
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IrisFaceVerificationScreen(nfcImageBytes: _fakePortraitPng(), onBackPressed: () {}, onVerified: (_) {}),
      ),
    );
    await tester.pump();
    await _startVerification(tester);
    await tester.pumpAndSettle();
    expect(callCount, 1);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(callCount, 2);
  });
}
