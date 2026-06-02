import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmark_pipeline.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';

// Re-export so that files importing face_detector.dart still get FaceObservation
// without needing a second import.
export 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';

/// Detects and aligns faces using the [FaceLandmarkPipeline].
///
/// Wraps the pipeline with ArcFace-style similarity warping to produce
/// consistent 112×112 crops for the face recognizer.
class FaceDetectorService {
  static const int _targetSize = 112;

  // MediaPipe face-mesh landmark indices for the 5 ArcFace keypoints.
  static const int _idxLeftEye = 468;
  static const int _idxRightEye = 473;
  static const int _idxNose = 1;
  static const int _idxMouthL = 61;
  static const int _idxMouthR = 291;

  // ArcFace canonical 5-point targets for a 112×112 crop.
  // Source: insightface/alignment/coordinate_systems — the same coordinates
  // used to train GhostFaceNet and most ArcFace-family recognition models.
  // Order: left eye, right eye, nose tip, left mouth corner, right mouth corner.
  // Each pair is (x, y) in pixel space of the 112×112 output image.
  static const List<double> _dstPoints = <double>[
    38.2946, 51.6963, // left eye
    73.5318, 51.5014, // right eye
    56.0252, 71.7366, // nose tip
    41.5493, 92.3655, // left mouth corner
    70.7299, 92.2041, // right mouth corner
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

  void resetTracking() => _pipeline.resetTracking();

  void setTrackingCrop(DetectorStageOutput? crop) => _pipeline.setTrackingCrop(crop);

  DetectorStageOutput? runDetectorStage(img.Image image, {FaceAlignmentMode mode = FaceAlignmentMode.selfie}) {
    return _pipeline.runDetectorStage(image, mode: mode);
  }

  FaceObservation? runLandmarkStage(img.Image image, DetectorStageOutput crop, {bool runBlendshapes = true}) {
    final result = _pipeline.runLandmarkStage(image, crop, runBlendshapes: runBlendshapes);
    if (result == null || result.landmarks.isEmpty) return null;
    return buildObservation(image, result);
  }

  DetectorStageOutput? computeTrackingCrop(FaceLandmarkerResult result, int imgW, int imgH) {
    return _pipeline.computeTrackingCrop(result, imgW, imgH);
  }

  /// Convenience method: runs detector + landmark stage and returns an observation.
  FaceObservation? detectPrimaryFace(
    img.Image image, {
    bool runBlendshapes = true,
    FaceAlignmentMode mode = FaceAlignmentMode.selfie,
  }) {
    final crop = _pipeline.runDetectorStage(image, mode: mode);
    if (crop == null) {
      _pipeline.resetTracking();
      return null;
    }
    final result = _pipeline.runLandmarkStage(image, crop, runBlendshapes: runBlendshapes);
    if (result == null || result.landmarks.isEmpty) {
      _pipeline.resetTracking();
      return null;
    }
    if (mode == FaceAlignmentMode.selfie) {
      _pipeline.updateTrackingCrop(result, image.width, image.height);
    }
    if (result.landmarks.first.length <= _idxRightEye) return null;
    return buildObservation(image, result);
  }

  /// Detects the primary face in [image] and returns the aligned 112×112 crop.
  /// Returns null when no face is found. Resets tracking before and after so
  /// successive NFC calls do not interfere with the live-camera tracking state.
  img.Image? detectAndCrop(img.Image image) {
    _pipeline.resetTracking();
    final result = detectPrimaryFace(image, runBlendshapes: false, mode: FaceAlignmentMode.nfc);
    _pipeline.resetTracking();
    return result?.alignedFace112;
  }

  /// Builds a [FaceObservation] from a landmark [result] and its source [image].
  FaceObservation buildObservation(img.Image image, FaceLandmarkerResult result) {
    final landmarks = result.landmarks.first;
    if (landmarks.length <= _idxRightEye) {
      throw StateError('Face landmark result is missing required alignment landmarks');
    }

    final box = _boundsFromLandmarks(landmarks, image.width, image.height);
    // Clamp denominator to at least 1 to guard against a degenerate 0×0 image.
    final boxAreaRatio = (box.width * box.height) / (image.width * image.height).clamp(1, 1 << 30);
    final center = Offset(
      (box.center.dx / image.width).clamp(0.0, 1.0),
      (box.center.dy / image.height).clamp(0.0, 1.0),
    );

    return FaceObservation(
      result: result,
      boundingBox: box,
      boundingBoxAreaRatio: boxAreaRatio.clamp(0.0, 1.0),
      boundingBoxCenter: center,
      mouthRatio: _mouthOpenRatio(landmarks),
      yawDegrees: matrixYaw(result),
      blendshapeScores: _blendshapeMap(result),
      alignedFace112: _similarityWarp(image, result),
    );
  }

  /// Extracts yaw in degrees from the pose matrix stored in [result].
  /// Returns null when the matrix is absent or shorter than expected.
  double? matrixYaw(FaceLandmarkerResult result) {
    final mats = result.transformMatrices;
    if (mats == null || mats.isEmpty) return null;
    final m = mats.first;
    if (m.length < 3) return null;
    // m[2] is the X component of the camera-facing normal vector.
    // asin(-m[2]) converts it to a yaw angle in radians.
    final v = (-m[2]).clamp(-1.0, 1.0);
    return math.asin(v) * 180.0 / math.pi;
  }

  Map<String, double> _blendshapeMap(FaceLandmarkerResult result) {
    final lists = result.blendshapes;
    if (lists == null || lists.isEmpty) return const <String, double>{};
    return <String, double>{for (final c in lists.first) c.categoryName: c.score};
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

  double _mouthOpenRatio(List<NormalizedLandmark> lm) {
    if (lm.length <= 152) return 0.0;
    // lm[13]/lm[14] = upper/lower inner lip; lm[10]/lm[152] = chin to crown.
    final gap = _dist(lm[13], lm[14]);
    final faceH = _dist(lm[10], lm[152]).clamp(1e-6, 10.0);
    return gap / faceH;
  }

  /// Warps [bitmap] so that the 5 detected facial keypoints align with the
  /// canonical ArcFace positions in a [_targetSize]×[_targetSize] output.
  img.Image _similarityWarp(img.Image bitmap, FaceLandmarkerResult result) {
    final lm = result.landmarks.first;
    final w = bitmap.width.toDouble();
    final h = bitmap.height.toDouble();

    final eyeA = (x: lm[_idxLeftEye].x * w, y: lm[_idxLeftEye].y * h);
    final eyeB = (x: lm[_idxRightEye].x * w, y: lm[_idxRightEye].y * h);
    final mouthA = (x: lm[_idxMouthL].x * w, y: lm[_idxMouthL].y * h);
    final mouthB = (x: lm[_idxMouthR].x * w, y: lm[_idxMouthR].y * h);

    // Sort eye and mouth pairs so left always has the smaller X coordinate.
    final eyes = _sortByX(eyeA, eyeB);
    final mouth = _sortByX(mouthA, mouthB);

    // Flat [x0, y0, x1, y1, ...] list matching _dstPoints order.
    final src = <double>[
      eyes.left.x,
      eyes.left.y,
      eyes.right.x,
      eyes.right.y,
      lm[_idxNose].x * w,
      lm[_idxNose].y * h,
      mouth.left.x,
      mouth.left.y,
      mouth.right.x,
      mouth.right.y,
    ];

    return _warpAffine(bitmap, _estimateSimilarityTransform(src, _dstPoints));
  }

  /// Sorts two pixel-space points so that the one with smaller X comes first.
  static ({({double x, double y}) left, ({double x, double y}) right}) _sortByX(
    ({double x, double y}) a,
    ({double x, double y}) b,
  ) {
    return a.x <= b.x ? (left: a, right: b) : (left: b, right: a);
  }

  /// Closed-form Umeyama algorithm: finds the least-squares similarity transform
  /// (uniform scale + rotation + translation) that maps [src] onto [dst].
  ///
  /// Both lists are flat [x0, y0, x1, y1, ...] coordinate pairs.
  _SimilarityTransform _estimateSimilarityTransform(List<double> src, List<double> dst) {
    final n = src.length ~/ 2;
    var srcMx = 0.0, srcMy = 0.0, dstMx = 0.0, dstMy = 0.0;
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

    var a = 0.0, b = 0.0, srcVar = 0.0;
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
    return _SimilarityTransform(
      m00: m00,
      m01: m01,
      m10: m10,
      m11: m11,
      tx: dstMx - (m00 * srcMx + m01 * srcMy),
      ty: dstMy - (m10 * srcMx + m11 * srcMy),
    );
  }

  /// Inverse affine warp: for every destination pixel, compute its source
  /// coordinate and sample bilinearly. Forward mapping would leave unfilled
  /// holes in the output and is therefore not used.
  img.Image _warpAffine(img.Image source, _SimilarityTransform t) {
    final det = t.m00 * t.m11 - t.m01 * t.m10;
    if (det.abs() < 1e-9) return img.Image(width: _targetSize, height: _targetSize);

    final srcW = source.width, srcH = source.height;
    final srcBytes = source.getBytes(order: img.ChannelOrder.rgb);
    final outBytes = Uint8List(_targetSize * _targetSize * 3);

    for (var y = 0; y < _targetSize; y++) {
      // Precompute per-row offset and shifted Y once to reduce inner-loop work.
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
        // Precompute row byte offsets to avoid redundant multiplications per pixel.
        final i00 = y0 * srcW * 3 + x0 * 3;
        final i01 = y0 * srcW * 3 + x1 * 3;
        final i10 = y1 * srcW * 3 + x0 * 3;
        final i11 = y1 * srcW * 3 + x1 * 3;
        final di = diRow + x * 3;
        // Precompute the four bilinear weights once per pixel.
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

  /// Euclidean distance between two normalized landmarks (ignores Z).
  static double _dist(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<void> close() async => _pipeline.close();
}

/// 2-D similarity transform: [m00/m01/m10/m11] form a scaled rotation matrix
/// and [tx/ty] are the translation components.
///
/// Applied as: dst = M * src + t, where M = [[m00, m01], [m10, m11]].
class _SimilarityTransform {
  const _SimilarityTransform({
    required this.m00,
    required this.m01,
    required this.m10,
    required this.m11,
    required this.tx,
    required this.ty,
  });

  final double m00; // scale * cos(angle)
  final double m01; // -scale * sin(angle)
  final double m10; // scale * sin(angle)
  final double m11; // scale * cos(angle)
  final double tx; // X translation
  final double ty; // Y translation
}
