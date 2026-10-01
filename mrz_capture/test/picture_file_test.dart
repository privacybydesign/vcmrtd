import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('picture_file_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('readAndDeletePicture returns the picture and deletes its file', () async {
    final file = File('${dir.path}/CAP_1.jpg')..writeAsBytesSync([1, 2, 3]);

    final bytes = await readAndDeletePicture(XFile(file.path));

    expect(bytes, Uint8List.fromList([1, 2, 3]));
    expect(file.existsSync(), isFalse);
  });

  test('readAndDeletePicture reads an in-memory picture without a file', () async {
    final bytes = await readAndDeletePicture(XFile.fromData(Uint8List.fromList([4, 5])));

    expect(bytes, Uint8List.fromList([4, 5]));
  });

  test('readAndDeletePicture fails, without throwing on the delete, when the file is gone', () async {
    expect(readAndDeletePicture(XFile('${dir.path}/missing.jpg')), throwsA(isA<Exception>()));
  });
}
