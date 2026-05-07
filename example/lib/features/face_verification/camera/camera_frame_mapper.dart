import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class MappedCameraFrame {
  final Uint8List mlBytes;
  final InputImageFormat mlFormat;
  final int bytesPerRow;
  final img.Image rgbImage;

  const MappedCameraFrame({
    required this.mlBytes,
    required this.mlFormat,
    required this.bytesPerRow,
    required this.rgbImage,
  });
}

class CameraFrameMapper {
  static MappedCameraFrame? map(CameraImage image) {
    if (image.planes.isEmpty) return null;

    if (image.format.group == ImageFormatGroup.bgra8888) {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      final rgb = _bgraToRgbImage(bytes, image.width, image.height, plane.bytesPerRow);
      return MappedCameraFrame(
        mlBytes: bytes,
        mlFormat: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
        rgbImage: rgb,
      );
    }

    if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
      final nv21 = _yuv420ToNv21(image);
      final rgb = _yuv420ToRgbImage(image);
      return MappedCameraFrame(mlBytes: nv21, mlFormat: InputImageFormat.nv21, bytesPerRow: image.width, rgbImage: rgb);
    }

    return null;
  }

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final out = Uint8List(ySize + ySize ~/ 2);

    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];

    var outIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * y.bytesPerRow;
      for (var col = 0; col < width; col++) {
        out[outIndex++] = y.bytes[rowStart + col];
      }
    }

    final uvPixelStrideU = u.bytesPerPixel ?? 1;
    final uvPixelStrideV = v.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      final uRow = row * u.bytesPerRow;
      final vRow = row * v.bytesPerRow;
      for (var col = 0; col < width ~/ 2; col++) {
        out[outIndex++] = v.bytes[vRow + col * uvPixelStrideV];
        out[outIndex++] = u.bytes[uRow + col * uvPixelStrideU];
      }
    }
    return out;
  }

  static img.Image _bgraToRgbImage(Uint8List bytes, int width, int height, int bytesPerRow) {
    final out = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      final rowStart = y * bytesPerRow;
      for (var x = 0; x < width; x++) {
        final i = rowStart + x * 4;
        final b = bytes[i];
        final g = bytes[i + 1];
        final r = bytes[i + 2];
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  static img.Image _yuv420ToRgbImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = img.Image(width: width, height: height);

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final vUvPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final uvY = y >> 1;
      final yRowStart = y * yRowStride;
      final uvRowStartU = uvY * uvRowStride;
      final uvRowStartV = uvY * vPlane.bytesPerRow;

      for (var x = 0; x < width; x++) {
        final uvX = x >> 1;
        final yValue = yPlane.bytes[yRowStart + x];
        final uValue = uPlane.bytes[uvRowStartU + uvX * uvPixelStride];
        final vValue = vPlane.bytes[uvRowStartV + uvX * vUvPixelStride];

        final yFloat = yValue.toDouble();
        final uFloat = uValue.toDouble() - 128.0;
        final vFloat = vValue.toDouble() - 128.0;

        final r = (yFloat + 1.402 * vFloat).round().clamp(0, 255);
        final g = (yFloat - 0.344136 * uFloat - 0.714136 * vFloat).round().clamp(0, 255);
        final b = (yFloat + 1.772 * uFloat).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  static img.Image rotateToUpright(img.Image image, int rotationDegrees) {
    final normalized = ((rotationDegrees % 360) + 360) % 360;
    return switch (normalized) {
      90 => img.copyRotate(image, angle: 90),
      180 => img.copyRotate(image, angle: 180),
      270 => img.copyRotate(image, angle: 270),
      _ => image,
    };
  }

  static img.Image cropFace(img.Image source, Rect bbox, {double scale = 1.0}) {
    final cx = bbox.left + bbox.width / 2;
    final cy = bbox.top + bbox.height / 2;
    final w = bbox.width * scale;
    final h = bbox.height * scale;

    final left = math.max(0, (cx - w / 2).floor());
    final top = math.max(0, (cy - h / 2).floor());
    final right = math.min(source.width, (cx + w / 2).ceil());
    final bottom = math.min(source.height, (cy + h / 2).ceil());
    final cropW = math.max(1, right - left);
    final cropH = math.max(1, bottom - top);
    return img.copyCrop(source, x: left, y: top, width: cropW, height: cropH);
  }
}
