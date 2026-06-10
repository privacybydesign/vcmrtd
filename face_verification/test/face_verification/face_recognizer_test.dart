import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:face_verification/src/face_verification/recognition/face_recognizer.dart';

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

  group('FaceRecognizer generateEmbedding with fake generator', () {
    test('normalizes embedding returned by fake generator', () {
      final rec = FaceRecognizer.withEmbeddingGenerator(
        (Float32List input, List<int> outputShape) => <double>[3.0, 4.0],
      );

      final result = rec.generateEmbedding(img.Image(width: 112, height: 112));

      expect(result[0], closeTo(0.6, 1e-6));
      expect(result[1], closeTo(0.8, 1e-6));
    });

    test('throws when not initialized and no fake generator is provided', () {
      final rec = FaceRecognizer();

      expect(() => rec.generateEmbedding(img.Image(width: 112, height: 112)), throwsA(isA<StateError>()));
    });

    test('passes default output shape to fake generator', () {
      List<int>? capturedShape;

      final rec = FaceRecognizer.withEmbeddingGenerator((Float32List input, List<int> outputShape) {
        capturedShape = outputShape;
        return <double>[1.0, 0.0];
      });

      rec.generateEmbedding(img.Image(width: 112, height: 112));

      expect(capturedShape, <int>[1, 512]);
    });

    test('passes normalized RGB input in range -1 to 1', () {
      Float32List? capturedInput;

      final rec = FaceRecognizer.withEmbeddingGenerator((Float32List input, List<int> outputShape) {
        capturedInput = input;
        return <double>[1.0, 0.0];
      });

      final image = img.Image(width: 112, height: 112);
      image.setPixelRgb(0, 0, 0, 127, 255);

      rec.generateEmbedding(image);

      expect(capturedInput, isNotNull);
      expect(capturedInput![0], closeTo(-1.0, 1e-6));
      expect(capturedInput![1], closeTo((127 - 127.5) / 127.5, 1e-6));
      expect(capturedInput![2], closeTo(1.0, 1e-6));
    });

    test('resizes non-112 image before generating input tensor', () {
      Float32List? capturedInput;

      final rec = FaceRecognizer.withEmbeddingGenerator((Float32List input, List<int> outputShape) {
        capturedInput = input;
        return <double>[1.0, 0.0];
      });

      rec.generateEmbedding(img.Image(width: 20, height: 30));

      expect(capturedInput, isNotNull);
      expect(capturedInput!.length, 112 * 112 * 3);
    });

    test('trims fake embedding to debug embedding size before normalizing', () {
      final rec = FaceRecognizer.withEmbeddingGenerator(
        (Float32List input, List<int> outputShape) => List<double>.filled(600, 1.0),
      );

      final result = rec.generateEmbedding(img.Image(width: 112, height: 112));

      expect(result.length, 512);
    });

    test('returns zero vector unchanged when fake generator returns zeros', () {
      final rec = FaceRecognizer.withEmbeddingGenerator(
        (Float32List input, List<int> outputShape) => <double>[0.0, 0.0, 0.0],
      );

      final result = rec.generateEmbedding(img.Image(width: 112, height: 112));

      expect(result, <double>[0.0, 0.0, 0.0]);
    });
  });

  group('FaceRecognizer interpreter hooks', () {
    test('initializeFromBuffer applies provided input and output shapes once', () async {
      Uint8List? capturedBytes;
      var initializeCalls = 0;

      final rec = FaceRecognizer.withInterpreterHooks(
        onInitialize: (Uint8List modelBytes, dynamic options) {
          capturedBytes = modelBytes;
          initializeCalls++;
        },
        inputShape: <int>[1, 4, 2, 3],
        outputShape: <int>[1, 3],
        onRunInterpreter: (_, __) {},
      );

      final modelBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      await rec.initializeFromBuffer(modelBytes);
      await rec.initializeFromBuffer(Uint8List.fromList(<int>[9, 9, 9]));

      final resized = rec.debugModelInputImage(img.Image(width: 1, height: 1));
      expect(capturedBytes, modelBytes);
      expect(initializeCalls, 1);
      expect(resized.width, 2);
      expect(resized.height, 4);
    });

    test('generateEmbedding uses interpreter run hook and flattens tensor output', () async {
      Float32List? capturedInput;

      final rec = FaceRecognizer.withInterpreterHooks(
        inputShape: <int>[1, 2, 2, 3],
        outputShape: <int>[1, 4],
        onInitialize: (_, __) {},
        onRunInterpreter: (Float32List input, dynamic outputTensor) {
          capturedInput = input;
          final row = (outputTensor as List<dynamic>).single as List<double>;
          row[0] = 0.0;
          row[1] = 3.0;
          row[2] = 4.0;
          row[3] = 0.0;
        },
      );

      await rec.initializeFromBuffer(Uint8List.fromList(<int>[7, 8, 9]));
      final result = rec.generateEmbedding(img.Image(width: 5, height: 5));

      expect(capturedInput, isNotNull);
      expect(capturedInput!.length, 2 * 2 * 3);
      expect(result.length, 4);
      expect(result[0], 0.0);
      expect(result[1], closeTo(0.6, 1e-6));
      expect(result[2], closeTo(0.8, 1e-6));
      expect(result[3], 0.0);
    });
  });
}
