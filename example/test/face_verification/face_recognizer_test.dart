import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

  group('FaceRecognizer _normalize', () {
    test('produces a unit vector (magnitude 1)', () {
      final rec = FaceRecognizer();
      final v = rec.debugNormalize([3.0, 4.0]); // magnitude = 5
      expect(v[0], closeTo(0.6, 1e-6));
      expect(v[1], closeTo(0.8, 1e-6));
    });

    test('normalization makes dot product equal cosine similarity', () {
      final rec = FaceRecognizer();
      final a = rec.debugNormalize([1.0, 2.0, 3.0]);
      final b = rec.debugNormalize([4.0, 5.0, 6.0]);
      final dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
      expect(dot, closeTo(rec.cosineSimilarity(a, b), 1e-6));
    });

    test('returns unchanged zero vector (no division by zero)', () {
      final rec = FaceRecognizer();
      final v = rec.debugNormalize([0.0, 0.0, 0.0]);
      expect(v, [0.0, 0.0, 0.0]);
    });

    test('single-element vector normalizes to 1.0 or -1.0', () {
      final rec = FaceRecognizer();
      expect(rec.debugNormalize([5.0])[0], closeTo(1.0, 1e-6));
      expect(rec.debugNormalize([-3.0])[0], closeTo(-1.0, 1e-6));
    });
  });

  group('FaceRecognizer _modelInputImage', () {
    test('resizes any image to 112×112', () {
      final rec = FaceRecognizer();
      final image = img.Image(width: 50, height: 60);
      final result = rec.debugModelInputImage(image);
      expect(result.width, 112);
      expect(result.height, 112);
    });

    test('handles image already at 112×112 without error', () {
      final rec = FaceRecognizer();
      final image = img.Image(width: 112, height: 112);
      final result = rec.debugModelInputImage(image);
      expect(result.width, 112);
      expect(result.height, 112);
    });
  });

  group('FaceRecognizer dispose', () {
    test('does not throw when not initialised', () async {
      await FaceRecognizer().dispose();
    });

    test('can be disposed twice without error', () async {
      final rec = FaceRecognizer();
      await rec.dispose();
      await rec.dispose();
    });
  });
}
