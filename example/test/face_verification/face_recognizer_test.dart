import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/recognition/face_recognizer.dart';

void main() {
  group('FaceRecognizer cosineSimilarity', () {
    test('returns one for identical non-zero embeddings', () {
      final recognizer = FaceRecognizer();

      expect(recognizer.cosineSimilarity(<double>[1, 0, 0], <double>[1, 0, 0]), 1.0);
    });

    test('returns zero for orthogonal embeddings', () {
      final recognizer = FaceRecognizer();

      expect(recognizer.cosineSimilarity(<double>[1, 0], <double>[0, 1]), 0.0);
    });

    test('returns zero when either embedding is empty or all zeros', () {
      final recognizer = FaceRecognizer();

      expect(recognizer.cosineSimilarity(<double>[], <double>[1, 2]), 0.0);
      expect(recognizer.cosineSimilarity(<double>[0, 0], <double>[1, 2]), 0.0);
    });

    test('uses the shared prefix when embedding lengths differ', () {
      final recognizer = FaceRecognizer();

      expect(recognizer.cosineSimilarity(<double>[1, 0, 99], <double>[1, 0]), 1.0);
    });
  });
}
