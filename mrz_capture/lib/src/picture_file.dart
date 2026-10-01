import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Reads the picture the camera just took, then deletes the file the camera
/// wrote it to: a picture of an identity document must not stay behind in
/// the app's cache. From here on it only exists in memory, for as long as
/// the caller holds on to it. Deleted even when reading fails.
Future<Uint8List> readAndDeletePicture(XFile file) async {
  try {
    return await file.readAsBytes();
  } finally {
    // An in-memory XFile (tests, web) has no file behind it.
    if (file.path.isNotEmpty) {
      try {
        await File(file.path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }
}
