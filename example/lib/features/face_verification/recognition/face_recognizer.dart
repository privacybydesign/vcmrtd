import 'dart:math' as math;

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class FaceRecognizer {
  static const _modelAsset = 'assets/face_verification/GhostFaceNet-float16.tflite';

  Interpreter? _interpreter;
  int _inputH = 112;
  int _inputW = 112;
  int _embeddingSize = 512;

  Future<void> initialize() async {
    if (_interpreter != null) return;

    final options = InterpreterOptions()..threads = 4;
    options.addDelegate(await FlexDelegate.create());

    _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
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
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputH,
        (y) => List.generate(_inputW, (x) {
          final p = resized.getPixel(x, y);
          final r = (p.r - 127.5) / 127.5;
          final g = (p.g - 127.5) / 127.5;
          final b = (p.b - 127.5) / 127.5;
          return [r, g, b];
        }),
      ),
    );
    final output = List.generate(1, (_) => List<double>.filled(_embeddingSize, 0.0));
    interpreter.run(input, output);
    return _normalize(output.first);
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

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
