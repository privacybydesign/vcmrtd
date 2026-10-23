import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idem/services/document_photo_quality.dart';
import 'package:image/image.dart' as img;

const _neutralChroma = 128;

/// What [DocumentTextReader.photoText] read off a photo.
typedef PhotoText = ({List<String> lines, List<String> barcodes});

/// Finds, with ML Kit's text recognition, where a camera frame's lines of
/// text are, and what a photo's say.
class DocumentTextReader {
  TextRecognizer? _recognizer;
  BarcodeScanner? _barcodeScanner;

  /// The lines of text in the frame, in fractions of the upright frame;
  /// [rotation] turns the frame upright (clockwise degrees).
  Future<List<Rect>> lines(LumaFrame frame, {required int rotation}) async {
    final text = await (_recognizer ??= TextRecognizer()).processImage(_input(frame, rotation));
    final boxes = [
      for (final block in text.blocks)
        for (final line in block.lines) line.boundingBox,
    ];

    return fractionsOfUpright(boxes, width: frame.width, height: frame.height, rotation: rotation);
  }

  /// The lines of text on a photo the step took (a JPEG), block by block,
  /// and the PDF417 barcodes on it (a North American licence's back).
  /// Text recognition reads text the right way up only, and documents print
  /// some sideways (a Dutch passport's BSN, on the back of its photo page):
  /// the photo is read turned a quarter both ways too, an empty line between
  /// the readings.
  Future<PhotoText> photoText(Uint8List jpeg) async {
    // ML Kit reads an encoded image only from a file.
    final dir = await Directory.systemTemp.createTemp('document_photo');
    try {
      final turned = compute(quarterTurns, jpeg);
      final upright = await _file(dir, 'photo.jpg', jpeg);
      final recognizer = _recognizer ??= TextRecognizer();
      final text = await recognizer.processImage(upright);
      final barcodes = await (_barcodeScanner ??= BarcodeScanner(
        formats: [BarcodeFormat.pdf417],
      )).processImage(upright);
      final lines = _lines(text);
      for (final (i, photo) in (await turned).indexed) {
        lines
          ..add('')
          ..addAll(_lines(await recognizer.processImage(await _file(dir, 'turned$i.jpg', photo))));
      }
      return (lines: lines, barcodes: [for (final barcode in barcodes) ?barcode.rawValue]);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  static Future<InputImage> _file(Directory dir, String name, Uint8List jpeg) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(jpeg, flush: true);
    return InputImage.fromFilePath(file.path);
  }

  static List<String> _lines(RecognizedText text) => [
    for (final block in text.blocks)
      for (final line in block.lines) line.text,
  ];

  Future<void> close() async {
    final recognizer = _recognizer;
    final barcodeScanner = _barcodeScanner;
    _recognizer = null;
    _barcodeScanner = null;
    await recognizer?.close();
    await barcodeScanner?.close();
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

/// [jpeg] turned a quarter clockwise and a quarter anticlockwise.
@visibleForTesting
List<Uint8List> quarterTurns(Uint8List jpeg) {
  final image = img.decodeJpg(jpeg);
  if (image == null) return const [];
  return [
    for (final angle in [90, -90]) img.encodeJpg(img.copyRotate(image, angle: angle), quality: _turnedQuality),
  ];
}

/// High enough that the turned photo reads like the photo itself.
const _turnedQuality = 90;

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
