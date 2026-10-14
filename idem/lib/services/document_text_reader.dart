import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idem/services/document_photo_quality.dart';

/// Tells, with ML Kit's text recognition, whether a camera frame's document is readable.
class DocumentTextReader {
  static const _neutralChroma = 128;

  TextRecognizer? _recognizer;

  /// [rotation] turns the frame upright (clockwise degrees); [region] is in
  /// fractions of the upright frame.
  Future<bool> readable(CameraImage image, {required int rotation, required Rect region}) async {
    final sideways = rotation % 180 != 0;
    final uprightWidth = (sideways ? image.height : image.width).toDouble();
    final uprightHeight = (sideways ? image.width : image.height).toDouble();

    final text = await (_recognizer ??= TextRecognizer()).processImage(_input(image, rotation));
    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines)
          Rect.fromLTRB(
            line.boundingBox.left / uprightWidth,
            line.boundingBox.top / uprightHeight,
            line.boundingBox.right / uprightWidth,
            line.boundingBox.bottom / uprightHeight,
          ),
    ];

    return textReadable(lines, region);
  }

  Future<void> close() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }

  /// On Android, the luma plane plus neutral chroma makes NV21.
  static InputImage _input(CameraImage image, int rotation) {
    final plane = image.planes.first;
    final Uint8List bytes;
    if (Platform.isAndroid) {
      final lumaSize = image.width * image.height;
      bytes = Uint8List(lumaSize + lumaSize ~/ 2)..fillRange(lumaSize, lumaSize + lumaSize ~/ 2, _neutralChroma);
      for (var row = 0; row < image.height; row++) {
        bytes.setRange(row * image.width, (row + 1) * image.width, plane.bytes, row * plane.bytesPerRow);
      }
    } else {
      bytes = plane.bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: Platform.isAndroid ? image.width : plane.bytesPerRow,
      ),
    );
  }
}
