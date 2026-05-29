import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/tflite_tensor_utils.dart';

class FaceRecognizer {
  static const _modelAsset = 'assets/face_verification/GhostFaceNet_fp32_V2.tflite';

  Interpreter? _interpreter;
  int _inputH = 112;
  int _inputW = 112;
  int _embeddingSize = 512;
  List<int> _outputShape = const <int>[1, 512];

  Future<InterpreterOptions> _buildOptions() async {
    return InterpreterOptions()..threads = 4;
  }

  Future<void> initializeFromBuffer(Uint8List modelBytes) async {
    if (_interpreter != null) return;
    debugPrint('[FaceVerification] FaceRecognizer: initializing $_modelAsset from buffer, bytes=${modelBytes.length}');
    _interpreter = Interpreter.fromBuffer(modelBytes, options: await _buildOptions());
    _readShapes();
  }

  void _readShapes() {
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    _outputShape = outputShape;
    if (inputShape.length == 4) {
      _inputH = inputShape[1];
      _inputW = inputShape[2];
    }
    if (outputShape.length >= 2) {
      _embeddingSize = outputShape.last;
    }
    debugPrint(
      '[FaceVerification] FaceRecognizer: input shape=$inputShape, output shape=$outputShape, embedding=$_embeddingSize',
    );
  }

  List<double> generateEmbedding(img.Image face, {String label = 'embedding'}) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('FaceRecognizer is not initialized');
    }

    final resized = _modelInputImage(face);
    final bytes = resized.getBytes(order: img.ChannelOrder.rgb);
    final total = _inputH * _inputW;
    final buf = Float32List(total * 3);
    for (var i = 0; i < total; i++) {
      buf[i * 3] = (bytes[i * 3] - 127.5) / 127.5;
      buf[i * 3 + 1] = (bytes[i * 3 + 1] - 127.5) / 127.5;
      buf[i * 3 + 2] = (bytes[i * 3 + 2] - 127.5) / 127.5;
    }
    final output = tfliteMakeTensor(_outputShape);
    interpreter.run(buf.buffer, output);
    final embedding = tfliteFlatFloatArray(output);
    final normalized = _normalize(embedding.length > _embeddingSize ? embedding.sublist(0, _embeddingSize) : embedding);
    _logEmbeddingStats(label, normalized);
    return normalized;
  }

  Uint8List modelInputPng(img.Image face) {
    return Uint8List.fromList(img.encodePng(_modelInputImage(face)));
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    final len = math.min(a.length, b.length);
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    normA = math.sqrt(normA);
    normB = math.sqrt(normB);
    final rawCosine = normA > 1e-9 && normB > 1e-9 ? dot / (normA * normB) : double.nan;
    final score = rawCosine.isNaN ? 0.0 : rawCosine.clamp(0.0, 1.0).toDouble();
    debugPrint(
      '[FaceVerification] Embedding compare: dot=${dot.toStringAsFixed(6)} '
      'normA=${normA.toStringAsFixed(6)} normB=${normB.toStringAsFixed(6)} '
      'rawCosine=${rawCosine.toStringAsFixed(6)} score=${score.toStringAsFixed(6)}',
    );
    return score;
  }

  List<double> _normalize(List<double> embedding) {
    var sq = 0.0;
    for (final v in embedding) {
      sq += v * v;
    }
    final norm = math.sqrt(sq);
    if (norm <= 1e-9) return embedding;
    return embedding.map((v) => v / norm).toList(growable: false);
  }

  img.Image _modelInputImage(img.Image face) {
    return img.copyResize(face, width: _inputW, height: _inputH, interpolation: img.Interpolation.linear);
  }

  void _logEmbeddingStats(String label, List<double> embedding) {
    if (embedding.isEmpty) {
      debugPrint('[FaceVerification] $label embedding stats: len=0');
      return;
    }

    var sq = 0.0;
    var sum = 0.0;
    var minVal = double.infinity;
    var maxVal = -double.infinity;
    var hasNaN = false;
    var hasInf = false;

    for (final v in embedding) {
      if (v.isNaN) hasNaN = true;
      if (v.isInfinite) hasInf = true;
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
      sum += v;
      sq += v * v;
    }

    final norm = math.sqrt(sq);
    final mean = sum / embedding.length;
    final first16 = embedding.take(16).map((double v) => v.isFinite ? v.toStringAsFixed(5) : v.toString()).join(', ');
    debugPrint(
      '[FaceVerification] $label embedding stats: len=${embedding.length} '
      'norm=${norm.toStringAsFixed(6)} min=${minVal.toStringAsFixed(6)} '
      'max=${maxVal.toStringAsFixed(6)} mean=${mean.toStringAsFixed(6)} '
      'hasNaN=$hasNaN hasInf=$hasInf first16=[$first16]',
    );
    _logEmbeddingValues(label, embedding);
  }

  void _logEmbeddingValues(String label, List<double> embedding) {
    const chunkSize = 64;
    for (var start = 0; start < embedding.length; start += chunkSize) {
      final end = math.min(start + chunkSize, embedding.length);
      final values = embedding
          .sublist(start, end)
          .map((double v) => v.isFinite ? v.toStringAsFixed(8) : v.toString())
          .join(', ');
      debugPrint('[FaceVerification] $label embedding values[$start..${end - 1}]=[$values]');
    }
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
