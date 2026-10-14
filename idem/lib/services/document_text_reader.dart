import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idem/services/document_photo_quality.dart';

const _neutralChroma = 128;

/// Tells, with ML Kit's text recognition, whether a camera frame's document is readable.
class DocumentTextReader {
  TextRecognizer? _recognizer;

  /// [rotation] turns the frame upright (clockwise degrees); [region] is in
  /// fractions of the upright frame.
  Future<bool> readable(CameraImage image, {required int rotation, required Rect region}) async {
    final text = await (_recognizer ??= TextRecognizer()).processImage(_input(image, rotation));
    final boxes = [
      for (final block in text.blocks)
        for (final line in block.lines) line.boundingBox,
    ];

    return textReadable(
      fractionsOfUpright(boxes, width: image.width, height: image.height, rotation: rotation),
      region,
    );
  }

  Future<void> close() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }

  static InputImage _input(CameraImage image, int rotation) {
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: Platform.isAndroid
          ? nv21FromLuma(plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow)
          : plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: Platform.isAndroid ? image.width : plane.bytesPerRow,
      ),
    );
  }
}

/// [boxes] in pixels of the upright frame, as fractions of it; [width] and
/// [height] are the frame's before [rotation].
@visibleForTesting
List<Rect> fractionsOfUpright(Iterable<Rect> boxes, {required int width, required int height, required int rotation}) {
  final sideways = rotation % 180 != 0;
  final uprightWidth = (sideways ? height : width).toDouble();
  final uprightHeight = (sideways ? width : height).toDouble();
  return [
    for (final box in boxes)
      Rect.fromLTRB(
        box.left / uprightWidth,
        box.top / uprightHeight,
        box.right / uprightWidth,
        box.bottom / uprightHeight,
      ),
  ];
}

/// The luma plane plus neutral chroma makes NV21, without the plane's row padding.
@visibleForTesting
Uint8List nv21FromLuma(Uint8List luma, {required int width, required int height, required int bytesPerRow}) {
  final lumaSize = width * height;
  final bytes = Uint8List(lumaSize + lumaSize ~/ 2)..fillRange(lumaSize, lumaSize + lumaSize ~/ 2, _neutralChroma);
  for (var row = 0; row < height; row++) {
    bytes.setRange(row * width, (row + 1) * width, luma, row * bytesPerRow);
  }
  return bytes;
}
