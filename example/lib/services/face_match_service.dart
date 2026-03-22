import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for face matching using FaceNet TFLite model.
///
/// Reimplements the face matching pipeline from multipaz-samples:
/// 1. Detect face using ML Kit (landmarks for alignment)
/// 2. Crop, rotate (level eyes), and scale face to 160x160
/// 3. Generate 512-dimensional face embedding via FaceNet
/// 4. Compare embeddings using cosine similarity
class FaceMatchService {
  static const int inputSize = 160;
  static const int _embeddingSize = 512;

  Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool get isInitialized => _interpreter != null;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/facenet_512.tflite');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _faceDetector.close();
  }

  /// Get face embedding from an image file (e.g., captured selfie).
  Future<List<double>?> getEmbeddingFromFile(String filePath) async {
    final imageBytes = await File(filePath).readAsBytes();
    var image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Apply EXIF orientation so pixel data matches ML Kit's coordinate space.
    image = img.bakeOrientation(image);

    final inputImage = InputImage.fromFilePath(filePath);
    final faces = await _faceDetector.processImage(inputImage);

    img.Image faceImage;
    if (faces.isNotEmpty) {
      faceImage = _extractAlignedFace(image, faces.first);
    } else {
      faceImage = img.copyResize(image, width: inputSize, height: inputSize);
    }

    return _getEmbedding(faceImage);
  }

  /// Get face embedding from raw image bytes (e.g., passport photo JPEG).
  Future<List<double>?> getEmbeddingFromBytes(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Write to temp file for ML Kit face detection
    final tempPath =
        '${Directory.systemTemp.path}/face_match_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(img.encodeJpg(image));

      final inputImage = InputImage.fromFilePath(tempPath);
      final faces = await _faceDetector.processImage(inputImage);

      img.Image faceImage;
      if (faces.isNotEmpty) {
        faceImage = _extractAlignedFace(image, faces.first);
      } else {
        // Passport photos are already face portraits, just resize
        faceImage =
            img.copyResize(image, width: inputSize, height: inputSize);
      }

      return _getEmbedding(faceImage);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Reimplementation of multipaz's extractFaceBitmap algorithm.
  ///
  /// Uses facial landmarks (eyes, mouth) to:
  /// 1. Determine face center (midpoint between eyes)
  /// 2. Calculate crop region based on inter-pupillary distance
  /// 3. Compute rotation angle to level the eyes horizontally
  /// 4. Crop, rotate, and scale to [inputSize] x [inputSize]
  img.Image _extractAlignedFace(img.Image image, Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth];

    if (leftEye == null || rightEye == null) {
      return _cropBoundingBox(image, face.boundingBox);
    }

    // Heuristic multipliers from multipaz
    const faceCropFactor = 4.0;
    const faceVerticalOffsetFactor = 0.25;

    final lx = leftEye.position.x.toDouble();
    final ly = leftEye.position.y.toDouble();
    final rx = rightEye.position.x.toDouble();
    final ry = rightEye.position.y.toDouble();

    // Face center = midpoint between eyes
    var faceCenterX = (lx + rx) / 2;
    var faceCenterY = (ly + ry) / 2;

    // Inter-pupillary distance
    final eyeOffsetX = lx - rx;
    final eyeOffsetY = ly - ry;
    final eyeDistance =
        sqrt(eyeOffsetX * eyeOffsetX + eyeOffsetY * eyeOffsetY);
    final faceWidth = (eyeDistance * faceCropFactor).round();
    final faceVerticalOffset = eyeDistance * faceVerticalOffsetFactor;

    // Shift center downward to better frame the full face
    if (mouth != null) {
      if (ly < mouth.position.y) {
        faceCenterY += faceVerticalOffset;
      } else {
        faceCenterY -= faceVerticalOffset;
      }
    } else {
      faceCenterY += faceVerticalOffset;
    }

    // Calculate eye tilt angle for rotation correction
    final eyesAngleRad = atan2(eyeOffsetY, eyeOffsetX);
    final eyesAngleDeg = eyesAngleRad * 180.0 / pi;

    return _cropRotateScale(
      image,
      faceCenterX,
      faceCenterY,
      -eyesAngleDeg,
      faceWidth,
      faceWidth,
      inputSize,
    );
  }

  img.Image _cropBoundingBox(img.Image image, Rect boundingBox) {
    final x = boundingBox.left.round().clamp(0, image.width - 1);
    final y = boundingBox.top.round().clamp(0, image.height - 1);
    final w = boundingBox.width.round().clamp(1, image.width - x);
    final h = boundingBox.height.round().clamp(1, image.height - y);

    final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
    return img.copyResize(cropped, width: inputSize, height: inputSize);
  }

  img.Image _cropRotateScale(
    img.Image source,
    double cx,
    double cy,
    double angleDegrees,
    int cropWidth,
    int cropHeight,
    int targetSize,
  ) {
    final needsRotation = angleDegrees.abs() > 1.0;

    // Crop a larger region when rotating so that black corners from
    // rotation land in the padding, not on the face.
    final padding = needsRotation ? (cropWidth * 0.4).round() : 0;
    final paddedW = cropWidth + padding * 2;
    final paddedH = cropHeight + padding * 2;

    final halfW = paddedW ~/ 2;
    final halfH = paddedH ~/ 2;
    var x = (cx - halfW).round().clamp(0, source.width - 1);
    var y = (cy - halfH).round().clamp(0, source.height - 1);
    var w = min(paddedW, source.width - x);
    var h = min(paddedH, source.height - y);

    if (w <= 0 || h <= 0) {
      return img.copyResize(source, width: targetSize, height: targetSize);
    }

    var result = img.copyCrop(source, x: x, y: y, width: w, height: h);

    if (needsRotation) {
      result = img.copyRotate(result, angle: angleDegrees);

      // Re-crop the center to the desired face size, removing padding.
      final cxR = result.width ~/ 2;
      final cyR = result.height ~/ 2;
      final finalW = min(cropWidth, result.width);
      final finalH = min(cropHeight, result.height);
      result = img.copyCrop(
        result,
        x: (cxR - finalW ~/ 2).clamp(0, result.width - 1),
        y: (cyR - finalH ~/ 2).clamp(0, result.height - 1),
        width: finalW.clamp(1, result.width),
        height: finalH.clamp(1, result.height),
      );
    }

    return img.copyResize(result, width: targetSize, height: targetSize);
  }

  /// Run FaceNet inference to produce a 512-dimensional face embedding.
  ///
  /// Input is normalized to [-1, 1] range: (pixel - 127.5) / 128.0
  List<double>? _getEmbedding(img.Image face) {
    if (_interpreter == null) return null;

    // Build input tensor [1, 160, 160, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = face.getPixel(x, y);
          return [
            (pixel.r.toDouble() - 127.5) / 128.0,
            (pixel.g.toDouble() - 127.5) / 128.0,
            (pixel.b.toDouble() - 127.5) / 128.0,
          ];
        }),
      ),
    );

    // Output tensor [1, 512]
    final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));

    _interpreter!.run(input, output);

    return output[0];
  }

  /// Calculate cosine similarity between two face embeddings.
  /// Returns a value between 0.0 and 1.0.
  double calculateSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;

    return (dot / denominator).clamp(0.0, 1.0);
  }
}
