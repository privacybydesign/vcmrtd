import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class FaceRecognizer {
  static const _modelAsset = 'assets/face_verification/GhostFaceNet_fp32_V2.tflite';

  Interpreter? _interpreter;
  int _inputH = 112;
  int _inputW = 112;
  int _embeddingSize = 512;
  List<int> _outputShape = const <int>[1, 512];

  Future<InterpreterOptions> _buildOptions() async {
    final options = InterpreterOptions()..threads = 4;
    try {
      options.addDelegate(await FlexDelegate.create());
    } catch (_) {}
    return options;
  }

  Future<void> initialize() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(_modelAsset, options: await _buildOptions());
    _readShapes();
  }

  Future<void> initializeFromBuffer(Uint8List modelBytes) async {
    if (_interpreter != null) return;
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
  }

  List<double> generateEmbedding(img.Image face) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('FaceRecognizer is not initialized');
    }

    final resized = img.copyResize(face, width: _inputW, height: _inputH, interpolation: img.Interpolation.linear);
    final bytes = resized.getBytes(order: img.ChannelOrder.rgb);
    final total = _inputH * _inputW;
    final buf = Float32List(total * 3);
    for (var i = 0; i < total; i++) {
      buf[i * 3] = (bytes[i * 3] - 127.5) / 127.5;
      buf[i * 3 + 1] = (bytes[i * 3 + 1] - 127.5) / 127.5;
      buf[i * 3 + 2] = (bytes[i * 3 + 2] - 127.5) / 127.5;
    }
    final output = _makeTensor(_outputShape);
    interpreter.run(buf.buffer, output);
    final embedding = _flatFloatArray(output);
    return _normalize(embedding.length > _embeddingSize ? embedding.sublist(0, _embeddingSize) : embedding);
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    final len = math.min(a.length, b.length);
    var dot = 0.0;
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(0.0, 1.0);
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

  dynamic _makeTensor(List<int> shape) {
    if (shape.isEmpty) return 0.0;

    dynamic build(int dim) {
      final size = shape[dim];
      if (dim == shape.length - 1) {
        return List<double>.filled(size, 0.0, growable: false);
      }
      return List<dynamic>.generate(size, (_) => build(dim + 1), growable: false);
    }

    return build(0);
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

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
