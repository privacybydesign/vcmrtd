[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Technical Debt](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_index)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![codecov](https://codecov.io/gh/privacybydesign/vcmrtd/graph/badge.svg)](https://codecov.io/gh/privacybydesign/vcmrtd)

# face_verification

A Flutter package for face verification and liveness detection. Supports both active liveness (gesture-based) and passive liveness (anti-spoofing + rPPG heart rate), plus face matching against a reference photo from an NFC chip.

## Features

- **Active liveness** - detects gestures: blink, turn left/right, mouth open, smile
- **Passive liveness** - anti-spoofing (MiniFASNet) and heart rate detection (rPPG/BigSmall)
- **Face recognition** - 512-dim embeddings via GhostFaceNet, cosine similarity matching
- **NFC photo matching** - compare live selfie against a reference image from `vcmrtd`
- Runs in a background isolate - no UI
- All TFLite models bundled - no separate download needed

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  CAMERA (YUV420 / BGRA8888)                                                                 │
└─────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  MAIN ISOLATE — FaceVerificationEngine                                                      │
│                                                                                             │
│  processFrame() → writes frame into FFI buffer pool (10 × 12 MB, zero-copy)                 │
│  dispatches buffer to PIPELINE                                                              │
│                                                                                             │
│  holds session state: gestures requested/completed, liveness mode,                          │
│  alignment state, countdown timer                                                           │
│                                                                                             │
│  on FaceObservation received from PIPELINE:                                                 │
│                                                                                             │
│  ┌──────────────────────────────────────┐   ┌──────────────────────────────────────┐        │
│  │  ACTIVE mode                         │   │  PASSIVE mode                        │        │
│  │                                      │   │                                      │        │
│  │  reads blendshape scores             │   │  reads face position + orientation   │        │
│  │  checks against thresholds           │   │  emits align events:                 │        │
│  │  detects: blink / turn L+R /         │   │  tooFar / tooClose /                 │        │
│  │           mouth open / smile         │   │  lookStraight / holdStill            │        │
│  │  emits: nextAction /                 │   │  once locked: countdown timer        │        │
│  │         actionDetected               │   │  emits passiveProgress events        │        │
│  │  accumulates completed challenges    │   │                                      │        │
│  └──────────────────────────────────────┘   └──────────────────────────────────────┘        │
│                                                                                             │
│  mid-session (random frame): sends face crop to MATCH → consistency check                   │
│  session end: sends final face crop to MATCH → NFC comparison                               │
└───────────────┬─────────────────────────────────────────────────────────┬───────────────────┘
                │                                                         │
                │ dispatches FFI buffer                                   │ sends face crop
                │                                                         │ (mid-session +
                ▼                                                         │  session end)
┌───────────────────────────────┐                                         │
│  PIPELINE ISOLATE             │                                         │
│                               │                                         │
│  reads FFI buffer             │                                         │
│                               │                                         │
│  [1] Face detector            │                                         │
│       └─ bounding box         │                                         │
│                               │                                         │
│  [2] Landmark pipeline        │                                         │
│       ├─ 468 landmarks        │                                         │
│       ├─ blendshape scores    │                                         │
│       └─ aligned face crop    │                                         │
│                               │                                         │
│  → FaceObservation            │                                         │
│    sent to main isolate       │                                         │
│                               │                                         │
│  if face found:               │                                         │
│  buffer handoff to PASSIVE    │                                         │
│  (PIL_READING → PASS_READY)   │                                         │
│  does not free buffer         │                                         │
└───────┬───────────────┬───────┘                                         │
        │               │                                                 │
        │ FaceObser-    │ FFI buffer handoff                              │
        │ vation        │ + FaceObservation                               │
        │ (per frame)   │ (face region)                                   │
        │               ▼                                                 ▼
        │  ┌────────────────────────────┐             ┌───────────────────────────────┐
        │  │  PASSIVE ISOLATE           │             │  MATCH ISOLATE                │
        │  │                            │             │                               │
        │  │  receives FFI buffer       │             │  never reads FFI buffer       │
        │  │  + FaceObservation         │             │  receives face crop from      │
        │  │                            │             │  engine only                  │
        │  │  MiniFASNet                │             │                               │
        │  │  · anti-spoof score        │             │  GhostFaceNet                 │
        │  │                            │             │  · 512-dim face embedding     │
        │  │  BigSmall                  │             │  · cosine similarity          │
        │  │  · rPPG signal             │             │                               │
        │  │  · heart rate estimation   │             │  mid-session: store/compare   │
        │  │                            │             │  embedding → face-swap check  │
        │  │  both accumulate across    │             │                               │
        │  │  frames throughout session │             │  session end: compare against │
        │  │                            │             │  embedded NFC photo           │
        │  │  while PASSIVE handles     │             │                               │
        │  │  frame N, PIPELINE is      │             │  → match score                │
        │  │  already on frame N+1      │             │                               │
        │  └────────────┬───────────────┘             └───────────────┬───────────────┘
        │               │                                             │
        │               │ anti-spoof score                            │ match score
        │               │ rPPG / heart rate                           │
        ▼               ▼                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  MAIN ISOLATE — score fusion (session end)                                                  │
│                                                                                             │
│  complete event:                                                                            │
│  passed · matchScore · antiSpoofScore · antiSpoofPassed · consistencyFailed                 │
│  rppg { hr · passed · sampleCount · durationMs }                                            │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

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
import 'dart:async';
import 'package:face_verification/face_verification.dart';

final engine = FaceVerificationEngine();
await engine.initialize();

// Set up the event listener before calling start() — events fire as soon as frames arrive.
engine.events.listen((event) {
  switch (event['type']) {
    case 'align':
      // Tip to show the user while they position their face.
      // event['tip'] is one of:
      //   'noFace'       - no face detected
      //   'tooFar'       - face too small, move closer
      //   'tooClose'     - face too large, move back
      //   'centerFace'   - face off-center (passive mode)
      //   'lookStraight' - face turned too far
      //   'holdStill'    - waiting for face to settle
      //   'openEyes'     - eyes too closed
      //   'closeMouth'   - mouth too open at rest
      //   'relaxFace'    - smiling too much at rest
      print('Tip: ${event['tip']}');
    case 'nextAction':
      // Active mode only: the gesture the user must perform next.
      // event['action'] is one of: 'BLINK', 'TURN_LEFT', 'TURN_RIGHT', 'MOUTH_OPEN', 'SMILE'
      print('Perform: ${event['action']}');
    case 'actionDetected':
      // Active mode only: a gesture was successfully detected.
      print('Completed: ${event['action']}');
    case 'extraAction':
      // Active mode only: an extra challenge was added (triggered when the user barely passed).
      print('Extra challenge: ${event['action']}');
    case 'timeout':
      // Active mode only: the user did not perform the gesture in time; moving to next action.
      print('Timed out on: ${event['action']}');
    case 'passiveProgress':
      // Passive mode only: emitted every frame.
      // event['started']   (bool) - false during lock-on phase, true once countdown begins
      // event['elapsedMs'] (int)  - ms elapsed since countdown started
      // event['targetMs']  (int)  - total ms required
      final pct = (event['started'] as bool) ? (event['elapsedMs'] as int) / (event['targetMs'] as int) : 0.0;
      print('Passive progress: ${(pct * 100).round()}%');
    case 'processing':
      // Final scoring is running; stop feeding camera frames.
      print('Processing...');
    case 'complete':
      // event['passed']            (bool)    - overall pass/fail
      // event['matchScore']        (double)  - cosine similarity vs NFC photo (0–1); 0 if no NFC photo
      // event['antiSpoofScore']    (double?) - anti-spoof confidence score
      // event['antiSpoofPassed']   (bool)    - whether anti-spoof check passed
      // event['consistencyFailed'] (bool)    - true if a face-swap was detected mid-session
      // event['rppg']              (Map)     - rPPG heart-rate result:
      //   'hr'          (double?) - estimated heart rate in BPM
      //   'passed'      (bool)    - whether rPPG check passed
      //   'sampleCount' (int)     - number of frames used
      //   'durationMs'  (int)     - duration of the rPPG measurement in ms
      print('Passed: ${event['passed']}, score: ${event['matchScore']}');
    case 'error':
      print('Error: ${event['message']}');
  }
});

// Optional but recommended: embed the NFC photo in the background right after
// initialize(), so it is ready before the user taps Start.
if (nfcImageBytes != null && nfcImageBytes.isNotEmpty) {
  unawaited(engine.prepareNfcFaceEagerly(nfcImageBytes).catchError((_) {}));
}

// When the user taps Start:
final actions = await engine.start(
  nfcImageBytes,  // Uint8List from NFC chip; pass Uint8List(0) if unavailable (match score will be 0)
  mode: LivenessMode.active,
);
// actions is a List<String> of wire-name strings the user must perform,
// for example ['BLINK', 'TURN_LEFT', 'SMILE']

// Feed camera frames from your camera image stream callback:
engine.processFrame(cameraImage, rotationDegrees);

// Clean up when done:
await engine.dispose();
```

## Liveness modes

| Mode | Description |
|------|-------------|
| `LivenessMode.active` | User performs gesture challenges (blink, turn, smile, etc.). Anti-spoof and rPPG run in parallel. |
| `LivenessMode.passive` | User holds still for a fixed duration. Liveness is determined by anti-spoof and rPPG only. |

## Example app

A complete working implementation is included in the [`vcmrtd` example app](../vcmrtd/example). The relevant files are:

- [`lib/widgets/pages/face_verification_screen.dart`](../vcmrtd/example/lib/widgets/pages/face_verification_screen.dart) — full UI: camera preview, alignment coaching, gesture prompts, passive countdown, result display
- [`lib/widgets/pages/face_verification_entry_screen.dart`](../vcmrtd/example/lib/widgets/pages/face_verification_entry_screen.dart) — entry point that wires the engine to the screen

The example demonstrates:
- Initializing the engine and eagerly preparing the NFC photo
- Handling all event types (`align`, `nextAction`, `passiveProgress`, `complete`, etc.)
- Displaying alignment tips and gesture instructions with icons
- Rendering a passive liveness countdown progress bar
- Showing the final result with match score, anti-spoof score, and rPPG heart rate
- Age-adjusted match threshold (`faceMatchThreshold`) based on the passport photo issue date

To run it:

```sh
cd vcmrtd/example
flutter pub get
flutter run
```

## Related packages

- [`vcmrtd`](../vcmrtd) - NFC reading and document parsing for machine-readable travel documents
