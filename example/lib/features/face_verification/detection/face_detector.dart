import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmark_pipeline.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';

class FaceObservation {
  const FaceObservation({
    required this.result,
    required this.boundingBox,
    required this.boundingBoxAreaRatio,
    required this.boundingBoxCenter,
    required this.mouthRatio,
    required this.yawDegrees,
    required this.blendshapeScores,
    required this.alignedFace112,
  });

  final FaceLandmarkerResult result;
  final Rect boundingBox;
  final double boundingBoxAreaRatio;

  /// Face bounding-box center, normalized to the frame (0..1 on each axis).
  /// Mirror- and rotation-robust enough to test "is the face centered in the
  /// oval" without mapping to exact screen coordinates.
  final Offset boundingBoxCenter;
  final double mouthRatio;
  final double? yawDegrees;
  final Map<String, double> blendshapeScores;
  final img.Image alignedFace112;
}

class FaceDetectorService {
  static const int _targetSize = 112;

  static const int _idxLeftEye = 468;
  static const int _idxRightEye = 473;
  static const int _idxNose = 1;
  static const int _idxMouthL = 61;
  static const int _idxMouthR = 291;

  // ArcFace canonical 5-point alignment targets for a 112×112 crop:
  // left eye, right eye, nose tip, left mouth corner, right mouth corner.
  static const List<double> _dstPoints = <double>[
    38.2946,
    51.6963,
    73.5318,
    51.5014,
    56.0252,
    71.7366,
    41.5493,
    92.3655,
    70.7299,
    92.2041,
  ];

  final FaceLandmarkPipeline _pipeline = FaceLandmarkPipeline();

  Future<void> initialize() async {
    await _pipeline.initialize();
  }

  void initializeFromBuffers({
    required Uint8List detector,
    required Uint8List landmarks,
    required Uint8List blendshapes,
  }) {
    _pipeline.initializeFromBuffers(detector: detector, landmarks: landmarks, blendshapes: blendshapes);
  }

  void resetTracking() {
    _pipeline.resetTracking();
  }

  void setTrackingCrop(DetectorStageOutput? crop) {
    _pipeline.setTrackingCrop(crop);
  }

  DetectorStageOutput? runDetectorStage(img.Image image) {
    return _pipeline.runDetectorStage(image);
  }

  FaceObservation? runLandmarkStage(img.Image image, DetectorStageOutput crop, {bool runBlendshapes = true}) {
    final result = _pipeline.runLandmarkStage(image, crop, runBlendshapes: runBlendshapes);
    if (result == null || result.landmarks.isEmpty) {
      return null;
    }
    return buildObservation(image, result);
  }

  DetectorStageOutput? computeTrackingCrop(FaceLandmarkerResult result, int imgW, int imgH) {
    return _pipeline.computeTrackingCrop(result, imgW, imgH);
  }

  FaceObservation? detectPrimaryFace(img.Image image, {bool runBlendshapes = true}) {
    final crop = _pipeline.runDetectorStage(image);
    if (crop == null) {
      _pipeline.resetTracking();
      return null;
    }
    final result = _pipeline.runLandmarkStage(image, crop, runBlendshapes: runBlendshapes);
    if (result == null || result.landmarks.isEmpty) {
      _pipeline.resetTracking();
      return null;
    }
    _pipeline.updateTrackingCrop(result, image.width, image.height);
    if (result.landmarks.first.length <= _idxRightEye) return null;
    return buildObservation(image, result);
  }

  img.Image? detectAndCrop(img.Image image) {
    final result = detectPrimaryFace(image, runBlendshapes: false);
    return result?.alignedFace112;
  }

  FaceObservation buildObservation(img.Image image, FaceLandmarkerResult result) {
    final landmarks = result.landmarks.first;
    if (landmarks.length <= _idxRightEye) {
      throw StateError('Face landmark result is missing required alignment landmarks');
    }

    final box = _boundsFromLandmarks(landmarks, image.width, image.height);
    final boxAreaRatio = (box.width * box.height) / (image.width * image.height).clamp(1, 1 << 30);
    final center = Offset(
      (box.center.dx / image.width).clamp(0.0, 1.0),
      (box.center.dy / image.height).clamp(0.0, 1.0),
    );
    final mouthRatio = _mouthOpenRatioFromLandmarks(landmarks);
    final yaw = matrixYaw(result);
    final blendshapeScores = _blendshapeMap(result);
    final aligned = _similarityWarp(image, result);

    return FaceObservation(
      result: result,
      boundingBox: box,
      boundingBoxAreaRatio: boxAreaRatio.clamp(0.0, 1.0),
      boundingBoxCenter: center,
      mouthRatio: mouthRatio,
      yawDegrees: yaw,
      blendshapeScores: blendshapeScores,
      alignedFace112: aligned,
    );
  }

  double? matrixYaw(FaceLandmarkerResult result) {
    final mats = result.transformMatrices;
    if (mats == null || mats.isEmpty) return null;
    final m = mats.first;
    if (m.length < 3) return null;
    final v = (-m[2]).clamp(-1.0, 1.0);
    return math.asin(v) * 180.0 / math.pi;
  }

  Map<String, double> _blendshapeMap(FaceLandmarkerResult result) {
    final lists = result.blendshapes;
    if (lists == null || lists.isEmpty) return const <String, double>{};
    final first = lists.first;
    return <String, double>{for (final c in first) c.categoryName: c.score};
  }

  Rect _boundsFromLandmarks(List<NormalizedLandmark> landmarks, int imgW, int imgH) {
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final lm in landmarks) {
      final x = (lm.x * imgW).clamp(0.0, imgW.toDouble());
      final y = (lm.y * imgH).clamp(0.0, imgH.toDouble());
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (!minX.isFinite || !maxX.isFinite || !minY.isFinite || !maxY.isFinite) {
      return Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble());
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _mouthOpenRatioFromLandmarks(List<NormalizedLandmark> lm) {
    if (lm.length <= 152) return 0.0;
    final gap = _dist(lm[13], lm[14]);
    final h = _dist(lm[10], lm[152]).clamp(1e-6, 10.0);
    return gap / h;
  }

  double _dist(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  img.Image _similarityWarp(img.Image bitmap, FaceLandmarkerResult result) {
    final landmarks = result.landmarks.first;
    final w = bitmap.width.toDouble();
    final h = bitmap.height.toDouble();

    final eyeAX = landmarks[_idxLeftEye].x * w;
    final eyeAY = landmarks[_idxLeftEye].y * h;
    final eyeBX = landmarks[_idxRightEye].x * w;
    final eyeBY = landmarks[_idxRightEye].y * h;
    final noseX = landmarks[_idxNose].x * w;
    final noseY = landmarks[_idxNose].y * h;
    final mouthAX = landmarks[_idxMouthL].x * w;
    final mouthAY = landmarks[_idxMouthL].y * h;
    final mouthBX = landmarks[_idxMouthR].x * w;
    final mouthBY = landmarks[_idxMouthR].y * h;

    final leftEyeX = eyeAX <= eyeBX ? eyeAX : eyeBX;
    final leftEyeY = eyeAX <= eyeBX ? eyeAY : eyeBY;
    final rightEyeX = eyeAX <= eyeBX ? eyeBX : eyeAX;
    final rightEyeY = eyeAX <= eyeBX ? eyeBY : eyeAY;

    final leftMouthX = mouthAX <= mouthBX ? mouthAX : mouthBX;
    final leftMouthY = mouthAX <= mouthBX ? mouthAY : mouthBY;
    final rightMouthX = mouthAX <= mouthBX ? mouthBX : mouthAX;
    final rightMouthY = mouthAX <= mouthBX ? mouthBY : mouthAY;

    final src = <double>[
      leftEyeX,
      leftEyeY,
      rightEyeX,
      rightEyeY,
      noseX,
      noseY,
      leftMouthX,
      leftMouthY,
      rightMouthX,
      rightMouthY,
    ];

    final t = _estimateSimilarityTransform(src, _dstPoints);
    return _warpAffine(bitmap, t);
  }

  // Closed-form Umeyama algorithm: finds the least-squares similarity transform
  // (uniform scale + rotation + translation) mapping src to dst landmark pairs.
  _SimilarityTransform _estimateSimilarityTransform(List<double> src, List<double> dst) {
    final n = src.length ~/ 2;
    var srcMx = 0.0;
    var srcMy = 0.0;
    var dstMx = 0.0;
    var dstMy = 0.0;
    for (var i = 0; i < n; i++) {
      srcMx += src[i * 2];
      srcMy += src[i * 2 + 1];
      dstMx += dst[i * 2];
      dstMy += dst[i * 2 + 1];
    }
    srcMx /= n;
    srcMy /= n;
    dstMx /= n;
    dstMy /= n;

    var a = 0.0;
    var b = 0.0;
    var srcVar = 0.0;
    for (var i = 0; i < n; i++) {
      final sx = src[i * 2] - srcMx;
      final sy = src[i * 2 + 1] - srcMy;
      final dx = dst[i * 2] - dstMx;
      final dy = dst[i * 2 + 1] - dstMy;
      a += sx * dx + sy * dy;
      b += sx * dy - sy * dx;
      srcVar += sx * sx + sy * sy;
    }

    final scale = srcVar > 0.0 ? math.sqrt(a * a + b * b) / srcVar : 1.0;
    final cosV = srcVar > 0.0 ? a / (srcVar * scale) : 1.0;
    final sinV = srcVar > 0.0 ? b / (srcVar * scale) : 0.0;
    final m00 = scale * cosV;
    final m01 = -scale * sinV;
    final m10 = scale * sinV;
    final m11 = scale * cosV;
    final tx = dstMx - (m00 * srcMx + m01 * srcMy);
    final ty = dstMy - (m10 * srcMx + m11 * srcMy);
    return _SimilarityTransform(m00: m00, m01: m01, m10: m10, m11: m11, tx: tx, ty: ty);
  }

  // Inverse warp: for each destination pixel compute its source coordinate and bilinearly sample.
  // Forward mapping would scatter source pixels and leave unfilled holes in the output.
  img.Image _warpAffine(img.Image source, _SimilarityTransform t) {
    final det = t.m00 * t.m11 - t.m01 * t.m10;
    if (det.abs() < 1e-9) {
      return img.Image(width: _targetSize, height: _targetSize);
    }

    final srcW = source.width, srcH = source.height;
    final srcBytes = source.getBytes(order: img.ChannelOrder.rgb);
    final outBytes = Uint8List(_targetSize * _targetSize * 3);

    for (var y = 0; y < _targetSize; y++) {
      // Precompute per-row values to avoid redundant work in the inner loop.
      final diRow = y * _targetSize * 3;
      final dy = y - t.ty;
      for (var x = 0; x < _targetSize; x++) {
        final dx = x - t.tx;
        final sx = (t.m11 * dx - t.m01 * dy) / det;
        final sy = (-t.m10 * dx + t.m00 * dy) / det;
        if (sx < 0 || sy < 0 || sx >= srcW || sy >= srcH) continue;

        final x0 = sx.floor(), y0 = sy.floor();
        final fx = sx - x0, fy = sy - y0;
        final x1 = (x0 + 1).clamp(0, srcW - 1);
        final y1 = (y0 + 1).clamp(0, srcH - 1);
        // Precompute row byte offsets to avoid two extra multiplications per pixel.
        final row0 = y0 * srcW * 3;
        final row1 = y1 * srcW * 3;
        final i00 = row0 + x0 * 3;
        final i01 = row0 + x1 * 3;
        final i10 = row1 + x0 * 3;
        final i11 = row1 + x1 * 3;
        final di = diRow + x * 3;
        // Precompute the four bilinear weights once per pixel instead of
        // recomputing (1-fx) and (1-fy) once per channel.
        // Bilinear combination of [0,255] values stays in [0,255], so no clamp needed.
        final w00 = (1.0 - fx) * (1.0 - fy);
        final w01 = fx * (1.0 - fy);
        final w10 = (1.0 - fx) * fy;
        final w11 = fx * fy;
        outBytes[di] = (srcBytes[i00] * w00 + srcBytes[i01] * w01 + srcBytes[i10] * w10 + srcBytes[i11] * w11).round();
        outBytes[di +
            1] = (srcBytes[i00 + 1] * w00 + srcBytes[i01 + 1] * w01 + srcBytes[i10 + 1] * w10 + srcBytes[i11 + 1] * w11)
            .round();
        outBytes[di +
            2] = (srcBytes[i00 + 2] * w00 + srcBytes[i01 + 2] * w01 + srcBytes[i10 + 2] * w10 + srcBytes[i11 + 2] * w11)
            .round();
      }
    }
    return img.Image.fromBytes(width: _targetSize, height: _targetSize, bytes: outBytes.buffer, numChannels: 3);
  }

  Future<void> close() async {
    _pipeline.close();
  }
}

class _SimilarityTransform {
  const _SimilarityTransform({
    required this.m00,
    required this.m01,
    required this.m10,
    required this.m11,
    required this.tx,
    required this.ty,
  });

  final double m00;
  final double m01;
  final double m10;
  final double m11;
  final double tx;
  final double ty;
}
