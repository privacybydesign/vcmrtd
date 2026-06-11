import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';
import 'package:vcmrtdapp/widgets/displays/passport_image_widget.dart';

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(imageChannel, null);
  });

  group('PassportImageWidget', () {
    testWidgets('null image data renders no-data message', (tester) async {
      await tester.pumpWidget(_wrap(const PassportImageWidget(header: 'h', imageData: null, imageType: null)));
      await tester.pump();
      expect(find.text('No image data available.'), findsOneWidget);
    });

    testWidgets('empty image data renders no-data message', (tester) async {
      await tester.pumpWidget(
        _wrap(PassportImageWidget(header: 'h', imageData: Uint8List(0), imageType: ImageType.jpeg)),
      );
      await tester.pump();
      expect(find.text('No image data available.'), findsOneWidget);
    });

    testWidgets('jpeg image data renders an Image widget', (tester) async {
      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: _jpeg(), imageType: ImageType.jpeg)));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('unknown image type renders unsupported message', (tester) async {
      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: _jpeg(), imageType: null)));
      await tester.pump();
      expect(find.text('Unknown or unsupported image type.'), findsOneWidget);
    });

    testWidgets('jpeg2000 conversion failure falls back to failed-conversion message', (tester) async {
      // Channel throws -> convertJp2 returns null -> failed message.
      messenger.setMockMethodCallHandler(imageChannel, (call) async {
        throw PlatformException(code: 'ERR');
      });

      // Use unique bytes so the static conversion cache from other tests is not hit.
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: bytes, imageType: ImageType.jpeg2000)));
      // Let the conversion future complete (returns null on failure).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Failed to convert JPEG2000 image.'), findsOneWidget);
    });

    testWidgets('jpeg2000 successful conversion renders the converted Image', (tester) async {
      final converted = _jpeg();
      messenger.setMockMethodCallHandler(imageChannel, (call) async => converted);

      final bytes = Uint8List.fromList([9, 8, 7, 6, 5]);
      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: bytes, imageType: ImageType.jpeg2000)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('updating from jpeg to unknown type updates rendered branch', (tester) async {
      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: _jpeg(), imageType: ImageType.jpeg)));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(_wrap(PassportImageWidget(header: 'h', imageData: _jpeg(), imageType: null)));
      await tester.pump();
      expect(find.text('Unknown or unsupported image type.'), findsOneWidget);
    });
  });
}
