[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Technical Debt](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_index)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![codecov](https://codecov.io/gh/privacybydesign/vcmrtd/graph/badge.svg)](https://codecov.io/gh/privacybydesign/vcmrtd)

# face_verification

A Flutter package for **face detection and alignment**. It detects the primary face in an image, runs the MediaPipe-style landmark model, and produces an ArcFace-aligned 112×112 crop suitable for feeding into a downstream face SDK (e.g. for recognition or matching).

> **Note:** Liveness detection (active/passive), anti-spoofing, rPPG, and on-device face recognition have been removed from this package. It now does alignment only; matching/liveness is expected to be handled by an external SDK consuming the aligned crop.

## Features

- **Face detection** — bounding box for the primary face
- **478-point landmarks** — full MediaPipe face-mesh landmark set
- **ArcFace alignment** — 112×112 RGB crop warped to the 5 canonical ArcFace keypoints
- **Pose** — yaw (degrees) derived from the landmark pose matrix, plus normalized bounding-box position/size
- Selfie (live-camera, tracked) and NFC/document photo alignment modes
- TFLite models bundled — no separate download needed

## Pipeline

```
image (img.Image, RGB)
        │
        ▼
[1] Face detector  ──▶ bounding box + 6 keypoints   (face_detector.tflite)
        │
        ▼
[2] Landmark model ──▶ 478 landmarks + pose matrix  (face_landmarks_detector.tflite)
        │
        ▼
[3] Similarity warp ─▶ aligned 112×112 crop (Umeyama → ArcFace canonical points)
        │
        ▼
   FaceObservation { boundingBox, boundingBoxAreaRatio, boundingBoxCenter,
                     yawDegrees, alignedFace112, result }
```

In selfie mode the detector crop is cached and reused as a tracking hint between
frames; call `resetTracking()` to force a full re-detect.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  face_verification:
    git:
      url: https://github.com/privacybydesign/vcmrtd.git
      ref: master
      path: face_verification
```

## Platform setup

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for face verification.</string>
```

Android does not require any manual changes — the `camera` plugin adds the `CAMERA` permission automatically via manifest merge.

## Basic usage

```dart
import 'package:image/image.dart' as img;
import 'package:face_verification/face_verification.dart';

final detector = FaceDetectorService();

// Loads the bundled detector + landmark TFLite models.
await detector.initialize();

// One-shot: detect + align the primary face in a still image (e.g. an NFC/document photo).
final img.Image? aligned = detector.detectAndCrop(decodedImage); // 112×112, or null if no face

// Full observation (bounding box, yaw, aligned crop, raw landmarks):
final FaceObservation? face = detector.detectPrimaryFace(
  decodedImage,
  mode: FaceAlignmentMode.selfie, // or FaceAlignmentMode.nfc
);
if (face != null) {
  final img.Image crop = face.alignedFace112; // hand this to your face SDK
  final double? yaw = face.yawDegrees;
}

await detector.close();
```

For a live camera feed, call `detectPrimaryFace(frame, mode: FaceAlignmentMode.selfie)`
on each frame (it caches a tracking crop between frames), and pick the most frontal
`alignedFace112` (smallest `|yawDegrees|`) to forward to the downstream SDK.

If you run the detector in a background isolate, use `initializeFromBuffers(detector:, landmarks:)`
with model bytes loaded on the main isolate (TFLite `Interpreter.fromBuffer` is isolate-safe;
asset loading is not).

## Alignment modes

| Mode | Description |
|------|-------------|
| `FaceAlignmentMode.selfie` | Live-camera faces. Caches the detector crop as a per-frame tracking hint. |
| `FaceAlignmentMode.nfc` | Document/passport photos. No tracking; tuned crop policy for portrait stills. |

## Related packages

- [`vcmrtd`](../vcmrtd) - NFC reading and document parsing for machine-readable travel documents
