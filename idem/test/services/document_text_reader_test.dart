import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_text_reader.dart';
import 'package:idem/services/text_skew.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'text_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fractionsOfUpright', () {
    test('divides by the frame as it is when it needs no quarter turn', () {
      final fractions = fractionsOfUpright(
        [const Rect.fromLTRB(40, 30, 120, 60)],
        width: 400,
        height: 300,
        rotation: 180,
      );
      expect(fractions, [const Rect.fromLTRB(0.1, 0.1, 0.3, 0.2)]);
    });

    test('swaps width and height for a frame turned a quarter', () {
      final fractions = fractionsOfUpright(
        [const Rect.fromLTRB(30, 40, 60, 120)],
        width: 400,
        height: 300,
        rotation: 90,
      );
      expect(fractions, [const Rect.fromLTRB(0.1, 0.1, 0.2, 0.3)]);
    });
  });

  group('levelledTurns', () {
    test('turns a level photo a quarter, half round and a quarter back, as NV21', () {
      final turns = levelledTurns(greyPhoto(textPage()), bgra: false).toList();

      expect(
        [for (final t in turns) (t.width, t.height, t.bytes.length)],
        [
          (600, 400, 600 * 400 * 3 ~/ 2),
          (400, 600, 400 * 600 * 3 ~/ 2),
          (600, 400, 600 * 400 * 3 ~/ 2),
          (400, 600, 400 * 600 * 3 ~/ 2),
        ],
      );
      expect(skewOf(turns.first), closeTo(0, 1));
    });

    test('levels a tilted photo first, to even sides for NV21', () {
      final level = levelledTurns(greyPhoto(img.copyRotate(textPage(), angle: 20)), bgra: false).first;

      expect(skewOf(level), closeTo(0, 1));
      expect((level.width.isEven, level.height.isEven), (true, true));
    });

    test('gives iOS four bytes a pixel', () {
      final level = levelledTurns(greyPhoto(textPage()), bgra: true).first;

      expect((level.bgra, level.bytes.length), (true, 600 * 400 * 4));
    });
  });

  group('levelledTurnsInBackground', () {
    test('decodes a photo it has no grey copy of', () async {
      final tilted = img.copyRotate(textPage(), angle: 20);
      final jpeg = Uint8List.fromList(img.encodeJpg(tilted));

      final turns = await levelledTurnsInBackground(jpeg).toList();

      final decoded = levelledTurns(greyPhoto(img.decodeJpg(jpeg)!), bgra: false);
      expect([for (final t in turns) t.bytes], [for (final t in decoded) t.bytes]);
    });

    test("reads the grey copy the photo's preparation made, not the photo", () async {
      final jpeg = Uint8List.fromList(img.encodeJpg(textPage()));
      rememberGrey(jpeg, greyPhoto(img.Image(width: 200, height: 100)));

      final turns = await levelledTurnsInBackground(jpeg).toList();

      expect((turns.first.width, turns.first.height), (200, 100));
    });

    test('lets go of the grey copy once it has read it', () async {
      final jpeg = Uint8List.fromList(img.encodeJpg(textPage()));
      rememberGrey(jpeg, greyPhoto(img.Image(width: 200, height: 100)));

      await levelledTurnsInBackground(jpeg).toList();

      expect(rememberedGrey(jpeg), isNull);
    });

    test('passes on why a photo could not be read', () {
      expect(levelledTurnsInBackground(Uint8List.fromList([1, 2, 3])).toList(), throwsA(isA<RemoteError>()));
    });
  });

  test('nv21FromLuma drops the row padding and adds neutral chroma', () {
    final luma = Uint8List.fromList([1, 2, 0, 3, 4, 0]);
    expect(nv21FromLuma(luma, width: 2, height: 2, bytesPerRow: 3), [1, 2, 3, 4, 128, 128]);
  });

  test('deleteStalePhotos deletes only the photo directories an earlier run left', () async {
    final temp = await Directory.systemTemp.createTemp('text_reader_test');
    addTearDown(() => temp.delete(recursive: true));
    final stale = await Directory('${temp.path}/document_photoAbc').create();
    await File('${stale.path}/photo.jpg').writeAsBytes([1]);
    final other = await Directory('${temp.path}/other').create();
    final file = await File('${temp.path}/document_photo.txt').create();

    await deleteStalePhotos(temp);

    expect(stale.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(file.existsSync(), isTrue);
  });

  test('a photo still being turned when the reader closes is not read', () async {
    const mlKit = MethodChannel('google_mlkit_text_recognizer');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(mlKit, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(mlKit, null));
    final reader = DocumentTextReader();

    final read = reader.photoText(Uint8List.fromList(img.encodeJpg(textPage())));
    await reader.close();

    await expectLater(read, throwsStateError);
    expect(calls, isEmpty, reason: 'ML Kit would make a recognizer nothing closes');
  });
}

double skewOf(PhotoTurn turn) {
  final grey = cv.Mat.create(rows: turn.height, cols: turn.width, type: cv.MatType.CV_8UC1);
  grey.data.setAll(0, turn.bytes.sublist(0, turn.width * turn.height));
  try {
    return textSkew(grey);
  } finally {
    grey.dispose();
  }
}
