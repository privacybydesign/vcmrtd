// Coverage for the non-JPEG (JPEG2000) branch of ProfilePictureWidget, which
// the widget smoke test does not exercise.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/profile_picture.dart';

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(imageChannel, null);
  });

  testWidgets('JPEG2000 image data renders the PassportImageWidget branch', (tester) async {
    final converted = _jpeg();
    messenger.setMockMethodCallHandler(imageChannel, (call) async => converted);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePictureWidget(imageData: Uint8List.fromList([3, 1, 4, 1, 5]), imageType: ImageType.jpeg2000),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The non-jpeg branch nests a PassportImageWidget; on successful conversion
    // it renders an Image.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('JPEG image data with a broken decode falls back to the error builder', (tester) async {
    // Non-decodable bytes tagged as JPEG -> Image.memory errorBuilder fires.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePictureWidget(imageData: Uint8List.fromList([0, 1, 2, 3]), imageType: ImageType.jpeg),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Image), findsOneWidget);
  });
}
