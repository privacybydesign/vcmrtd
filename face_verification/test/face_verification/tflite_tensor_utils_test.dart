import 'package:flutter_test/flutter_test.dart';
import 'package:face_verification/src/face_verification/tflite_tensor_utils.dart';

void main() {
  group('tfliteMakeTensor', () {
    test('creates scalar tensor for empty shape', () {
      expect(tfliteMakeTensor(<int>[]), 0.0);
    });

    test('creates nested fixed-size double lists', () {
      final tensor = tfliteMakeTensor(<int>[2, 3]) as List<dynamic>;

      expect(tensor, hasLength(2));
      expect(tensor.first, isA<List<double>>());
      expect(tensor.first, equals(<double>[0, 0, 0]));
    });
  });

  group('tfliteFlatFloatArray', () {
    test('flattens nested numeric output', () {
      final flattened = tfliteFlatFloatArray(<dynamic>[
        <dynamic>[1, 2.5],
        <dynamic>[
          <dynamic>[3],
        ],
      ]);

      expect(flattened, equals(<double>[1, 2.5, 3]));
    });

    test('returns empty list for unsupported values', () {
      expect(tfliteFlatFloatArray('not a tensor'), isEmpty);
    });
  });
}
