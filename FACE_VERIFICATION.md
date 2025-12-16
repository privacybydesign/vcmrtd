# Face Verification with Liveness Detection

This project now includes face verification with liveness detection using the Regula Forensics Face SDK. This feature enhances security by verifying that the person presenting the document is the same person depicted in the document's photo.

## Overview

The face verification feature:
- **Liveness Detection**: Ensures the person is physically present (not a photo or video)
- **Face Matching**: Compares the live face capture with the photo from the document (DG2)
- **Secure**: Uses Regula's Face SDK which has passed iBeta PAD Level 1 and Level 2 tests

## How It Works

1. After successfully reading the document via NFC, the user is prompted for face verification
2. The Face SDK captures a live photo with liveness detection
3. The live photo is compared against the face photo extracted from the document
4. A match score is calculated (threshold: 75%)
5. User proceeds if verification passes, or can retry if it fails

## Integration Flow

```
Document Type Selection
        ↓
    MRZ Scanning
        ↓
   NFC Reading
        ↓
Face Verification ← NEW
        ↓
  Result Display
```

## Setup

### Dependencies

The following packages are required (already added to `pubspec.yaml`):

```yaml
dependencies:
  flutter_face_api: ^7.2.540
  flutter_face_core_basic: ^7.2.540
```

### Android Configuration

**Permissions** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

**Build Configuration** (`android/app/build.gradle`):
```gradle
aaptOptions {
    noCompress "Regula/faceSdkResource.dat"
}
```

### iOS Configuration

**Permissions** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>The camera will be used for scanning your passport and verifying your identity with face recognition</string>
```

## License

The Regula Face SDK can be used in trial mode without a license, but has limitations:
- Watermarks on captured images
- Limited API calls

For production use, obtain a license from [Regula Forensics](https://regulaforensics.com/):
1. Get your license file (`regula.license`)
2. Add it to `example/assets/regula.license`
3. Update `pubspec.yaml` to include the asset:
   ```yaml
   flutter:
     assets:
       - assets/regula.license
   ```

## Usage

### Provider Architecture

The face verification uses Riverpod for state management:

```dart
// Initialize Face SDK
final notifier = ref.read(faceVerificationProvider.notifier);
await notifier.initialize();

// Start liveness detection
final result = await notifier.startLiveness();

// Set document image
notifier.setDocumentImage(documentPhotoBytes);

// Match faces
final matchScore = await notifier.matchFaces();
```

### UI Components

**FaceCaptureScreen**:
- Main screen for face verification
- Shows instructions to the user
- Handles liveness capture
- Displays match results
- Allows skipping (optional)

### Customization

#### Adjust Match Threshold

Default threshold is 75%. To adjust, edit `face_capture_screen.dart`:

```dart
const threshold = 0.75; // Change this value (0.0 to 1.0)
```

#### Disable Skip Option

To make face verification mandatory, remove the `onSkip` parameter in `routing.dart`:

```dart
return FaceCaptureScreen(
  documentImage: documentImage,
  onBack: context.pop,
  onVerificationSuccess: (matchScore) { ... },
  // Remove this line to disable skip:
  // onSkip: () { ... },
);
```

#### Liveness Configuration

Configure liveness settings in `face_verification_provider.dart`:

```dart
final result = await _faceSdk.startLiveness(
  config: LivenessConfig(
    skipStep: [LivenessSkipStep.ONBOARDING_STEP], // Skip onboarding screen
    // Add more configuration options as needed
  ),
);
```

## API Reference

### FaceVerificationNotifier

**Methods:**
- `initialize()` - Initialize the Face SDK
- `startLiveness()` - Start liveness detection and capture face
- `setDocumentImage(Uint8List)` - Set the document photo for comparison
- `matchFaces()` - Compare liveness image with document image
- `reset()` - Reset the verification state

**State Properties:**
- `isInitialized` - Whether SDK is initialized
- `isLoading` - Whether an operation is in progress
- `livenessImage` - Captured liveness image
- `documentImage` - Document photo for comparison
- `matchScore` - Face match score (0.0 to 1.0)
- `error` - Error message if any

## Troubleshooting

### SDK Initialization Fails

**Problem**: "Face SDK initialization error"

**Solutions**:
1. Check internet connection (required for first-time initialization)
2. Verify license file is correctly placed in assets
3. Check logs for specific error codes

### Low Match Scores

**Problem**: Face verification consistently fails with valid matches

**Solutions**:
1. Ensure good lighting conditions
2. Make sure the face is clearly visible
3. Lower the threshold if appropriate for your use case
4. Check document photo quality (from DG2)

### Camera Permission Denied

**Problem**: Camera doesn't activate

**Solutions**:
1. Verify permissions in AndroidManifest.xml / Info.plist
2. Check that user granted camera permission
3. Test on a physical device (not emulator)

## Backend Integration

For production use, you may want to:
1. Send the match score to your backend for verification
2. Store verification results for audit purposes
3. Implement server-side face matching as an additional layer

The backend Docker image mentioned can be integrated separately for server-side verification.

## Resources

- [Regula Face SDK Documentation](https://docs.regulaforensics.com/develop/face-sdk/mobile/)
- [Flutter Face API on pub.dev](https://pub.dev/packages/flutter_face_api)
- [GitHub Repository](https://github.com/regulaforensics/flutter_face_api)
- [Regula Forensics Website](https://regulaforensics.com/)

## Security Considerations

1. **Liveness Detection**: Active liveness (head movement) is more secure than passive
2. **Match Threshold**: Higher threshold = more secure but more false rejections
3. **Backend Verification**: Consider adding server-side verification for critical applications
4. **Data Privacy**: Face images should be processed securely and not stored unless necessary
5. **GDPR Compliance**: Ensure compliance with data protection regulations

## License

This integration uses the Regula Face SDK which is licensed separately. The SDK is free for evaluation purposes but requires a commercial license for production use.

The rest of the project follows the existing license (GPL v3).
