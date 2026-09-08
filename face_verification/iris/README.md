# face_verification_iris

Face verification via the vendor **Iris SDK** (passportreader.app) — an
alternate engine alongside [`face_verification`](../face_verification), not
part of its pipeline. Pick one or the other at the call site; nothing in
either package depends on the other.

| | `face_verification` | `face_verification_iris` |
|---|---|---|
| Pipeline | On-device, pure Dart/TFLite, headless (feed frames, read an event stream) | Vendor native SDK, owns its own full-screen camera UI |
| Liveness | Active (gestures) + passive (anti-spoof, rPPG) | Whatever the Iris SDK does internally — opaque to us |
| Native footprint | FFI to bundled `.tflite` models | Prebuilt vendor binaries (`iris.aar`, `Iris.xcframework`) |

## Getting the SDK binaries

`iris.aar` and `Iris.xcframework` are proprietary binaries shared privately
by the vendor — not committed to this public repository (see `.gitignore`).
Get your own copy and place it here before building:

- Android: `android/libs/iris.aar`
- iOS: `ios/Iris.xcframework` (the unzipped framework directory)

## Dart API

```dart
import 'package:face_verification_iris/face_verification_iris.dart';

final verifier = IrisFaceVerifier();
final result = await verifier.verify(portraitPng); // PNG bytes, e.g. the NFC DG2 photo

switch (result.outcome) {
  case IrisVerificationOutcome.matched:
    // result.face holds the captured live face crop.
  case IrisVerificationOutcome.failed:
  case IrisVerificationOutcome.cancelled:
}
```

`verify()` presents a full-screen native flow (the Iris SDK drives its own
camera UI) and resolves once the user completes, fails, or cancels it —
there's no per-frame event stream to hook into, unlike `face_verification`'s
`FaceVerificationEngine`.

## Status / what's verified vs. inferred

- **Android**: verified against the decompiled `iris.aar` — `Iris(Activity)`,
  `startFaceVerification(ViewGroup, byte[], StartFaceVerificationHandler)`,
  permissions/native libs merge in automatically from the aar's own manifest.
- **iOS**: the Swift call in `FaceVerificationIrisPlugin.swift` is inferred
  from the vendor's Objective-C header
  (`-startFaceVerificationInWindowScene:portrait:completion:failure:cancellation:`)
  via standard Clang-importer naming rules — not yet built against a real
  Xcode toolchain. Verify the inferred Swift signature once the framework is
  vendored in.

## Not yet wired into the app

This package is self-contained but not yet consumed anywhere. Wiring it into
`vcmrtd/example` still needs, at minimum:

- **Android**: `vcmrtd/example/android/settings.gradle.kts` needs a `flatDir`
  repository pointing at `../../face_verification_iris/android/libs` — this
  package's own `build.gradle` intentionally does *not* declare one, since
  modern Flutter/AGP centralizes repository resolution in the app's
  `settings.gradle` (`RepositoriesMode.FAIL_ON_PROJECT_REPOS`), and a
  plugin module declaring its own `repositories {}` block would break that.
- **iOS**: the example app's `Podfile`/`Runner.xcodeproj` needs to pick up
  this pod (standard Flutter plugin resolution should handle this once it's
  a `pubspec.yaml` dependency of the example app).
- **App code**: a call site choosing between `FaceVerificationEngine`
  (`face_verification`) and `IrisFaceVerifier` (this package).

## Related packages

- [`face_verification`](../face_verification) — the existing on-device engine
- [`vcmrtd`](../vcmrtd) — NFC reading and document parsing
