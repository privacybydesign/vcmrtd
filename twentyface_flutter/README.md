# twentyface_flutter

Flutter plugin for 20face SDK face verification. Enables comparison of live camera images against passport photos (DG2) with liveness detection.

## Features

- Face verification against passport photos
- Real-time face detection with positioning feedback
- Passive liveness detection (anti-spoofing)
- Support for JPEG and JPEG2000 image formats
- Complete camera UI for face verification flow
- Customizable verification parameters

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  twentyface_flutter:
    path: ../twentyface_flutter  # Or use a git URL
```

### iOS Setup

1. Add camera permission to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for face verification.</string>
```

2. Set minimum iOS version to 13.0 in `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

### Android Setup

1. Add camera permission to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.front" android:required="true" />
```

2. Set minimum SDK version in `android/app/build.gradle`:
```gradle
minSdkVersion 24
```

## Usage

### Basic Face Comparison

```dart
import 'package:twentyface_flutter/twentyface_flutter.dart';

// Initialize the service
final service = FaceVerificationService();
await service.initialize(licenseKey);

// Compare faces
final result = await service.compareFaces(
  liveImage: cameraCapture,        // JPEG bytes from camera
  referenceImage: passportPhoto,   // DG2 image from passport
  referenceImageType: ImageType.jpeg2000,
);

if (result.match && result.passedLivenessCheck) {
  print('Identity verified!');
  print('Similarity: ${result.similarityPercentage?.toStringAsFixed(1)}%');
}

// Clean up
await service.dispose();
```

### Using the Camera UI

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FaceVerificationScreen(
      referenceImage: passportData.photoImageData,
      referenceImageType: ImageType.jpeg2000,
      service: faceService,
      onResult: (result) {
        if (result.match) {
          // Verification successful
        }
      },
      onCancel: () => Navigator.pop(context),
    ),
  ),
);
```

### Face Detection for Custom UI

```dart
final detections = await service.detectFaces(cameraFrame);

for (final detection in detections) {
  print('Face at: ${detection.rectangle}');
  print('Quality OK: ${detection.isOverallOk}');
  print('Pose: ${detection.pose}');
}
```

### Configuration

```dart
final config = FaceVerificationConfig(
  matchThreshold: 0.7,           // Distance threshold for match
  enablePassiveLiveness: true,   // Enable liveness detection
  livenessThreshold: 0.5,        // Liveness confidence threshold
  maxHorizontalRotation: 30.0,   // Max yaw angle in degrees
  maxVerticalRotation: 30.0,     // Max pitch angle in degrees
  minSharpness: 3.0,             // Minimum image sharpness (0-12)
  detectClosestOnly: true,       // Only detect largest face
);

await service.initialize(license, config: config);
```

## Integration with vcmrtd

```dart
import 'package:vcmrtd/vcmrtd.dart';
import 'package:twentyface_flutter/twentyface_flutter.dart';

// After reading passport data with vcmrtd
final passportData = await reader.read();

// Verify face
final result = await verifyFaceAgainstPassport(
  passportPhotoData: passportData.photoImageData,
  passportPhotoType: passportData.photoImageType == ImageType.jpeg2000
      ? ImageType.jpeg2000
      : ImageType.jpeg,
  liveImage: cameraCapture,
  service: faceService,
);
```

## License

Requires a valid 20face SDK license. Inject the license at build time:

```bash
flutter build --dart-define=TWENTYFACE_LICENSE=your_license_here
```

Or set it programmatically:

```dart
await service.initialize(licenseString);
```

## API Reference

### FaceVerificationService

| Method | Description |
|--------|-------------|
| `initialize(license)` | Initialize SDK with license |
| `compareFaces(...)` | Compare two face images |
| `detectFaces(image)` | Detect faces in an image |
| `checkLiveness(image)` | Check if face is live |
| `getVersion()` | Get SDK version |
| `dispose()` | Release SDK resources |

### FaceComparisonResult

| Property | Type | Description |
|----------|------|-------------|
| `match` | `bool` | Whether faces match |
| `recognitionDistance` | `double` | Distance between faces (0-2) |
| `isSuccessful` | `bool` | Whether comparison was successful |
| `passedLivenessCheck` | `bool` | Whether liveness passed |
| `similarityPercentage` | `double?` | Similarity as percentage |

### FaceStatus

Contains quality check flags:
- `detectionNoFaces` - No face detected
- `qualitycheckBlurry` - Image too blurry
- `qualitycheckRotated` - Face rotated too much
- `qualitycheckOverexposed` - Image overexposed
- `passiveAntispoofingSpoofed` - Liveness check failed
- `isOverallOk` - All checks passed
