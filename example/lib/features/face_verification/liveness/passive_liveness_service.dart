import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_tuning.dart';
import 'package:vcmrtdapp/features/face_verification/tflite_tensor_utils.dart';

class RppgResult {
  const RppgResult({required this.hr, required this.passed, required this.sampleCount, required this.durationMs});

  final double? hr;
  final bool passed;
  final int sampleCount;
  final int durationMs;
}

class PassiveLivenessService {
  static final double antiSpoofMinScore = FaceVerificationTuning.antiSpoofMinScore;

  static const int _inputSize = 80;
  static const int _liveClassIdx = 1; // MiniFASNet softmax output: 0 = spoof (depth), 1 = live, 2 = spoof (clip)
  static const double _scaleV2 = 2.7;
  static const int _minAntiSpoofSamples = FaceVerificationTuning.antiSpoofMinSamples;
  static final double _antiSpoofSampleRate = FaceVerificationTuning.antiSpoofSampleRate;
  static final double _antiSpoofMaxYawDeg = FaceVerificationTuning.antiSpoofMaxYawDeg;
  static const int _minBvpSamples = 15;
  static const int _minDurationMs = 2000;
  static const double _rppgFrontalMaxYaw = 15.0;
  static const int _rppgMaxGapMs = 1000;

  PassiveLivenessService({
    math.Random? random,
    int Function()? nowMs,
    double? Function(img.Image frame, FaceLandmarkerResult result)? antiSpoofScoreOverride,
    List<double>? Function(int batchLength)? bigSmallBvpOverride,
    List<double>? Function(int modelIndex, Float32List appearanceBuf, Float32List motionBuf, List<int> outputShape)?
    bigSmallModelOutputOverride,
  }) : _random = random ?? math.Random(),
       _nowMs = nowMs,
       _antiSpoofScoreOverride = antiSpoofScoreOverride,
       _bigSmallBvpOverride = bigSmallBvpOverride,
       _bigSmall = _BigSmallService(debugRunOverride: bigSmallModelOutputOverride);

  final math.Random _random;
  final int Function()? _nowMs;
  final double? Function(img.Image frame, FaceLandmarkerResult result)? _antiSpoofScoreOverride;
  final List<double>? Function(int batchLength)? _bigSmallBvpOverride;

  Interpreter? _v1;
  Interpreter? _v2;
  bool _v1Nchw = false;
  bool _v2Nchw = false;

  final List<double> _scores = <double>[];
  double _scoresSum = 0.0;

  final _BigSmallService _bigSmall;
  final List<_RppgFrame> _rppgFrameBuffer = <_RppgFrame>[];
  final Queue<double> _bvpSamples = Queue<double>();
  final Queue<int> _bvpSampleTimes = Queue<int>();
  int _lastFrameBufferedMs = 0;

  Future<void> initialize() async {
    _v1 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v1se.tflite', options: _cpuOptions(2));
    _v2 = await Interpreter.fromAsset('assets/face_verification/minifasnet_v2.tflite', options: _cpuOptions(2));

    _readAntiSpoofShapes();
    await _bigSmall.initialize();
  }

  void initializeFromBuffers({required Uint8List v1, required Uint8List v2, required List<Uint8List> bigSmall}) {
    _v1 = Interpreter.fromBuffer(v1, options: _cpuOptions(2));
    _v2 = Interpreter.fromBuffer(v2, options: _cpuOptions(2));

    _readAntiSpoofShapes();
    _bigSmall.initializeFromBuffers(bigSmall);
  }

  void _readAntiSpoofShapes() {
    final s1 = _v1!.getInputTensor(0).shape;
    final s2 = _v2!.getInputTensor(0).shape;
    _v1Nchw = s1.length == 4 && s1[1] == 3;
    _v2Nchw = s2.length == 4 && s2[1] == 3;
  }

  void reset() {
    _scores.clear();
    _scoresSum = 0.0;
    _rppgFrameBuffer.clear();
    _bvpSamples.clear();
    _bvpSampleTimes.clear();
    _lastFrameBufferedMs = 0;
  }

  void collectPassiveMetrics(img.Image frame, FaceObservation face) {
    _sampleAntiSpoof(frame, face);
    _sampleRppg(frame, face);
  }

  int _currentTimeMs() => _nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  double? getAntiSpoofScore() {
    if (_scores.isEmpty) return null;
    return _scoresSum / _scores.length;
  }

  bool isAntiSpoofPassed() {
    if (_scores.length < _minAntiSpoofSamples) return false;
    final avg = getAntiSpoofScore();
    if (avg == null) return false;
    return avg >= antiSpoofMinScore;
  }

  RppgResult? getRppgResult() {
    if (_bvpSamples.length < _minBvpSamples || _bvpSampleTimes.length < 2) return null;
    final durationMs = (_bvpSampleTimes.last - _bvpSampleTimes.first).clamp(1, 1 << 30);
    if (durationMs < _minDurationMs) return null;
    final fps = (((_bvpSamples.length - 1) * 1000) / durationMs).clamp(1, 1000).toInt();
    return _evaluateBvp(_bvpSamples.toList(growable: false), fps);
  }

  // ---------------------------------------------------------------------------
  // Test-only debug helpers
  // These helpers are intentionally small and safe; they make it easier to
  // write unit tests without altering main logic.
  // ---------------------------------------------------------------------------

  /// Add a synthetic anti-spoof score (for tests).
  void debugAddAntiSpoofScore(double score) {
    _scores.add(score);
    _scoresSum += score;
  }

  /// Add a BVP sample + timestamp (for tests).
  void debugAddBvpSample(double sample, int timestampMs) {
    _bvpSamples.add(sample);
    _bvpSampleTimes.add(timestampMs);
  }

  /// Evaluate current BVP samples and return an `RppgResult` (for tests).
  RppgResult? debugEvaluateBvp() => getRppgResult();

  /// Expose softmax for unit testing.
  @visibleForTesting
  List<double> debugSoftmax(List<double> logits) => _softmax(logits);

  /// Expose face-box pixel calculation for unit testing.
  @visibleForTesting
  List<int>? debugFaceBoxPixels(Map<String, List<double>> rois, int imgW, int imgH) => _faceBoxPixels(rois, imgW, imgH);

  /// Expose scaled crop for unit testing.
  @visibleForTesting
  img.Image? debugScaledCrop(img.Image source, List<int> bbox, double scale) => _scaledCrop(source, bbox, scale);

  /// Expose BGR preprocessing for unit testing.
  @visibleForTesting
  ByteBuffer debugPreprocess(img.Image image, {required bool nchw}) => _preprocess(image, nchw: nchw);

  @visibleForTesting
  Map<String, List<double>>? debugExtractRois(FaceLandmarkerResult result) => _extractRois(result);

  @visibleForTesting
  (img.Image, img.Image)? debugCropFaceForBigSmall(img.Image bitmap, Map<String, List<double>> rois) =>
      _cropFaceForBigSmall(bitmap, rois);

  @visibleForTesting
  RppgResult debugEvaluateBvpSamples(List<double> samples, int fps) => _evaluateBvp(samples, fps);

  @visibleForTesting
  double? debugEstimateHeartRate(List<double> signal, int fps) => _estimateHeartRate(signal, fps);

  @visibleForTesting
  List<int> debugFindPeaks(List<double> signal, int minDist) => _findPeaks(signal, minDist);

  @visibleForTesting
  Float32List debugBuildBigSmallAppearanceBuffer(List<img.Image> appearances) =>
      _bigSmall.debugBuildAppearanceBuffer(appearances);

  @visibleForTesting
  Float32List debugBuildBigSmallMotionBuffer(List<img.Image> motions) => _bigSmall.debugBuildMotionBuffer(motions);

  @visibleForTesting
  List<double>? debugBigSmallRunInferenceWithImages({
    required List<img.Image> appearances,
    required List<img.Image> motions,
    required List<int> timestampsMs,
  }) {
    final count = math.min(appearances.length, math.min(motions.length, timestampsMs.length));

    final batch = List<_RppgFrame>.generate(
      count,
      (i) => _RppgFrame(appearance: appearances[i], motion: motions[i], timestampMs: timestampsMs[i]),
      growable: false,
    );

    return _bigSmall.runInference(batch);
  }

  @visibleForTesting
  void debugSetBigSmallOutputShapes(List<List<int>?> outputShapes) {
    _bigSmall.debugSetOutputShapes(outputShapes);
  }

  void _sampleAntiSpoof(img.Image frame, FaceObservation face) {
    if (_random.nextDouble() >= _antiSpoofSampleRate) return;
    final yaw = face.yawDegrees;
    final isFrontal = yaw == null || yaw.abs() < _antiSpoofMaxYawDeg;
    if (!isFrontal) return;
    final score = _scoreFrame(frame, face.result);
    if (score != null) {
      _scores.add(score);
      _scoresSum += score;
    }
  }

  double? _scoreFrame(img.Image frame, FaceLandmarkerResult result) {
    final override = _antiSpoofScoreOverride;
    if (override != null) return override(frame, result);

    final v1 = _v1;
    final v2 = _v2;
    if (v1 == null || v2 == null) return null;

    final rois = _extractRois(result);
    if (rois == null) return null;
    final bbox = _faceBoxPixels(rois, frame.width, frame.height);
    if (bbox == null) return null;

    final whole = img.copyResize(frame, width: _inputSize, height: _inputSize, interpolation: img.Interpolation.linear);
    final cropV2 = _scaledCrop(frame, bbox, _scaleV2);
    if (cropV2 == null) return null;
    final scaledFace = img.copyResize(
      cropV2,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final in1 = _preprocess(whole, nchw: _v1Nchw);
    final in2 = _preprocess(scaledFace, nchw: _v2Nchw);

    final out1 = <List<double>>[List<double>.filled(3, 0.0)];
    final out2 = <List<double>>[List<double>.filled(3, 0.0)];
    v1.run(in1, out1);
    v2.run(in2, out2);

    final sm1 = _softmax(out1.first);
    final sm2 = _softmax(out2.first);
    final combined = List<double>.generate(3, (int i) => sm1[i] + sm2[i], growable: false);
    final liveConfidence = combined[_liveClassIdx] / 2.0;
    final label = combined.indexOf(combined.reduce(math.max));
    return label == _liveClassIdx ? liveConfidence : 0.0;
  }

  void _sampleRppg(img.Image frame, FaceObservation face) {
    final yaw = face.yawDegrees;
    if (yaw != null && yaw.abs() > _rppgFrontalMaxYaw) return;
    final rois = _extractRois(face.result);
    if (rois == null) return;

    final crops = _cropFaceForBigSmall(frame, rois);
    if (crops == null) return;
    final now = _currentTimeMs();

    if (_rppgFrameBuffer.isNotEmpty && now - _lastFrameBufferedMs > _rppgMaxGapMs) {
      _rppgFrameBuffer.clear();
    }

    _rppgFrameBuffer.add(_RppgFrame(appearance: crops.$1, motion: crops.$2, timestampMs: now));
    _lastFrameBufferedMs = now;

    if (_rppgFrameBuffer.length >= _BigSmallService.bufferFrames) {
      final batch = List<_RppgFrame>.from(_rppgFrameBuffer);
      _rppgFrameBuffer.clear();
      final bvp = _bigSmallBvpOverride?.call(batch.length) ?? _bigSmall.runInference(batch);
      if (bvp != null) {
        final count = math.min(bvp.length, batch.length - 1);
        for (var i = 0; i < count; i++) {
          _bvpSamples.add(bvp[i]);
          final t0 = batch[i].timestampMs;
          final t1 = batch[i + 1].timestampMs;
          _bvpSampleTimes.add(t0 + ((t1 - t0) ~/ 2));
        }
        while (_bvpSamples.length > 900) {
          _bvpSamples.removeFirst();
          _bvpSampleTimes.removeFirst();
        }
      }
    }
  }

  Map<String, List<double>>? _extractRois(FaceLandmarkerResult result) {
    if (result.landmarks.isEmpty) return null;
    final lm = result.landmarks.first;
    final fw = (lm[338].x - lm[109].x).abs();
    final s = fw * 0.15;
    return <String, List<double>>{
      'forehead': <double>[lm[10].x, lm[10].y - s * 0.3, s],
      'right_cheek': <double>[lm[205].x, lm[205].y, s],
      'left_cheek': <double>[lm[425].x, lm[425].y, s],
      'nose': <double>[lm[4].x, lm[4].y, s * 0.8],
      'lips': <double>[(lm[0].x + lm[17].x) / 2.0, (lm[0].y + lm[17].y) / 2.0, s],
    };
  }

  List<int>? _faceBoxPixels(Map<String, List<double>> rois, int imgW, int imgH) {
    final l = rois['left_cheek'];
    final r = rois['right_cheek'];
    final f = rois['forehead'];
    final p = rois['lips'];
    if (l == null || r == null || f == null || p == null) return null;

    final minX = math.min(l[0], r[0]);
    final maxX = math.max(l[0], r[0]);
    final minY = math.min(f[1], p[1]);
    final maxY = math.max(f[1], p[1]);

    final x = (minX * imgW).toInt().clamp(0, imgW - 1);
    final y = (minY * imgH).toInt().clamp(0, imgH - 1);
    final w = ((maxX - minX) * imgW).toInt().clamp(1, imgW);
    final h = ((maxY - minY) * imgH).toInt().clamp(1, imgH);
    if (w <= 1 || h <= 1) return null;
    return <int>[x, y, w, h];
  }

  img.Image? _scaledCrop(img.Image source, List<int> bbox, double scale) {
    final srcW = source.width;
    final srcH = source.height;
    final s = math.min((srcH - 1.0) / bbox[3], math.min((srcW - 1.0) / bbox[2], scale));
    final cx = bbox[2] / 2.0 + bbox[0];
    final cy = bbox[3] / 2.0 + bbox[1];
    var ltX = cx - bbox[2] * s / 2.0;
    var ltY = cy - bbox[3] * s / 2.0;
    var rbX = cx + bbox[2] * s / 2.0;
    var rbY = cy + bbox[3] * s / 2.0;

    if (ltX < 0.0) {
      rbX -= ltX;
      ltX = 0.0;
    }
    if (ltY < 0.0) {
      rbY -= ltY;
      ltY = 0.0;
    }
    if (rbX > srcW - 1.0) {
      ltX -= rbX - srcW + 1.0;
      rbX = srcW - 1.0;
    }
    if (rbY > srcH - 1.0) {
      ltY -= rbY - srcH + 1.0;
      rbY = srcH - 1.0;
    }

    final x1 = ltX.toInt().clamp(0, srcW - 1);
    final y1 = ltY.toInt().clamp(0, srcH - 1);
    final x2 = rbX.toInt().clamp(0, srcW - 1);
    final y2 = rbY.toInt().clamp(0, srcH - 1);
    if (x2 <= x1 || y2 <= y1) return null;
    return img.copyCrop(source, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
  }

  // MiniFASNet was trained on OpenCV BGR images, so channels are written in reverse order
  // relative to the RGB bytes returned by the image library.
  ByteBuffer _preprocess(img.Image image, {required bool nchw}) {
    final rawBytes = image.getBytes(order: img.ChannelOrder.rgb);
    const planeSize = _inputSize * _inputSize;
    final buf = Float32List(planeSize * 3);
    if (nchw) {
      for (var i = 0; i < planeSize; i++) {
        buf[i] = rawBytes[i * 3 + 2].toDouble(); // B
        buf[planeSize + i] = rawBytes[i * 3 + 1].toDouble(); // G
        buf[2 * planeSize + i] = rawBytes[i * 3].toDouble(); // R
      }
    } else {
      for (var i = 0; i < planeSize; i++) {
        buf[i * 3] = rawBytes[i * 3 + 2].toDouble(); // B
        buf[i * 3 + 1] = rawBytes[i * 3 + 1].toDouble(); // G
        buf[i * 3 + 2] = rawBytes[i * 3].toDouble(); // R
      }
    }
    return buf.buffer;
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(math.max);
    final exps = logits.map((double v) => math.exp(v - maxVal)).toList(growable: false);
    final sum = exps.reduce((double a, double b) => a + b);
    return exps.map((double e) => e / (sum == 0 ? 1 : sum)).toList(growable: false);
  }

  (img.Image, img.Image)? _cropFaceForBigSmall(img.Image bitmap, Map<String, List<double>> rois) {
    final l = rois['left_cheek'];
    final r = rois['right_cheek'];
    final f = rois['forehead'];
    final p = rois['lips'];
    if (l == null || r == null || f == null || p == null) return null;

    final imgW = bitmap.width;
    final imgH = bitmap.height;
    final x1 = ((math.min(l[0], r[0]) - l[2]) * imgW).toInt().clamp(0, imgW - 1);
    final x2 = ((math.max(l[0], r[0]) + r[2]) * imgW).toInt().clamp(0, imgW - 1);
    final y1 = ((f[1] - f[2]) * imgH).toInt().clamp(0, imgH - 1);
    final y2 = ((p[1] + p[2]) * imgH).toInt().clamp(0, imgH - 1);
    if (x2 <= x1 || y2 <= y1) return null;

    final cropped = img.copyCrop(bitmap, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    final appearance = img.copyResize(
      cropped,
      width: _BigSmallService.appearanceSize,
      height: _BigSmallService.appearanceSize,
      interpolation: img.Interpolation.linear,
    );
    final motion = img.copyResize(
      cropped,
      width: _BigSmallService.motionSize,
      height: _BigSmallService.motionSize,
      interpolation: img.Interpolation.linear,
    );
    return (appearance, motion);
  }

  RppgResult _evaluateBvp(List<double> samples, int fps) {
    if (samples.isEmpty || fps <= 0) {
      return const RppgResult(hr: null, passed: false, sampleCount: 0, durationMs: 0);
    }
    final hr = _estimateHeartRate(samples, fps);
    final passed = hr != null && hr >= 45.0 && hr <= 110.0;
    final durationMs = fps > 0 ? (((samples.length - 1) * 1000) / fps).round() : 0;
    return RppgResult(hr: hr, passed: passed, sampleCount: samples.length, durationMs: durationMs);
  }

  double? _estimateHeartRate(List<double> signal, int fps) {
    if (signal.length < 3) return null;
    final peaks = _findPeaks(signal, (fps * 0.4).clamp(1.0, 1000000.0).toInt());
    if (peaks.length < 2) return null;
    final intervals = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final sec = (peaks[i] - peaks[i - 1]) / fps;
      if (sec >= 0.4 && sec <= 1.5) intervals.add(sec);
    }
    if (intervals.isEmpty) return null;
    final avg = intervals.reduce((double a, double b) => a + b) / intervals.length;
    return 60.0 / avg;
  }

  List<int> _findPeaks(List<double> signal, int minDist) {
    final peaks = <int>[];
    for (var i = 1; i < signal.length - 1; i++) {
      if (signal[i] > signal[i - 1] && signal[i] > signal[i + 1]) {
        if (peaks.isEmpty || i - peaks.last >= minDist) {
          peaks.add(i);
        } else if (signal[i] > signal[peaks.last]) {
          peaks[peaks.length - 1] = i;
        }
      }
    }
    return peaks;
  }

  Future<void> dispose() async {
    _v1?.close();
    _v2?.close();
    _v1 = null;
    _v2 = null;
    _bigSmall.close();
  }
}

class _RppgFrame {
  const _RppgFrame({required this.appearance, required this.motion, required this.timestampMs});

  final img.Image appearance;
  final img.Image motion;
  final int timestampMs;
}

class _BigSmallService {
  _BigSmallService({
    List<double>? Function(int modelIndex, Float32List appearanceBuf, Float32List motionBuf, List<int> outputShape)?
    debugRunOverride,
  }) : _debugRunOverride = debugRunOverride;

  static const List<String> _modelFiles = <String>[
    'assets/face_verification/bigsmall_1.tflite',
    'assets/face_verification/bigsmall_2.tflite',
    'assets/face_verification/bigsmall_3.tflite',
  ];
  static const int frames = 3;
  static const int bufferFrames = frames + 1;
  static const int appearanceSize = 144;
  static const int motionSize = 9;

  final List<Interpreter?> _interpreters = List<Interpreter?>.filled(_modelFiles.length, null);
  final List<List<int>?> _appearanceShapes = List<List<int>?>.filled(_modelFiles.length, null);
  final List<List<int>?> _motionShapes = List<List<int>?>.filled(_modelFiles.length, null);
  final List<List<int>?> _outputShapes = List<List<int>?>.filled(_modelFiles.length, null);
  final List<double>? Function(int modelIndex, Float32List appearanceBuf, Float32List motionBuf, List<int> outputShape)?
  _debugRunOverride;

  Future<void> initialize() async {
    for (var i = 0; i < _modelFiles.length; i++) {
      if (_interpreters[i] != null) continue;
      _interpreters[i] = await Interpreter.fromAsset(_modelFiles[i], options: _cpuOptions(2));
      _loadShapes(i);
    }
  }

  void initializeFromBuffers(List<Uint8List> modelBuffers) {
    for (var i = 0; i < modelBuffers.length; i++) {
      if (_interpreters[i] != null) continue;
      _interpreters[i] = Interpreter.fromBuffer(modelBuffers[i], options: _cpuOptions(2));
      _loadShapes(i);
    }
  }

  void _loadShapes(int i) {
    _appearanceShapes[i] = _interpreters[i]!.getInputTensor(0).shape;
    _motionShapes[i] = _interpreters[i]!.getInputTensor(1).shape;
    _outputShapes[i] = _interpreters[i]!.getOutputTensor(0).shape;
  }

  @visibleForTesting
  void debugSetOutputShapes(List<List<int>?> outputShapes) {
    for (var i = 0; i < _outputShapes.length; i++) {
      _outputShapes[i] = i < outputShapes.length ? outputShapes[i] : null;
    }
  }

  List<double>? runInference(List<_RppgFrame> framesBatch) {
    if (framesBatch.length != bufferFrames) return null;
    final debugRunOverride = _debugRunOverride;
    if (_interpreters.every((Interpreter? i) => i == null) && debugRunOverride == null) return null;

    final appearanceBuf = _buildAppearanceBuf(framesBatch);
    final motionBuf = _buildMotionBuf(framesBatch);

    final sum = List<double>.filled(frames, 0.0);
    var count = 0;

    for (var i = 0; i < _interpreters.length; i++) {
      final interp = _interpreters[i];
      final oShape = _outputShapes[i];
      if (oShape == null) continue;

      final List<double> out;
      if (debugRunOverride != null) {
        out = debugRunOverride(i, appearanceBuf, motionBuf, oShape) ?? const <double>[];
      } else {
        if (interp == null) continue;
        final outTensor = tfliteMakeTensor(oShape);
        interp.runForMultipleInputs(<Object>[appearanceBuf.buffer, motionBuf.buffer], <int, Object>{0: outTensor});
        out = tfliteFlatFloatArray(outTensor);
      }
      if (out.isEmpty) continue;
      final take = math.min(frames, out.length);
      for (var f = 0; f < take; f++) {
        sum[f] += out[f];
      }
      count++;
    }

    if (count == 0) return null;
    return List<double>.generate(frames, (int i) => sum[i] / count, growable: false);
  }

  void close() {
    for (var i = 0; i < _interpreters.length; i++) {
      _interpreters[i]?.close();
      _interpreters[i] = null;
    }
  }

  @visibleForTesting
  Float32List debugBuildAppearanceBuffer(List<img.Image> appearances) {
    final batch = List<_RppgFrame>.generate(
      bufferFrames,
      (i) => _RppgFrame(
        appearance: appearances[i],
        motion: img.Image(width: motionSize, height: motionSize),
        timestampMs: i,
      ),
      growable: false,
    );

    return _buildAppearanceBuf(batch);
  }

  @visibleForTesting
  Float32List debugBuildMotionBuffer(List<img.Image> motions) {
    final batch = List<_RppgFrame>.generate(
      bufferFrames,
      (i) => _RppgFrame(
        appearance: img.Image(width: appearanceSize, height: appearanceSize),
        motion: motions[i],
        timestampMs: i,
      ),
      growable: false,
    );

    return _buildMotionBuf(batch);
  }

  // Packs frames as planar channels (all R pixels, then G, then B) as required by the
  // BigSmall model's appearance stream input layout.
  Float32List _buildAppearanceBuf(List<_RppgFrame> batch) {
    const planeSize = appearanceSize * appearanceSize;
    final buf = Float32List(frames * 3 * planeSize);
    var offset = 0;
    for (var fi = 1; fi <= frames; fi++) {
      final rawBytes = batch[fi].appearance.getBytes(order: img.ChannelOrder.rgb);
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3] / 255.0;
      }
      offset += planeSize;
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3 + 1] / 255.0;
      }
      offset += planeSize;
      for (var i = 0; i < planeSize; i++) {
        buf[offset + i] = rawBytes[i * 3 + 2] / 255.0;
      }
      offset += planeSize;
    }
    return buf;
  }

  // Normalized frame-to-frame pixel difference (nv - cv) / (nv + cv + ε) as a proxy for
  // optical flow. This is the "motion" stream expected by the BigSmall rPPG model.
  Float32List _buildMotionBuf(List<_RppgFrame> batch) {
    const planeSize = motionSize * motionSize;
    const eps = 1e-7;
    final buf = Float32List(frames * 3 * planeSize);
    var offset = 0;
    for (var fi = 0; fi < frames; fi++) {
      final currBytes = batch[fi].motion.getBytes(order: img.ChannelOrder.rgb);
      final nextBytes = batch[fi + 1].motion.getBytes(order: img.ChannelOrder.rgb);
      for (var c = 0; c < 3; c++) {
        for (var i = 0; i < planeSize; i++) {
          final cv = currBytes[i * 3 + c].toDouble();
          final nv = nextBytes[i * 3 + c].toDouble();
          buf[offset++] = (nv - cv) / (nv + cv + eps);
        }
      }
    }
    return buf;
  }
}

// MiniFASNet models have TRANSPOSE ops for NCHW input — GPU delegate produces
// incorrect outputs for NCHW layouts, so these models must run on CPU only.
InterpreterOptions _cpuOptions(int threads) => InterpreterOptions()..threads = threads;
