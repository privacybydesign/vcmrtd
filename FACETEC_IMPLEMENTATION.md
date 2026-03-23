# FaceTec Implementation Guide

This document provides implementation details for the FaceTec face verification integration in the vcmrtd project.

## Overview

FaceTec has been integrated alongside the Regula Forensics solution (from PR #86) to allow comparison between the two face verification providers. The implementation uses FaceTec's platform channel approach to communicate with native Android and iOS SDKs.

## Architecture

### Flutter Layer (Dart)

```
lib/
├── facetec_config.dart                           # Configuration
├── providers/
│   ├── facetec_verification_provider.dart        # Main provider (Riverpod)
│   └── face_verification_config_provider.dart    # Provider switching
├── processors/
│   └── facetec_session_processor.dart            # Session handling
├── utilities/
│   └── facetec_networking.dart                   # Server communication
└── widgets/pages/
    └── facetec_capture_screen.dart               # UI
```

### Native Layer

**Android**: `MainActivity.java`
- Implements `FaceTecSessionRequestProcessor`
- Method channels: `com.facetec.sdk` and `com.facetec.sdk/livenesscheck`
- Handles SDK initialization and liveness sessions

**iOS**: `AppDelegate.swift`
- Implements `FaceTecSessionRequestProcessor`
- Same method channels as Android
- Manages SDK lifecycle

### Communication Flow

```
1. Flutter → Native: Initialize SDK
   MethodChannel: 'com.facetec.sdk'
   Method: 'initialize'

2. Flutter → Native: Start Liveness
   MethodChannel: 'com.facetec.sdk'
   Method: 'startLivenessCheck'

3. Native → Flutter: Process Session
   MethodChannel: 'com.facetec.sdk/livenesscheck'
   Method: 'processSession'

4. Flutter → Server: Send session data
   HTTP POST to FaceTec API

5. Server → Flutter: Response blob

6. Flutter → Native: Process response
   MethodChannel: 'com.facetec.sdk/livenesscheck'
   Method: 'onResponseBlobReceived'
```

## Setup Instructions

### 1. FaceTec Account Setup

1. Create account at https://dev.facetec.com
2. Obtain your Device Key Identifier
3. Download the native SDKs:
   - **Android**: `facetec*.aar` file
   - **iOS**: `FaceTecSDK.xcframework`

### 2. Configure Device Key

Edit `lib/facetec_config.dart`:

```dart
class FaceTecConfig {
  static const String deviceKeyIdentifier = "YOUR_DEVICE_KEY_HERE";
  // ... rest of config
}
```

### 3. Install Native SDKs

**Android:**
1. Copy `facetec*.aar` to `android/app/libs/`
2. Ensure `build.gradle` includes:
   ```gradle
   dependencies {
       implementation fileTree(dir: 'libs', include: ['*.aar'])
   }
   ```

**iOS:**
1. Copy `FaceTecSDK.xcframework` to `ios/`
2. Add to Xcode project:
   - Open `ios/Runner.xcworkspace`
   - Drag `FaceTecSDK.xcframework` into project
   - Ensure "Embed & Sign" is selected

### 4. Copy Native Platform Code

**Android**: Copy MainActivity.java from the FaceTec sample app to your project:
```
FaceTec-Android-iOS-SDK-Flutter/android/app/src/main/java/...
   ↓
example/android/app/src/main/java/...
```

**iOS**: Copy AppDelegate.swift from the FaceTec sample app:
```
FaceTec-Android-iOS-SDK-Flutter/ios/Runner/AppDelegate.swift
   ↓
example/ios/Runner/AppDelegate.swift
```

### 5. Update Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.5.0            # For FaceTec API communication
  logger: ^2.6.1          # For logging
  flutter_riverpod: ^2.6.1  # State management
```

Run:
```bash
flutter pub get
```

### 6. Platform Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for face verification with liveness detection</string>
```

## Usage

### Basic Usage

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtdapp/providers/facetec_verification_provider.dart';
import 'package:vcmrtdapp/widgets/pages/facetec_capture_screen.dart';

// Initialize and use FaceTec verification
final notifier = ref.read(faceTecVerificationProvider.notifier);

// Initialize SDK
await notifier.initialize();

// Start liveness check
await notifier.startLiveness();

// Or use the UI screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => FaceTecCaptureScreen(
      documentImage: documentPhotoBytes,
      onVerificationSuccess: (score) {
        print('Match score: $score');
      },
      onBack: () => Navigator.pop(context),
    ),
  ),
);
```

### Switching Between Providers

```dart
import 'package:vcmrtdapp/providers/face_verification_config_provider.dart';

// Switch to FaceTec
ref.read(faceVerificationConfigProvider.notifier).state =
    FaceVerificationProvider.faceTec;

// Switch to Regula
ref.read(faceVerificationConfigProvider.notifier).state =
    FaceVerificationProvider.regula;

// Disable face verification
ref.read(faceVerificationEnabledProvider.notifier).state = false;
```

## Integration into App Flow

To integrate face verification after NFC reading, update your routing:

```dart
// In routing.dart
onSuccess: (document, result) {
  // Navigate to face capture screen
  context.go(
    '/face_capture',
    extra: {
      'document': document,
      'result': result,
      'document_type': params.documentType
    },
  );
}
```

## Key Components

### FaceTecVerificationProvider

**State Management:**
- `isInitialized` - SDK initialization status
- `isLoading` - Loading indicator
- `isProcessing` - Liveness check in progress
- `livenessImage` - Captured face image
- `documentImage` - Document photo for comparison
- `matchScore` - Similarity score (0.0 - 1.0)
- `error` - Error messages

**Methods:**
- `initialize()` - Initialize FaceTec SDK
- `startLiveness()` - Begin 3D liveness check
- `setDocumentImage(image)` - Set document photo
- `onSessionComplete()` - Handle session completion
- `reset()` - Reset state

### FaceTecCaptureScreen

**Properties:**
- `documentImage` - Optional document photo for matching
- `onVerificationSuccess` - Callback with match score
- `onSkip` - Optional skip callback
- `onBack` - Back navigation callback

**Features:**
- Informative UI explaining the process
- Loading states and error handling
- Match result dialog with threshold
- Platform-adaptive design

### FaceTecNetworking

Handles server communication with FaceTec API:
- Sends session request blobs
- Receives and processes response blobs
- Error handling for network failures

### FaceTecSessionProcessor

Manages session lifecycle:
- Listens for native callbacks
- Coordinates between Flutter and native code
- Handles session data flow

## Comparison with Regula

| Feature | FaceTec | Regula |
|---------|---------|--------|
| **Technology** | 3D face scanning | 2D face matching |
| **Integration** | Platform channels | Flutter package |
| **Liveness** | Active 3D | Active/Passive 2D |
| **Certification** | Industry-leading | iBeta PAD L1/L2 |
| **Setup** | Native SDK + Platform code | Flutter package only |
| **Complexity** | High | Low |
| **Server** | FaceTec API required | Optional backend |

## Testing

### Test Mode

FaceTec SDK works in test mode without a production license using the FaceTec Testing API. The sample configuration includes a test public key and uses the FaceTec test server.

### Testing Checklist

- [ ] SDK initializes successfully
- [ ] Liveness UI appears
- [ ] Face capture completes
- [ ] Session processes successfully
- [ ] Match score calculated
- [ ] Error handling works
- [ ] Both Android and iOS tested

## Troubleshooting

### SDK Initialization Fails

**Problem**: "Device key identifier not configured"

**Solution**:
1. Ensure `FaceTecConfig.deviceKeyIdentifier` is set
2. Verify the key is correct from dev.facetec.com
3. Check internet connection

### Native SDK Not Found

**Problem**: "No implementation found for method initialize"

**Solution**:
1. Verify native SDK files are in correct locations
2. Ensure native platform code (MainActivity/AppDelegate) is properly integrated
3. Clean and rebuild: `flutter clean && flutter run`

### Camera Permission Denied

**Problem**: Liveness check doesn't start

**Solution**:
1. Verify permissions in AndroidManifest.xml / Info.plist
2. Check user granted camera permission
3. Test on physical device (not emulator)

### Session Processing Fails

**Problem**: "Catastrophic network error"

**Solution**:
1. Check internet connection
2. Verify FaceTec API URL is correct
3. Check server logs if using custom backend
4. Ensure device key is valid

## Production Considerations

### 1. Backend Integration

For production, you **must** use your own backend middleware:

```dart
// Change baseURL to your backend
static const String baseURL = "https://yourserver.com/api/facetec";
```

Your backend should:
- Receive session requests from your app
- Forward to FaceTec Server API
- Return response blobs to your app
- Store verification results
- Implement security measures

### 2. Security

**Do NOT** in production:
- Include device key in client code (use server-side)
- Call FaceTec API directly from app
- Store biometric data unnecessarily
- Skip server-side verification

### 3. License

FaceTec requires a production license for:
- Removing watermarks
- Higher API limits
- Production support

Contact FaceTec for pricing and licensing.

### 4. Compliance

Ensure compliance with:
- GDPR (data protection)
- BIPA (biometric data laws)
- Local privacy regulations
- Terms of service

## Advanced Configuration

### Custom UI Theme

Customize FaceTec UI in native code:

**Android** (MainActivity.java):
```java
FaceTecCustomization ftCustomization = new FaceTecCustomization();
ftCustomization.getOverlayCustomization().brandingImage = R.drawable.your_logo;
ftCustomization.getFrameCustomization().backgroundColor = Color.parseColor("#FFFFFF");
FaceTecSDK.setCustomization(ftCustomization);
```

**iOS** (AppDelegate.swift):
```swift
let ftCustomization = FaceTecCustomization()
ftCustomization.overlayCustomization.brandingImage = UIImage(named: "your_logo")
ftCustomization.frameCustomization.backgroundColor = UIColor.white
FaceTec.sdk.setCustomization(ftCustomization)
```

### Match Threshold

Adjust in `facetec_capture_screen.dart`:

```dart
const threshold = 0.75; // 75% - adjust based on security needs
// Higher threshold = more secure, more false rejections
// Lower threshold = less secure, fewer false rejections
```

### Timeout Configuration

Add timeout to session processing:

```dart
await _channel.invokeMethod("startLivenessCheck")
    .timeout(Duration(seconds: 60));
```

## Additional Resources

- **FaceTec Developer Portal**: https://dev.facetec.com
- **FaceTec Documentation**: https://dev.facetec.com/docs
- **Security Best Practices**: https://dev.facetec.com/security-best-practices
- **Sample App**: FaceTec-Android-iOS-SDK-Flutter folder

## Support

For issues specific to:
- **FaceTec SDK**: Contact FaceTec support
- **vcmrtd Integration**: Check project issues on GitHub
- **Flutter**: Flutter documentation and community

## Next Steps

1. **Test the Implementation**: Run the app on physical devices
2. **Compare with Regula**: Use the provider switcher to compare
3. **Evaluate**: Determine which provider best fits your needs
4. **Production Setup**: Set up backend and licensing
5. **Deploy**: Follow platform deployment guidelines

## Notes

- This implementation is based on FaceTec SDK sample app from dev.facetec.com
- The match scoring is currently simulated for demonstration
- Full integration requires native platform code completion
- Server-side implementation is required for production use
- Contact FaceTec for production licensing and support
