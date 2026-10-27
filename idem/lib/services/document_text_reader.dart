import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idem/services/document_photo_quality.dart';

const _neutralChroma = 128;
const _photoDirPrefix = 'document_photo';

/// Finds, with ML Kit's text recognition, where a camera frame's lines of
/// text are, and what a photo's say.
class DocumentTextReader {
  /// Photos an earlier run left behind when it was killed mid-read, deleted
  /// once, from the app's start.
  static Future<void>? _staleSwept;

  TextRecognizer? _recognizer;
  var _closed = false;

  /// Deletes the photos an earlier run left behind; the first photo of this
  /// run is written once they're gone.
  static Future<void> sweepStalePhotos() => _staleSwept ??= deleteStalePhotos(Directory.systemTemp);

  /// The lines of text in the frame, in fractions of the upright frame;
  /// [rotation] turns the frame upright (clockwise degrees).
  Future<List<Rect>> lines(LumaFrame frame, {required int rotation}) async {
    final text = await _openRecognizer.processImage(_input(frame, rotation));
    final boxes = [
      for (final block in text.blocks)
        for (final line in block.lines) line.boundingBox,
    ];

    return fractionsOfUpright(boxes, width: frame.width, height: frame.height, rotation: rotation);
  }

  /// The lines of text on a photo the step took (a JPEG), block by block.
  Future<List<String>> photoText(Uint8List jpeg) async {
    // ML Kit reads an encoded image only from a file.
    await sweepStalePhotos();
    final dir = await Directory.systemTemp.createTemp(_photoDirPrefix);
    try {
      final file = File('${dir.path}/photo.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      final text = await _openRecognizer.processImage(InputImage.fromFilePath(file.path));
      return [
        for (final block in text.blocks)
          for (final line in block.lines) line.text,
      ];
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<void> close() async {
    _closed = true;
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }

  /// ML Kit makes a recognizer for an image processed after [close], one
  /// nothing closes: a read still waiting on the file then fails instead.
  TextRecognizer get _openRecognizer {
    if (_closed) throw StateError('the text reader is closed');
    return _recognizer ??= TextRecognizer();
  }

  static InputImage _input(LumaFrame frame, int rotation) {
    return InputImage.fromBytes(
      bytes: frame.isBgra
          ? frame.bytes
          : nv21FromLuma(frame.bytes, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow),
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: frame.isBgra ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
        bytesPerRow: frame.isBgra ? frame.bytesPerRow : frame.width,
      ),
    );
  }
}

@visibleForTesting
Future<void> deleteStalePhotos(Directory temp) async {
  try {
    await for (final entry in temp.list()) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (entry is Directory && name.startsWith(_photoDirPrefix)) await entry.delete(recursive: true);
    }
  } on FileSystemException catch (_) {
    // Left for the next run.
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
