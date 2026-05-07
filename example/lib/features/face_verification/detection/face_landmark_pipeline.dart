import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';

class DetectorStageOutput {
  const DetectorStageOutput({
    required this.cropX1,
    required this.cropY1,
    required this.cropW,
    required this.cropH,
    required this.angle,
  });

  final double cropX1;
  final double cropY1;
  final double cropW;
  final double cropH;
  final double angle;
}

class FaceLandmarkPipeline {
  static const int _detectorSize = 128;
  static const int _landmarkSize = 256;
  static const int _numAnchors = 896;
  static const int _numLandmarks = 478;
  static const int _detectorKeypoints = 6;
  static const double _scoreThreshold = 0.5;
  static const double _iouThreshold = 0.3;
  static const double _fixedCropMargin = 2.0;
  static const double _fixedCropShiftY = -0.10;
  static const double _presenceThreshold = 0.5;

  static const List<String> _blendshapeNames = <String>[
    '_neutral',
    'browDownLeft',
    'browDownRight',
    'browInnerUp',
    'browOuterUpLeft',
    'browOuterUpRight',
    'cheekPuff',
    'cheekSquintLeft',
    'cheekSquintRight',
    'eyeBlinkLeft',
    'eyeBlinkRight',
    'eyeLookDownLeft',
    'eyeLookDownRight',
    'eyeLookInLeft',
    'eyeLookInRight',
    'eyeLookOutLeft',
    'eyeLookOutRight',
    'eyeLookUpLeft',
    'eyeLookUpRight',
    'eyeSquintLeft',
    'eyeSquintRight',
    'eyeWideLeft',
    'eyeWideRight',
    'jawForward',
    'jawLeft',
    'jawOpen',
    'jawRight',
    'mouthClose',
    'mouthDimpleLeft',
    'mouthDimpleRight',
    'mouthFrownLeft',
    'mouthFrownRight',
    'mouthFunnel',
    'mouthLeft',
    'mouthLowerDownLeft',
    'mouthLowerDownRight',
    'mouthPressLeft',
    'mouthPressRight',
    'mouthPucker',
    'mouthRight',
    'mouthRollLower',
    'mouthRollUpper',
    'mouthShrugLower',
    'mouthShrugUpper',
    'mouthSmileLeft',
    'mouthSmileRight',
    'mouthStretchLeft',
    'mouthStretchRight',
    'mouthUpperUpLeft',
    'mouthUpperUpRight',
    'noseSneerLeft',
    'noseSneerRight',
  ];

  static const List<int> _blendshapeLandmarkIndices = <int>[
    0,
    1,
    4,
    5,
    6,
    7,
    8,
    10,
    13,
    14,
    17,
    21,
    33,
    37,
    39,
    40,
    46,
    52,
    53,
    54,
    55,
    58,
    61,
    63,
    65,
    66,
    67,
    70,
    78,
    80,
    81,
    82,
    84,
    87,
    88,
    91,
    93,
    95,
    103,
    105,
    107,
    109,
    127,
    132,
    133,
    136,
    144,
    145,
    146,
    148,
    149,
    150,
    152,
    153,
    154,
    155,
    157,
    158,
    159,
    160,
    161,
    162,
    163,
    168,
    172,
    173,
    176,
    178,
    181,
    185,
    191,
    195,
    197,
    234,
    246,
    249,
    251,
    263,
    267,
    269,
    270,
    276,
    282,
    283,
    284,
    285,
    288,
    291,
    293,
    295,
    296,
    297,
    300,
    308,
    310,
    311,
    312,
    314,
    317,
    318,
    321,
    323,
    324,
    332,
    334,
    336,
    338,
    356,
    361,
    362,
    365,
    373,
    374,
    375,
    377,
    378,
    379,
    380,
    381,
    382,
    384,
    385,
    386,
    387,
    388,
    389,
    390,
    397,
    398,
    400,
    402,
    405,
    409,
    415,
    454,
    466,
    468,
    469,
    470,
    471,
    472,
    473,
    474,
    475,
    476,
    477,
  ];

  static final List<List<double>> _anchors = _buildAnchors();

  Interpreter? _detectorInterp;
  Interpreter? _landmarkInterp;
  Interpreter? _blendshapeInterp;

  dynamic _detRegressors;
  dynamic _detScores;
  dynamic _lmOutRaw;
  dynamic _presenceOutRaw;
  List<dynamic> _lmAllOutputs = <dynamic>[];
  dynamic _blendshapeRaw;
  List<int> _blendshapeInputShape = <int>[];

  DetectorStageOutput? _lastCrop;
  double presenceThreshold = _presenceThreshold;

  Future<void> initialize() async {
    if (_detectorInterp != null) return;
    final numThreads = (Platform.numberOfProcessors ~/ 2).clamp(1, 4);
    final options = InterpreterOptions()..threads = numThreads;

    _detectorInterp = await Interpreter.fromAsset('assets/face_verification/face_detector.tflite', options: options);
    _landmarkInterp = await Interpreter.fromAsset(
      'assets/face_verification/face_landmarks_detector.tflite',
      options: options,
    );
    _blendshapeInterp = await Interpreter.fromAsset(
      'assets/face_verification/face_blendshapes.tflite',
      options: options,
    );

    final det0 = _detectorInterp!.getOutputTensor(0).shape;
    final det1 = _detectorInterp!.getOutputTensor(1).shape;
    _detRegressors = _makeTensor(det0);
    _detScores = _makeTensor(det1);

    final lmOutputCount = _landmarkInterp!.getOutputTensors().length;
    _lmAllOutputs = List<dynamic>.generate(
      lmOutputCount,
      (i) => _makeTensor(_landmarkInterp!.getOutputTensor(i).shape),
    );
    _lmOutRaw = _lmAllOutputs[0];
    _presenceOutRaw = _lmAllOutputs[1];

    final bsInShape = _blendshapeInterp!.getInputTensor(0).shape;
    final bsOutShape = _blendshapeInterp!.getOutputTensor(0).shape;
    _blendshapeInputShape = bsInShape;
    _blendshapeRaw = _makeTensor(bsOutShape);

    _runWarmUp();
  }

  void _runWarmUp() {
    try {
      _warmUpDetector();
    } catch (_) {}
    try {
      _warmUpLandmarker();
    } catch (_) {}
    try {
      _warmUpBlendshapes();
    } catch (_) {}
  }

  void _warmUpDetector() {
    if (_detectorInterp == null) return;
    final zero = List.generate(
      _detectorSize,
      (_) => List.generate(_detectorSize, (_) => <double>[0.0, 0.0, 0.0], growable: false),
      growable: false,
    );
    _detectorInterp!.runForMultipleInputs(<Object>[zero], <int, Object>{0: _detRegressors, 1: _detScores});
  }

  void _warmUpLandmarker() {
    if (_landmarkInterp == null || _lmAllOutputs.isEmpty) return;
    final zero = List.generate(
      _landmarkSize,
      (_) => List.generate(_landmarkSize, (_) => <double>[0.0, 0.0, 0.0], growable: false),
      growable: false,
    );
    final out = <int, Object>{for (var i = 0; i < _lmAllOutputs.length; i++) i: _lmAllOutputs[i]};
    _landmarkInterp!.runForMultipleInputs(<Object>[zero], out);
  }

  void _warmUpBlendshapes() {
    if (_blendshapeInterp == null || _blendshapeInputShape.isEmpty) return;
    final total = _blendshapeInputShape.fold<int>(1, (p, v) => p * v);
    final zeroInput = _reshapeToShape(List<double>.filled(total, 0.0), _blendshapeInputShape);
    _blendshapeInterp!.run(zeroInput, _blendshapeRaw);
  }

  void close() {
    _lastCrop = null;
    _detectorInterp?.close();
    _landmarkInterp?.close();
    _blendshapeInterp?.close();
    _detectorInterp = null;
    _landmarkInterp = null;
    _blendshapeInterp = null;
  }

  void resetTracking() {
    _lastCrop = null;
  }

  FaceLandmarkerResult? detect(img.Image bitmap, {bool runBlendshapes = true}) {
    final box = _detectFace(bitmap);
    if (box == null) return null;
    final crop = _cropRegion(box, bitmap.width, bitmap.height);
    return runLandmarkStage(
      bitmap,
      DetectorStageOutput(cropX1: crop[0], cropY1: crop[1], cropW: crop[2], cropH: crop[3], angle: crop[4]),
      runBlendshapes: runBlendshapes,
    );
  }

  DetectorStageOutput? runDetectorStage(img.Image bitmap) {
    if (_detectorInterp == null) return null;
    final cached = _lastCrop;
    _lastCrop = null;
    if (cached != null) return cached;

    final box = _detectFace(bitmap);
    if (box == null) return null;
    final crop = _cropRegion(box, bitmap.width, bitmap.height);
    return DetectorStageOutput(cropX1: crop[0], cropY1: crop[1], cropW: crop[2], cropH: crop[3], angle: crop[4]);
  }

  FaceLandmarkerResult? runLandmarkStage(img.Image bitmap, DetectorStageOutput crop, {bool runBlendshapes = true}) {
    if (_landmarkInterp == null) return null;
    final landmarkInput = _buildLandmarkInput(bitmap, crop);
    final out = <int, Object>{for (var i = 0; i < _lmAllOutputs.length; i++) i: _lmAllOutputs[i]};
    _landmarkInterp!.runForMultipleInputs(<Object>[landmarkInput], out);

    final rawPresence = _flatFloatArray(_presenceOutRaw);
    if (rawPresence.isEmpty) return null;
    final presence = _sigmoid(rawPresence.first);
    if (presence < presenceThreshold) return null;

    final raw = _flatFloatArray(_lmOutRaw);
    if (raw.length < _numLandmarks * 3) return null;
    final landmarks = _remapLandmarks(raw, crop.cropX1, crop.cropY1, crop.cropW, crop.cropH, crop.angle);
    if (landmarks.length < _numLandmarks) return null;

    final blendshapes = runBlendshapes ? _runBlendshapes(landmarks, bitmap.width, bitmap.height) : null;
    final matrix = _computePoseMatrix(landmarks);

    return FaceLandmarkerResult(
      landmarks: <List<NormalizedLandmark>>[landmarks],
      blendshapes: blendshapes == null ? null : <List<Category>>[blendshapes],
      transformMatrices: matrix == null ? null : <List<double>>[matrix],
    );
  }

  void updateTrackingCrop(FaceLandmarkerResult result, int imgW, int imgH) {
    if (result.landmarks.isEmpty) return;
    final lms = result.landmarks.first;
    if (lms.length < _numLandmarks) return;

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final lm in lms) {
      if (lm.x < minX) minX = lm.x;
      if (lm.x > maxX) maxX = lm.x;
      if (lm.y < minY) minY = lm.y;
      if (lm.y > maxY) maxY = lm.y;
    }

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final w = (maxX - minX).clamp(1e-6, 1.0);
    final h = (maxY - minY).clamp(1e-6, 1.0);
    final angle = _computeRotation(lms[33].x, lms[33].y, lms[263].x, lms[263].y, imgW: imgW, imgH: imgH);
    final crop = _buildSquareCrop(cx, cy, w, h, angle, imgW, imgH);
    _lastCrop = DetectorStageOutput(cropX1: crop[0], cropY1: crop[1], cropW: crop[2], cropH: crop[3], angle: crop[4]);
  }

  List<dynamic> _buildDetectorInput(img.Image bitmap) {
    final letterboxed = _drawDetectorLetterboxed(bitmap);
    return <dynamic>[
      List.generate(_detectorSize, (int y) {
        return List.generate(_detectorSize, (int x) {
          final p = letterboxed.getPixel(x, y);
          return <double>[(p.r - 127.5) / 127.5, (p.g - 127.5) / 127.5, (p.b - 127.5) / 127.5];
        }, growable: false);
      }, growable: false),
    ];
  }

  List<dynamic> _buildLandmarkInput(img.Image bitmap, DetectorStageOutput crop) {
    final imgW = bitmap.width.toDouble();
    final imgH = bitmap.height.toDouble();

    // Equivalent of Kotlin's fillLandmarkBitmap:
    //   matrix.setTranslate(-srcCx, -srcCy)
    //   matrix.postRotate(-toDegrees(angle))
    //   matrix.postScale(256/cropW, 256/cropH)
    // Implemented as copyCrop → optional copyRotate → copyResize to avoid
    // the previous 65 536-pixel per-frame inverse-warp loop with cos/sin.
    final cropCx = (crop.cropX1 + crop.cropW * 0.5) * imgW;
    final cropCy = (crop.cropY1 + crop.cropH * 0.5) * imgH;
    final halfW = (crop.cropW * imgW * 0.5).clamp(1.0, imgW / 2);
    final halfH = (crop.cropH * imgH * 0.5).clamp(1.0, imgH / 2);

    final x1 = (cropCx - halfW).round().clamp(0, bitmap.width - 1);
    final y1 = (cropCy - halfH).round().clamp(0, bitmap.height - 1);
    final x2 = (cropCx + halfW).round().clamp(x1 + 1, bitmap.width);
    final y2 = (cropCy + halfH).round().clamp(y1 + 1, bitmap.height);

    var patch = img.copyCrop(bitmap, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    if (crop.angle.abs() > 0.01) {
      patch = img.copyRotate(patch, angle: -(crop.angle * 180.0 / math.pi));
    }
    final resized = img.copyResize(
      patch,
      width: _landmarkSize,
      height: _landmarkSize,
      interpolation: img.Interpolation.linear,
    );

    return <dynamic>[
      List<dynamic>.generate(
        _landmarkSize,
        (int row) => List<dynamic>.generate(_landmarkSize, (int col) {
          final p = resized.getPixel(col, row);
          return <double>[p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }, growable: false),
        growable: false,
      ),
    ];
  }

  List<double>? _detectFace(img.Image bitmap) {
    if (_detectorInterp == null) return null;
    final input = _buildDetectorInput(bitmap);
    final out = <int, Object>{0: _detRegressors, 1: _detScores};
    _detectorInterp!.runForMultipleInputs(<Object>[input], out);
    return _decodeAndNms();
  }

  List<double>? _decodeAndNms() {
    final scale = _detectorSize.toDouble();
    final boxSize = 5 + _detectorKeypoints * 2;
    final boxes = <List<double>>[];
    for (var i = 0; i < _numAnchors; i++) {
      final box = _decodeBox(i, scale, boxSize);
      if (box != null) boxes.add(box);
    }
    if (boxes.isEmpty) return null;
    boxes.sort((List<double> a, List<double> b) => b[4].compareTo(a[4]));
    return _softNms(boxes, boxSize);
  }

  List<double>? _decodeBox(int i, double scale, int boxSize) {
    final scores = _detScores as List<dynamic>;
    final regressors = _detRegressors as List<dynamic>;
    final score = _sigmoid((scores[0][i][0] as num).toDouble());
    if (score < _scoreThreshold) return null;

    final a = _anchors[i];
    final cx = a[0] + ((regressors[0][i][0] as num).toDouble() / scale);
    final cy = a[1] + ((regressors[0][i][1] as num).toDouble() / scale);
    final w = (regressors[0][i][2] as num).toDouble() / scale;
    final h = (regressors[0][i][3] as num).toDouble() / scale;

    final x1 = cx - (w * 0.5);
    final y1 = cy - (h * 0.5);
    final x2 = cx + (w * 0.5);
    final y2 = cy + (h * 0.5);
    if (x2 <= x1 || y2 <= y1) return null;

    final box = List<double>.filled(boxSize, 0.0);
    box[0] = x1.clamp(0.0, 1.0);
    box[1] = y1.clamp(0.0, 1.0);
    box[2] = x2.clamp(0.0, 1.0);
    box[3] = y2.clamp(0.0, 1.0);
    box[4] = score;
    for (var k = 0; k < _detectorKeypoints; k++) {
      final rx = 4 + k * 2;
      final kx = a[0] + ((regressors[0][i][rx] as num).toDouble() / scale);
      final ky = a[1] + ((regressors[0][i][rx + 1] as num).toDouble() / scale);
      box[5 + k * 2] = kx.clamp(0.0, 1.0);
      box[6 + k * 2] = ky.clamp(0.0, 1.0);
    }
    return box;
  }

  List<double>? _softNms(List<List<double>> sorted, int boxSize) {
    final suppressed = List<bool>.filled(sorted.length, false);
    for (var i = 0; i < sorted.length; i++) {
      if (suppressed[i]) continue;
      final base = sorted[i];
      final group = <List<double>>[base];
      for (var j = i + 1; j < sorted.length; j++) {
        if (!suppressed[j] && _iou(base, sorted[j]) > _iouThreshold) {
          group.add(sorted[j]);
          suppressed[j] = true;
        }
      }
      final totalScore = group.fold<double>(0.0, (double p, List<double> b) => p + b[4]);
      if (totalScore <= 1e-6) return base;
      final merged = List<double>.filled(boxSize, 0.0);
      for (final box in group) {
        final w = box[4] / totalScore;
        for (var j = 0; j < 4; j++) {
          merged[j] += box[j] * w;
        }
        for (var j = 5; j < boxSize; j++) {
          merged[j] += box[j] * w;
        }
      }
      merged[4] = group.first[4];
      return merged;
    }
    return null;
  }

  double _iou(List<double> a, List<double> b) {
    final ix1 = math.max(a[0], b[0]);
    final iy1 = math.max(a[1], b[1]);
    final ix2 = math.min(a[2], b[2]);
    final iy2 = math.min(a[3], b[3]);
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final areaA = (a[2] - a[0]) * (a[3] - a[1]);
    final areaB = (b[2] - b[0]) * (b[3] - b[1]);
    return inter / (areaA + areaB - inter + 1e-6);
  }

  img.Image _drawDetectorLetterboxed(img.Image bitmap) {
    final canvas = img.Image(width: _detectorSize, height: _detectorSize);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));

    final srcW = bitmap.width.toDouble();
    final srcH = bitmap.height.toDouble();
    final scale = math.min(_detectorSize / srcW, _detectorSize / srcH);
    final drawW = (srcW * scale).round().clamp(1, _detectorSize);
    final drawH = (srcH * scale).round().clamp(1, _detectorSize);
    final left = ((_detectorSize - drawW) / 2.0).round();
    final top = ((_detectorSize - drawH) / 2.0).round();
    final resized = img.copyResize(bitmap, width: drawW, height: drawH, interpolation: img.Interpolation.linear);
    img.compositeImage(canvas, resized, dstX: left, dstY: top);
    return canvas;
  }

  List<double> _cropRegion(List<double> box, int imgW, int imgH) {
    final boxCx = (box[0] + box[2]) * 0.5;
    final boxCy = (box[1] + box[3]) * 0.5;
    final boxW = (box[2] - box[0]).clamp(0.05, 0.95);
    final boxH = (box[3] - box[1]).clamp(0.05, 0.95);
    final blended = _keypointBlendedCenter(box, boxCx, boxCy);
    final cx = blended?[0] ?? boxCx;
    final cy = blended?[1] ?? boxCy;
    final angle = box.length >= 9 ? _computeRotation(box[5], box[6], box[7], box[8], imgW: imgW, imgH: imgH) : 0.0;
    return _buildSquareCrop(cx, cy, boxW, boxH, angle, imgW, imgH);
  }

  List<double>? _keypointBlendedCenter(List<double> box, double boxCx, double boxCy) {
    if (box.length < 17) return null;
    var minKx = double.infinity;
    var minKy = double.infinity;
    var maxKx = -double.infinity;
    var maxKy = -double.infinity;
    var count = 0;
    for (var k = 0; k < _detectorKeypoints; k++) {
      final x = box[5 + k * 2];
      final y = box[6 + k * 2];
      if (x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1) {
        minKx = math.min(minKx, x);
        minKy = math.min(minKy, y);
        maxKx = math.max(maxKx, x);
        maxKy = math.max(maxKy, y);
        count++;
      }
    }
    if (count < 4) return null;
    final kpW = math.max(maxKx - minKx, 1e-6);
    final kpH = math.max(maxKy - minKy, 1e-6);
    if (kpW <= 0.05 || kpH <= 0.03) return null;
    final kpCx = (minKx + maxKx) * 0.5;
    final kpCy = (minKy + maxKy) * 0.5;
    return <double>[(kpCx * 0.7 + boxCx * 0.3).clamp(0.0, 1.0), (kpCy * 0.7 + boxCy * 0.3).clamp(0.0, 1.0)];
  }

  List<double> _buildSquareCrop(double cx, double cy, double w, double h, double angle, int imgW, int imgH) {
    final pxSize = math.max(w * imgW, h * imgH) * _fixedCropMargin;
    final normW = pxSize / imgW;
    final normH = pxSize / imgH;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final shiftPx = _fixedCropShiftY * pxSize;
    final shiftedCx = (cx - (sinA * shiftPx / imgW)).clamp(0.0, 1.0);
    final shiftedCy = (cy + (cosA * shiftPx / imgH)).clamp(0.0, 1.0);
    return <double>[shiftedCx - normW / 2.0, shiftedCy - normH / 2.0, normW, normH, angle];
  }

  List<NormalizedLandmark> _remapLandmarks(
    List<double> raw,
    double cropX1,
    double cropY1,
    double cropW,
    double cropH,
    double angle,
  ) {
    final n = raw.length ~/ 3;
    final result = <NormalizedLandmark>[];
    final cropCx = cropX1 + cropW * 0.5;
    final cropCy = cropY1 + cropH * 0.5;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    for (var i = 0; i < n; i++) {
      final lx = (raw[i * 3] / _landmarkSize) - 0.5;
      final ly = (raw[i * 3 + 1] / _landmarkSize) - 0.5;
      final sx = lx * cropW;
      final sy = ly * cropH;
      result.add(
        NormalizedLandmark(
          cropCx + cosA * sx - sinA * sy,
          cropCy + sinA * sx + cosA * sy,
          (raw[i * 3 + 2] / _landmarkSize) * cropW,
        ),
      );
    }
    return result;
  }

  List<Category>? _runBlendshapes(List<NormalizedLandmark> landmarks, int imgW, int imgH) {
    final interp = _blendshapeInterp;
    if (interp == null || _blendshapeInputShape.isEmpty) return null;
    final inputFlat = <double>[];
    for (final idx in _blendshapeLandmarkIndices) {
      final lm = landmarks[idx];
      inputFlat.add(lm.x * imgW);
      inputFlat.add(lm.y * imgH);
    }
    final input = _reshapeToShape(inputFlat, _blendshapeInputShape);
    interp.run(input, _blendshapeRaw);
    final raw = _flatFloatArray(_blendshapeRaw);
    return List<Category>.generate(raw.length, (int i) {
      final name = i < _blendshapeNames.length ? _blendshapeNames[i] : 'blend_$i';
      return Category(name, raw[i]);
    }, growable: false);
  }

  List<double>? _computePoseMatrix(List<NormalizedLandmark> lm) {
    if (lm.length < 455) return null;
    var rX = lm[454].x - lm[234].x;
    var rY = lm[454].y - lm[234].y;
    var rZ = lm[454].z - lm[234].z;

    var uX = lm[10].x - lm[152].x;
    var uY = lm[10].y - lm[152].y;
    var uZ = lm[10].z - lm[152].z;

    final rLen = math.sqrt(rX * rX + rY * rY + rZ * rZ);
    if (rLen < 1e-6) return null;
    rX /= rLen;
    rY /= rLen;
    rZ /= rLen;

    final dot = uX * rX + uY * rY + uZ * rZ;
    uX -= dot * rX;
    uY -= dot * rY;
    uZ -= dot * rZ;
    final uLen = math.sqrt(uX * uX + uY * uY + uZ * uZ);
    if (uLen < 1e-6) return null;
    uX /= uLen;
    uY /= uLen;
    uZ /= uLen;

    final nX = rY * uZ - rZ * uY;
    final nY = rZ * uX - rX * uZ;
    final nZ = rX * uY - rY * uX;

    return <double>[rX, uX, nX, 0.0, rY, uY, nY, 0.0, rZ, uZ, nZ, 0.0, 0.0, 0.0, 0.0, 1.0];
  }

  static List<List<double>> _buildAnchors() {
    const strides = <int>[8, 16, 16, 16];
    final anchors = <List<double>>[];
    for (final stride in strides) {
      final feat = _detectorSize ~/ stride;
      for (var y = 0; y < feat; y++) {
        for (var x = 0; x < feat; x++) {
          for (var k = 0; k < 2; k++) {
            anchors.add(<double>[(x + 0.5) / feat, (y + 0.5) / feat]);
          }
        }
      }
    }
    return anchors;
  }

  double _computeRotation(
    double startX,
    double startY,
    double endX,
    double endY, {
    double targetAngle = 0.0,
    int imgW = 1,
    int imgH = 1,
  }) {
    final a = targetAngle - math.atan2(-(endY - startY) * imgH, (endX - startX) * imgW);
    return _normalizeAngle(a);
  }

  double _normalizeAngle(double angle) {
    final twoPi = 2.0 * math.pi;
    var a = angle % twoPi;
    if (a > math.pi) a -= twoPi;
    if (a < -math.pi) a += twoPi;
    return a;
  }

  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  dynamic _makeTensor(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    return _makeTensorRecursive(shape, 0);
  }

  dynamic _makeTensorRecursive(List<int> shape, int index) {
    final size = shape[index];
    if (index == shape.length - 1) {
      return List<double>.filled(size, 0.0, growable: false);
    }
    return List<dynamic>.generate(size, (_) => _makeTensorRecursive(shape, index + 1), growable: false);
  }

  List<double> _flatFloatArray(dynamic arr) {
    if (arr is num) return <double>[arr.toDouble()];
    if (arr is List) {
      final out = <double>[];
      for (final item in arr) {
        out.addAll(_flatFloatArray(item));
      }
      return out;
    }
    return <double>[];
  }

  dynamic _reshapeToShape(List<double> values, List<int> shape) {
    final total = shape.fold<int>(1, (int p, int v) => p * v);
    if (values.length < total) {
      values = <double>[...values, ...List<double>.filled(total - values.length, 0.0)];
    } else if (values.length > total) {
      values = values.sublist(0, total);
    }
    var idx = 0;
    dynamic build(int dim) {
      if (dim == shape.length - 1) {
        final out = List<double>.filled(shape[dim], 0.0, growable: false);
        for (var i = 0; i < out.length; i++) {
          out[i] = values[idx++];
        }
        return out;
      }
      return List<dynamic>.generate(shape[dim], (_) => build(dim + 1), growable: false);
    }

    return build(0);
  }
}
