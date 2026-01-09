# How to Enable FaceTec After Installing SDK Files

The FaceTec code has been temporarily commented out to allow the app to build without the SDK files. Follow these steps to enable it after installing the SDK.

## Step 1: Install FaceTec SDK Files

### Android
```bash
# Copy the .aar file to libs directory
cp /path/to/facetec-sdk-android-*.aar example/android/app/libs/
```

### iOS
```bash
# Copy the xcframework to iOS directory
cp -r /path/to/FaceTecSDK.xcframework example/ios/

# Then open Xcode and add the framework:
# 1. Open example/ios/Runner.xcworkspace in Xcode
# 2. Add FaceTecSDK.xcframework to project
# 3. Set to "Embed & Sign"
```

## Step 2: Enable Android FaceTec Code

Edit `example/android/app/src/main/kotlin/app/yivi/vcmrtd/MainActivity.kt`:

### 2.1 Uncomment imports (line ~12-13)
```kotlin
// BEFORE:
// import com.facetec.sdk.*

// AFTER:
import com.facetec.sdk.*
```

### 2.2 Add FaceTecSessionRequestProcessor to class (line ~15)
```kotlin
// BEFORE:
class MainActivity : FlutterActivity() { // REMOVE ", FaceTecSessionRequestProcessor" AFTER INSTALLING SDK

// AFTER:
class MainActivity : FlutterActivity(), FaceTecSessionRequestProcessor {
```

### 2.3 Uncomment FaceTec properties (lines ~18-23)
```kotlin
// BEFORE:
    // private var faceTecSDKInstance: FaceTecSDKInstance? = null
    // private var latestExternalDatabaseRefID: String = ""
    // private var processorChannel: MethodChannel? = null
    // private var initializeResultCallback: MethodChannel.Result? = null
    // private var requestCallback: FaceTecSessionRequestProcessor.Callback? = null

// AFTER:
    private var faceTecSDKInstance: FaceTecSDKInstance? = null
    private var latestExternalDatabaseRefID: String = ""
    private var processorChannel: MethodChannel? = null
    private var initializeResultCallback: MethodChannel.Result? = null
    private var requestCallback: FaceTecSessionRequestProcessor.Callback? = null
```

### 2.4 Uncomment FaceTec channel setup (lines ~54-66)
```kotlin
// BEFORE:
        // Setup FaceTec channels - UNCOMMENT AFTER INSTALLING SDK
        /*
        val faceTecSDKChannel = MethodChannel(...)
        ...
        */

// AFTER:
        // Setup FaceTec channels
        val faceTecSDKChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACETEC_CHANNEL)
        processorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACETEC_PROCESSOR_CHANNEL)

        faceTecSDKChannel.setMethodCallHandler { call, result ->
            receivedFaceTecSDKMethodCall(call, result)
        }

        processorChannel?.setMethodCallHandler { call, result ->
            receivedLivenessCheckProcessorCall(call, result)
        }
```

### 2.5 Uncomment all FaceTec methods (line ~76 to end)
Remove the `/*` at line ~77 and `*/` at line ~199 to uncomment all FaceTec methods.

## Step 3: Enable iOS FaceTec Code

Edit `example/ios/Runner/AppDelegate.swift`:

### 3.1 Uncomment FaceTec import (line ~3)
```swift
// BEFORE:
// UNCOMMENT AFTER INSTALLING SDK: import FaceTecSDK

// AFTER:
import FaceTecSDK
```

### 3.2 Add protocols to class (line ~6)
```swift
// BEFORE:
@objc class AppDelegate: FlutterAppDelegate { // ADD ", FaceTecInitializeCallback, FaceTecSessionRequestProcessor, URLSessionDelegate" AFTER INSTALLING SDK

// AFTER:
@objc class AppDelegate: FlutterAppDelegate, FaceTecInitializeCallback, FaceTecSessionRequestProcessor, URLSessionDelegate {
```

### 3.3 Uncomment FaceTec properties (lines ~8-17)
```swift
// BEFORE:
    // FaceTec properties - UNCOMMENT AFTER INSTALLING SDK
    /*
    private var requestCallback: FaceTecSessionRequestProcessorCallback!
    ...
    */

// AFTER:
    // FaceTec properties
    private var requestCallback: FaceTecSessionRequestProcessorCallback!
    var latestExternalDatabaseRefID: String = ""
    var faceTecSDKInstance: FaceTecSDKInstance?
    var flutterEngine: FlutterEngine?
    var processorChannel: FlutterMethodChannel?
    var controller: FlutterViewController?
    private var flutterInitializeResultCallback: FlutterResult?
```

### 3.4 Uncomment controller assignment (line ~31)
```swift
// BEFORE:
        // UNCOMMENT AFTER INSTALLING SDK
        // self.controller = controller

// AFTER:
        self.controller = controller
```

### 3.5 Uncomment FaceTec channel setup (lines ~35-42)
```swift
// BEFORE:
        // Setup FaceTec channels - UNCOMMENT AFTER INSTALLING SDK
        /*
        let faceTecSDKChannel = FlutterMethodChannel(...)
        ...
        */

// AFTER:
        // Setup FaceTec channels
        let faceTecSDKChannel = FlutterMethodChannel(name: "com.facetec.sdk", binaryMessenger: controller.binaryMessenger)
        self.processorChannel = FlutterMethodChannel(name: "com.facetec.sdk/livenesscheck", binaryMessenger: controller.binaryMessenger)

        faceTecSDKChannel.setMethodCallHandler(receivedFaceTecSDKMethodCall(call:result:))
        self.processorChannel!.setMethodCallHandler(receivedLivenessCheckProcessorCall(call:result:))
```

### 3.6 Uncomment all FaceTec methods (line ~81 to end)
Remove the `/*` at line ~82 and `*/` at line ~223 to uncomment all FaceTec methods.

## Step 4: Test the Build

```bash
cd example

# Clean
flutter clean
flutter pub get

# Build and test
flutter build apk        # Android
flutter build ios        # iOS (on Mac)

# Or run directly
flutter run
```

## Quick Verification Checklist

### Android
- [ ] `import com.facetec.sdk.*` uncommented
- [ ] `MainActivity : FlutterActivity(), FaceTecSessionRequestProcessor` updated
- [ ] FaceTec properties uncommented
- [ ] FaceTec channel setup uncommented
- [ ] All FaceTec methods uncommented (remove /* and */)
- [ ] SDK .aar file in `android/app/libs/`

### iOS
- [ ] `import FaceTecSDK` uncommented
- [ ] `AppDelegate: FlutterAppDelegate, FaceTecInitializeCallback, FaceTecSessionRequestProcessor, URLSessionDelegate` updated
- [ ] FaceTec properties uncommented
- [ ] `self.controller = controller` uncommented
- [ ] FaceTec channel setup uncommented
- [ ] All FaceTec methods uncommented (remove /* and */)
- [ ] SDK .xcframework in `ios/` directory
- [ ] Framework added to Xcode project with "Embed & Sign"

## Troubleshooting

**Still getting "Unresolved reference" errors on Android?**
- Verify the .aar file is in `android/app/libs/`
- Run `flutter clean` and rebuild
- Check that you uncommented the import statement

**Still getting errors on iOS?**
- Verify FaceTecSDK.xcframework is in `ios/` directory
- Make sure you added it to Xcode project
- Check that "Embed & Sign" is selected
- Run `flutter clean` and rebuild

**Build succeeds but FaceTec doesn't work?**
- Check that device key is configured in `lib/facetec_config.dart`
- Check internet connection (required for first init)
- Check logs for initialization errors

## Alternative: Use Find & Replace

You can use your IDE's find and replace to quickly uncomment all sections:

### Android (MainActivity.kt)
1. Find: `// import com.facetec.sdk.*` → Replace with: `import com.facetec.sdk.*`
2. Find: `, FaceTecSessionRequestProcessor {` (update class declaration manually)
3. Find: `    // private var faceTecSDKInstance` → Replace with: `    private var faceTecSDKInstance`
4. Find: `    // private var latestExternalDatabaseRefID` → Replace with: `    private var latestExternalDatabaseRefID`
5. Find: `    // private var processorChannel` → Replace with: `    private var processorChannel`
6. Find: `    // private var initializeResultCallback` → Replace with: `    private var initializeResultCallback`
7. Find: `    // private var requestCallback` → Replace with: `    private var requestCallback`
8. Remove the `/*` and `*/` comment blocks

### iOS (AppDelegate.swift)
1. Find: `// UNCOMMENT AFTER INSTALLING SDK: import FaceTecSDK` → Replace with: `import FaceTecSDK`
2. Update class declaration manually to add protocols
3. Remove the `/*` and `*/` around properties
4. Find: `// self.controller = controller` → Replace with: `self.controller = controller`
5. Remove the `/*` and `*/` around channel setup
6. Remove the `/*` and `*/` around all FaceTec methods

---

After completing these steps, FaceTec will be fully enabled and you can test the 3D liveness functionality!
