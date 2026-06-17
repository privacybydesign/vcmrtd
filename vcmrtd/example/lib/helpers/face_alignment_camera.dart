import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

// Camera-frame and NFC-photo decoding helpers used by the face-alignment flow.
//
// These conversions were originally part of the (removed) face-verification
// worker. The package now does face alignment only, so the camera-specific glue
// lives in the example app instead of the package — keeping the package free of
// a `camera` dependency.

// Native JPEG-2000 decoder. Passport NFC photos are often JP2, which the Dart
// `image` package cannot decode; the platform side handles it via UIKit/Android.
const MethodChannel _imageChannel = MethodChannel('image_channel');

// Converts a single [CameraImage] to an upright RGB [img.Image] ready for the
// face-alignment pipeline. Returns null for unsupported formats.
//
// Android delivers 3-plane YUV420; iOS delivers single-plane BGRA8888.
img.Image? cameraImageToUpright(CameraImage image, int rotationDegrees) {
  img.Image? frame;
  final group = image.format.group;
  if (group == ImageFormatGroup.bgra8888 && image.planes.isNotEmpty) {
    final p = image.planes.first;
    frame = _bgraToRgbImage(p.bytes, image.width, image.height, p.bytesPerRow);
  } else if (group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
    frame = _yuv420ToRgbImage(image);
  }
  if (frame == null) return null;
  return rotateToUpright(frame, rotationDegrees);
}

// Decodes [bytes] to an image. Falls back to the native JP2 decoder via the
// image_channel method channel when the Dart decoder does not recognise the
// format (JPEG 2000 passport photos are decoded natively by the platform).
Future<img.Image?> decodeNfcImage(Uint8List bytes) async {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded != null) return decoded;

  try {
    final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
    if (converted == null) return null;
    return img.decodeImage(converted);
  } catch (_) {
    return null;
  }
}

@visibleForTesting
img.Image bgraToRgbImage(Uint8List bytes, int width, int height, int bytesPerRow) =>
    _bgraToRgbImage(bytes, width, height, bytesPerRow);

img.Image _bgraToRgbImage(Uint8List bytes, int width, int height, int bytesPerRow) {
  final rgb = Uint8List(width * height * 3);
  var dst = 0;
  for (var y = 0; y < height; y++) {
    var src = y * bytesPerRow;
    for (var x = 0; x < width; x++) {
      rgb[dst++] = bytes[src + 2];
      rgb[dst++] = bytes[src + 1];
      rgb[dst++] = bytes[src];
      src += 4;
    }
  }
  return img.Image.fromBytes(width: width, height: height, bytes: rgb.buffer, numChannels: 3);
}

img.Image _yuv420ToRgbImage(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yBytes = image.planes[0].bytes;
  final uBytes = image.planes[1].bytes;
  final vBytes = image.planes[2].bytes;
  final yRowStride = image.planes[0].bytesPerRow;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
  final vRowStride = image.planes[2].bytesPerRow;
  final vPixelStride = image.planes[2].bytesPerPixel ?? 1;

  final rgb = Uint8List(width * height * 3);
  var dst = 0;
  for (var y = 0; y < height; y++) {
    final uvRow = y >> 1;
    final yRowStart = y * yRowStride;
    final uRowStart = uvRow * uvRowStride;
    final vRowStart = uvRow * vRowStride;
    for (var x = 0; x < width; x++) {
      final uvCol = x >> 1;
      final yv = yBytes[yRowStart + x] & 0xFF;
      final uv = (uBytes[uRowStart + uvCol * uvPixelStride] & 0xFF) - 128;
      final vv = (vBytes[vRowStart + uvCol * vPixelStride] & 0xFF) - 128;
      // Full-range BT.601 YCbCr->RGB, coefficients x1024 for integer arithmetic.
      final yScaled = yv << 10;
      rgb[dst++] = ((yScaled + 1436 * vv) >> 10).clamp(0, 255);
      rgb[dst++] = ((yScaled - 352 * uv - 731 * vv) >> 10).clamp(0, 255);
      rgb[dst++] = ((yScaled + 1814 * uv) >> 10).clamp(0, 255);
    }
  }
  return img.Image.fromBytes(width: width, height: height, bytes: rgb.buffer, numChannels: 3);
}

@visibleForTesting
img.Image rotateToUpright(img.Image image, int rotationDegrees) {
  final normalized = ((rotationDegrees % 360) + 360) % 360;
  if (normalized == 0) return image;
  if (normalized == 90) return _rotate90CW(image);
  if (normalized == 270) return _rotate270CW(image);
  if (normalized == 180) return _rotate180(image);
  // Non-axis-aligned fallback (rare).
  final rotated = img.copyRotate(image, angle: normalized.toDouble());
  if (rotated.numChannels == 3) return rotated;
  final rgb = rotated.getBytes(order: img.ChannelOrder.rgb);
  return img.Image.fromBytes(width: rotated.width, height: rotated.height, bytes: rgb.buffer, numChannels: 3);
}

img.Image _transposePixels(img.Image src, int dstW, int dstH, int Function(int x, int y) dstIdx) {
  final srcW = src.width, srcH = src.height;
  final s = src.getBytes(order: img.ChannelOrder.rgb);
  final d = Uint8List(dstW * dstH * 3);
  for (var y = 0; y < srcH; y++) {
    for (var x = 0; x < srcW; x++) {
      final si = (y * srcW + x) * 3;
      final di = dstIdx(x, y) * 3;
      d[di] = s[si];
      d[di + 1] = s[si + 1];
      d[di + 2] = s[si + 2];
    }
  }
  return img.Image.fromBytes(width: dstW, height: dstH, bytes: d.buffer, numChannels: 3);
}

// 90 deg CW: output[x][dstW-1-y] = src[y][x], output size = srcH x srcW.
img.Image _rotate90CW(img.Image src) {
  final dstW = src.height, dstH = src.width;
  return _transposePixels(src, dstW, dstH, (x, y) => x * dstW + (dstW - 1 - y));
}

// 270 deg CW (= 90 deg CCW): output[srcW-1-x][y] = src[y][x].
img.Image _rotate270CW(img.Image src) {
  final dstW = src.height, dstH = src.width;
  return _transposePixels(src, dstW, dstH, (x, y) => (dstH - 1 - x) * dstW + y);
}

// 180 deg: output[srcH-1-y][srcW-1-x] = src[y][x].
img.Image _rotate180(img.Image src) {
  final w = src.width, h = src.height;
  return _transposePixels(src, w, h, (x, y) => (h - 1 - y) * w + (w - 1 - x));
}
