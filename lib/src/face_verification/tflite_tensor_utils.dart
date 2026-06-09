dynamic tfliteMakeTensor(List<int> shape) {
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

List<double> tfliteFlatFloatArray(dynamic arr) {
  if (arr is num) return <double>[arr.toDouble()];
  if (arr is List) {
    final out = <double>[];
    for (final item in arr) {
      out.addAll(tfliteFlatFloatArray(item));
    }
    return out;
  }
  return <double>[];
}
