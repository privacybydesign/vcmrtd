import 'package:face_verification/face_verification.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

// Measured on a printed portrait laid out like an ID card (scores 0.58 to
// 0.68, face 20 to 30% of the card's height), not yet on a real document.

const _minPortraitHeight = 0.12;
const _maxPortraitHeight = 0.7;

/// The face found on a document, in fractions of the document.
typedef DocumentPortrait = ({Rect box, double score});

/// The MediaPipe models [FaceLandmarkPipeline.initializeFromBuffers] takes:
/// only the detector is used, the pipeline wants all three.
typedef FaceModels = ({Uint8List detector, Uint8List landmarks, Uint8List blendshapes});

Future<FaceModels>? _models;

/// Loaded once; a load that failed is tried again next time.
Future<FaceModels> loadFaceModels() => _models ??= _loadFaceModels().catchError((Object e) {
  _models = null;
  throw e;
});

Future<FaceModels> _loadFaceModels() async {
  Future<Uint8List> load(String name) async {
    final data = await rootBundle.load('packages/face_verification/lib/src/models/$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  return (
    detector: await load('face_detector.tflite'),
    landmarks: await load('face_landmarks_detector.tflite'),
    blendshapes: await load('face_blendshapes.tflite'),
  );
}

FaceLandmarkPipeline portraitFinder(FaceModels models) =>
    FaceLandmarkPipeline()
      ..initializeFromBuffers(detector: models.detector, landmarks: models.landmarks, blendshapes: models.blendshapes);

/// The most confident face in a grey [document] image, [width] x [height].
DocumentPortrait? findPortrait(FaceLandmarkPipeline finder, Uint8List document, int width, int height) {
  final image = img.Image(width: width, height: height);
  // Its 8-bit RGB pixels, row after row, written directly: far faster than pixel by pixel.
  final rgb = image.toUint8List();
  for (var i = 0, o = 0; i < width * height; i++, o += 3) {
    final grey = document[i];
    rgb[o] = grey;
    rgb[o + 1] = grey;
    rgb[o + 2] = grey;
  }
  return finder.detectFaceBox(image);
}

/// Whether [portrait] is sized like a document's: neither a tiny face in the
/// background nor a face filling the frame. Where it is differs per document.
bool portraitInPlace(DocumentPortrait? portrait) {
  if (portrait == null) return false;
  return portrait.box.height >= _minPortraitHeight && portrait.box.height <= _maxPortraitHeight;
}
