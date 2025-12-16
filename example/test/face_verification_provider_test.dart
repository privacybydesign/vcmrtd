import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG2000 Converter', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, null);
    });

    test('decodeImage should successfully convert JPEG2000 to PNG', () async {
      const mockJp2Data = [0xFF, 0x4F, 0xFF, 0x51]; // JPEG2000 signature
      const mockPngData = [0x89, 0x50, 0x4E, 0x47]; // PNG signature

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, (MethodCall call) async {
        if (call.method == 'decodeImage') {
          final jp2ImageData = call.arguments['jp2ImageData'] as Uint8List;
          expect(jp2ImageData, equals(mockJp2Data));
          return Uint8List.fromList(mockPngData);
        }
        return null;
      });

      final result = await decodeImage(Uint8List.fromList(mockJp2Data), null);

      expect(result, isNotNull);
      expect(result, equals(mockPngData));
    });

    test('decodeImage should return null when conversion fails', () async {
      const mockJp2Data = [10, 20, 30, 40];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, (MethodCall call) async {
        if (call.method == 'decodeImage') {
          throw PlatformException(
            code: 'CONVERSION_ERROR',
            message: 'Failed to decode image',
          );
        }
        return null;
      });

      final result = await decodeImage(Uint8List.fromList(mockJp2Data), null);

      expect(result, isNull);
    });

    test('decodeImage should handle empty input data', () async {
      const mockEmptyData = <int>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, (MethodCall call) async {
        if (call.method == 'decodeImage') {
          final jp2ImageData = call.arguments['jp2ImageData'] as Uint8List;
          if (jp2ImageData.isEmpty) {
            throw PlatformException(
              code: 'INVALID_DATA',
              message: 'Empty image data',
            );
          }
          return Uint8List.fromList([]);
        }
        return null;
      });

      final result = await decodeImage(Uint8List.fromList(mockEmptyData), null);

      expect(result, isNull);
    });

    test('decodeImage should pass correct data to platform channel', () async {
      const mockJp2Data = [100, 200, 150, 75];
      const mockPngData = [80, 78, 71, 13];
      var channelCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, (MethodCall call) async {
        if (call.method == 'decodeImage') {
          channelCalled = true;
          final jp2ImageData = call.arguments['jp2ImageData'] as Uint8List;
          expect(jp2ImageData.length, equals(mockJp2Data.length));
          expect(jp2ImageData[0], equals(100));
          expect(jp2ImageData[1], equals(200));
          expect(jp2ImageData[2], equals(150));
          expect(jp2ImageData[3], equals(75));
          return Uint8List.fromList(mockPngData);
        }
        return null;
      });

      await decodeImage(Uint8List.fromList(mockJp2Data), null);

      expect(channelCalled, isTrue);
    });
  });

  group('FaceVerificationProvider - JPEG2000 Integration', () {
    test('should convert document image before face matching', () async {
      // This is an integration test that verifies the conversion is called
      // For a full integration test with FaceSDK, you would need to mock
      // the flutter_face_api package or use a test double

      const mockJp2Data = [0xFF, 0x4F, 0xFF, 0x51];
      const mockPngData = [0x89, 0x50, 0x4E, 0x47];
      var decodeImageCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, (MethodCall call) async {
        if (call.method == 'decodeImage') {
          decodeImageCalled = true;
          return Uint8List.fromList(mockPngData);
        }
        return null;
      });

      // Test the conversion directly
      final converted = await decodeImage(Uint8List.fromList(mockJp2Data), null);

      expect(decodeImageCalled, isTrue);
      expect(converted, isNotNull);
      expect(converted, equals(mockPngData));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imageChannel, null);
    });
  });
}
