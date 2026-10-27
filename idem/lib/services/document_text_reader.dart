import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:idem/services/document_photo_quality.dart';
import 'package:idem/services/text_skew.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

const _neutralChroma = 128;
const _photoDirPrefix = 'document_photo';

/// What [DocumentTextReader.photoText] read off a photo.
typedef PhotoText = ({List<String> lines, List<String> barcodes});

/// Finds, with ML Kit's text recognition, where a camera frame's lines of
/// text are, and what a photo's say.
class DocumentTextReader {
  /// Photos a build that read them from files left behind when it was killed
  /// mid-read, deleted once, from the app's start.
  static Future<void>? _staleSwept;

  TextRecognizer? _recognizer;
  BarcodeScanner? _barcodeScanner;
  var _closed = false;

  /// Deletes the photos an earlier build left behind.
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

  /// The lines of text on a photo the step took (a JPEG), block by block,
  /// and the PDF417 barcodes on it (a North American licence's back).
  /// Text recognition reads level text the right way up only, and documents
  /// print some sideways (a Dutch passport's BSN, on the back of its photo
  /// page) and get photographed tilted or upside down: the photo is levelled
  /// and read in all four quarter turns, an empty line between the readings.
  /// Each turn is read as soon as it is made, alongside the others.
  Future<PhotoText> photoText(Uint8List jpeg) async {
    final readings = <Future<List<String>>>[];
    Future<List<Barcode>>? barcodes;
    await for (final turn in levelledTurnsInBackground(jpeg)) {
      final input = _turnInput(turn);
      // Handled once every turn is out; ignore() keeps a failure until then from going unhandled.
      barcodes ??= _openBarcodeScanner.processImage(input)..ignore();
      readings.add(_openRecognizer.processImage(input).then(_lines)..ignore());
    }

    final lines = [
      for (final (i, reading) in (await Future.wait(readings)).indexed) ...[if (i > 0) '', ...reading],
    ];
    return (lines: lines, barcodes: [for (final barcode in await barcodes ?? const <Barcode>[]) ?barcode.rawValue]);
  }

  static List<String> _lines(RecognizedText text) => [
    for (final block in text.blocks)
      for (final line in block.lines) line.text,
  ];

  Future<void> close() async {
    _closed = true;
    final recognizer = _recognizer;
    final barcodeScanner = _barcodeScanner;
    _recognizer = null;
    _barcodeScanner = null;
    await recognizer?.close();
    await barcodeScanner?.close();
  }

  /// ML Kit makes a recognizer for an image processed after [close], one
  /// nothing closes: a read still waiting on the file then fails instead.
  TextRecognizer get _openRecognizer {
    if (_closed) throw StateError('the text reader is closed');
    return _recognizer ??= TextRecognizer();
  }

  BarcodeScanner get _openBarcodeScanner {
    if (_closed) throw StateError('the text reader is closed');
    return _barcodeScanner ??= BarcodeScanner(formats: [BarcodeFormat.pdf417]);
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

/// A photo's brightness, one byte a pixel, rows without padding.
typedef GreyPhoto = ({Uint8List pixels, int width, int height});

/// One turn of a photo as ML Kit takes it: NV21 on Android, [bgra] on iOS.
typedef PhotoTurn = ({Uint8List bytes, int width, int height, bool bgra});

/// The grey copies photos' preparation made of them.
final _greys = Expando<GreyPhoto>('grey');

/// Has [DocumentTextReader.photoText] read [grey], the photo's preparation
/// already made, rather than decode [jpeg] again.
void rememberGrey(Uint8List jpeg, GreyPhoto grey) => _greys[jpeg] = grey;

@visibleForTesting
GreyPhoto? rememberedGrey(Uint8List jpeg) => _greys[jpeg];

/// [image]'s brightness.
GreyPhoto greyPhoto(img.Image image) {
  final grey = greyMat(image);
  try {
    return (pixels: Uint8List.fromList(grey.data), width: grey.cols, height: grey.rows);
  } finally {
    grey.dispose();
  }
}

/// [levelledTurns] off the UI isolate, each as soon as it is made, so
/// reading one doesn't wait for the rest.
@visibleForTesting
Stream<PhotoTurn> levelledTurnsInBackground(Uint8List jpeg) async* {
  final port = ReceivePort();
  try {
    await Isolate.spawn(
      _sendLevelledTurns,
      (jpeg: jpeg, grey: _greys[jpeg], bgra: Platform.isIOS, to: port.sendPort),
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    await for (final message in port) {
      switch (message) {
        case final PhotoTurn turn:
          yield turn;
        case [final error, final stack]:
          throw RemoteError('$error', '$stack');
        default:
          return;
      }
    }
  } finally {
    port.close();
  }
}

void _sendLevelledTurns(({Uint8List jpeg, GreyPhoto? grey, bool bgra, SendPort to}) job) {
  final grey = job.grey ?? _decodedGrey(job.jpeg);
  if (grey == null) return;
  for (final turn in levelledTurns(grey, bgra: job.bgra)) {
    job.to.send(turn);
  }
}

GreyPhoto? _decodedGrey(Uint8List jpeg) {
  final image = img.decodeJpg(jpeg);
  return image == null ? null : greyPhoto(image);
}

/// [photo] with its lines of text levelled, then that turned a quarter
/// clockwise, half round and a quarter anticlockwise.
@visibleForTesting
Iterable<PhotoTurn> levelledTurns(GreyPhoto photo, {required bool bgra}) sync* {
  final grey = cv.Mat.create(rows: photo.height, cols: photo.width, type: cv.MatType.CV_8UC1);
  grey.data.setAll(0, photo.pixels);
  final skew = textSkew(grey);
  final level = skew.abs() < _minSkew ? grey : levelled(grey, skew);
  // NV21 halves both sides for its colour.
  final even = level.region(cv.Rect(0, 0, level.cols & ~1, level.rows & ~1)).clone();
  if (!identical(level, grey)) level.dispose();
  grey.dispose();

  try {
    yield _turn(even, bgra: bgra);
    for (final code in [cv.ROTATE_90_CLOCKWISE, cv.ROTATE_180, cv.ROTATE_90_COUNTERCLOCKWISE]) {
      final turned = cv.rotate(even, code);
      try {
        yield _turn(turned, bgra: bgra);
      } finally {
        turned.dispose();
      }
    }
  } finally {
    even.dispose();
  }
}

PhotoTurn _turn(cv.Mat grey, {required bool bgra}) {
  final (width, height) = (grey.cols, grey.rows);
  if (!bgra) {
    return (
      bytes: nv21FromLuma(grey.data, width: width, height: height, bytesPerRow: width),
      width: width,
      height: height,
      bgra: false,
    );
  }
  final colour = cv.cvtColor(grey, cv.COLOR_GRAY2BGRA);
  try {
    return (bytes: Uint8List.fromList(colour.data), width: width, height: height, bgra: true);
  } finally {
    colour.dispose();
  }
}

InputImage _turnInput(PhotoTurn turn) => InputImage.fromBytes(
  bytes: turn.bytes,
  metadata: InputImageMetadata(
    size: Size(turn.width.toDouble(), turn.height.toDouble()),
    rotation: InputImageRotation.rotation0deg,
    format: turn.bgra ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
    bytesPerRow: turn.bgra ? turn.width * _bgraBytesPerPixel : turn.width,
  ),
);

/// Text recognition copes with this much tilt itself.
const _minSkew = 1.0;

const _bgraBytesPerPixel = 4;

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
