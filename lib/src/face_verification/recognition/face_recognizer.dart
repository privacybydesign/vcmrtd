import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/face_verification.dart';

// Generates and compares 512-dimensional face embeddings using GhostFaceNet.
//
// Call [initializeFromBuffer] once, then [generateEmbedding] per face crop,
// and [cosineSimilarity] to compare two embeddings.
class FaceRecognizer {
  FaceRecognizer()
    : _debugEmbeddingGenerator = null,
      _debugInitOverride = null,
      _debugRunInterpreterOverride = null,
      _debugInputShapeOverride = null,
      _debugOutputShapeOverride = null;

  @visibleForTesting
  FaceRecognizer.withEmbeddingGenerator(List<double> Function(Float32List input, List<int> outputShape) generator)
    : _debugEmbeddingGenerator = generator,
      _debugInitOverride = null,
      _debugRunInterpreterOverride = null,
      _debugInputShapeOverride = null,
      _debugOutputShapeOverride = null;

  @visibleForTesting
  FaceRecognizer.withInterpreterHooks({
    void Function(Uint8List modelBytes, InterpreterOptions options)? onInitialize,
    void Function(Float32List input, dynamic outputTensor)? onRunInterpreter,
    required List<int> inputShape,
    required List<int> outputShape,
  }) : _debugEmbeddingGenerator = null,
       _debugInitOverride = onInitialize,
       _debugRunInterpreterOverride = onRunInterpreter,
       _debugInputShapeOverride = inputShape,
       _debugOutputShapeOverride = outputShape;

  Interpreter? _interpreter;
  bool _debugInitialized = false;

  final List<double> Function(Float32List input, List<int> outputShape)? _debugEmbeddingGenerator;
  final void Function(Uint8List modelBytes, InterpreterOptions options)? _debugInitOverride;
  final void Function(Float32List input, dynamic outputTensor)? _debugRunInterpreterOverride;
  final List<int>? _debugInputShapeOverride;
  final List<int>? _debugOutputShapeOverride;

  // Actual input/output dimensions are read from the model at init time.
  // These are safe fallbacks that match GhostFaceNet_fp32_V2.
  int _inputH = 112;
  int _inputW = 112;
  int _embeddingSize = 512;
  List<int> _outputShape = const <int>[1, 512];

  // Returns CPU-only interpreter options. GhostFaceNet does not benefit from
  // the GPU delegate in practice and avoids NCHW/TRANSPOSE compatibility issues.
  InterpreterOptions _buildOptions() => InterpreterOptions()..threads = 4;

  Future<void> initializeFromBuffer(Uint8List modelBytes) async {
    if (_interpreter != null || _debugInitialized) return;
    final debugInputShape = _debugInputShapeOverride;
    final debugOutputShape = _debugOutputShapeOverride;
    if (debugInputShape != null && debugOutputShape != null) {
      _debugInitOverride?.call(modelBytes, _buildOptions());
      _readShapes(inputShapeOverride: debugInputShape, outputShapeOverride: debugOutputShape);
      _debugInitialized = true;
      return;
    }
    _interpreter = Interpreter.fromBuffer(modelBytes, options: _buildOptions());
    _readShapes();
  }

  void _readShapes({List<int>? inputShapeOverride, List<int>? outputShapeOverride}) {
    final inputShape = inputShapeOverride ?? _interpreter!.getInputTensor(0).shape;
    final outputShape = outputShapeOverride ?? _interpreter!.getOutputTensor(0).shape;
    _outputShape = outputShape;
    if (inputShape.length == 4) {
      _inputH = inputShape[1];
      _inputW = inputShape[2];
    }
    if (outputShape.length >= 2) {
      _embeddingSize = outputShape.last;
    }
  }

  // Generates a unit-normalized embedding for [face].
  //
  // [face] must be a 112×112 RGB image (arbitrary sizes are resized internally).
  // Pixel values are normalized to [-1, 1] using (v - 127.5) / 127.5, which is
  // the standard preprocessing expected by ArcFace-family models including GhostFaceNet.
  List<double> generateEmbedding(img.Image face) {
    final interpreter = _interpreter;
    if (interpreter == null && _debugEmbeddingGenerator == null && _debugRunInterpreterOverride == null) {
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
    final debugGenerator = _debugEmbeddingGenerator;
    final List<double> embedding;
    if (debugGenerator != null) {
      embedding = debugGenerator(buf, _outputShape);
    } else {
      embedding = _runInterpreter(interpreter, buf);
    }
    // The model output should always match _embeddingSize, but guard against
    // unexpected shapes so we never index out of bounds.
    final trimmed = embedding.length > _embeddingSize ? embedding.sublist(0, _embeddingSize) : embedding;
    return _normalize(trimmed);
  }

  List<double> _runInterpreter(Interpreter? interpreter, Float32List input) {
    final output = tfliteMakeTensor(_outputShape);
    final debugRunInterpreter = _debugRunInterpreterOverride;
    if (debugRunInterpreter != null) {
      debugRunInterpreter(input, output);
    } else {
      interpreter!.run(input.buffer, output);
    }
    return tfliteFlatFloatArray(output);
  }

  // Cosine similarity between two L2-normalized embeddings, clamped to [0, 1].
  //
  // Returns 0.0 when either embedding is a zero vector (can happen if the model
  // returned all zeros for an unrecognizable face patch).
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
    if (normA <= 1e-9 || normB <= 1e-9) return 0.0;
    return (dot / (normA * normB)).clamp(0.0, 1.0).toDouble();
  }

  @visibleForTesting
  List<double> debugNormalize(List<double> embedding) => _normalize(embedding);

  @visibleForTesting
  img.Image debugModelInputImage(img.Image face) => _modelInputImage(face);

  // L2-normalizes [embedding] so that cosine similarity equals dot product.
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

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _debugInitialized = false;
  }
}
