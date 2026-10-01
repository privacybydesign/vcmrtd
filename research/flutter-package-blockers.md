# What blocks packaging the flow as a Flutter package?

Research for [#213](https://github.com/privacybydesign/vcmrtd/issues/213), part of [#206](https://github.com/privacybydesign/vcmrtd/issues/206).

The question: what stops the verification flow that `idem` runs today (QR or deep link, MRZ scan, NFC chip read, face check, submission) from shipping as a Flutter package that a relying party's host app depends on?

All local code references are to `master` at `2c3d9c4`. The resolved dependency versions come from `idem/pubspec.lock`.

## Short answer

Most of this is ordinary engineering work. Three things are not:

1. **Our own licence.** `vcmrtd`, `mrz_capture` and `face_verification` are GPLv3 (`LICENSE`, `vcmrtd/LICENSE`, `mrz_capture/LICENSE`, `face_verification/LICENSE`). Under the GPL, a host app that links them must be GPL as a whole. A proprietary host app can't meet that. The FSF also treats App Store distribution terms as incompatible with the GPL.
2. **Vendor terms for the two face engines.** The Regula native binaries are "commercial, all rights reserved". The Iris SDK terms grant a "non-transferable" right. Neither vendor publishes terms that let us pass the SDK on to a third party's app. Both need a conversation with the vendor.
3. **Training-data terms on the bundled face models.** Nobody has recorded where the tflite models came from. At least one of them (GhostFaceNet) comes from a family trained on MS1MV2 or MS1MV3, and InsightFace releases those datasets, and the models trained on them, for non-commercial research only.

The rest is work: the native code lives in the runner rather than in plugins, the deep-link setup is tied to our domains, iOS needs extra Podfile setup, and the version pins are tight.

## 1. Licences

### 1.1 Our own code: GPLv3

| Package | Licence |
|---|---|
| repo root, `vcmrtd`, `mrz_capture`, `face_verification` | GPL-3.0 (`*/LICENSE`) |
| `idem` | no `LICENSE` file of its own (the repo root applies) |
| `iris_sdk_flutter` (our wrapper repo) | no `LICENSE` file at all (checked at `c02e1db`) |

- The GPL FAQ says that if a program links a GPL library, "the terms of the GPL apply to the entire combination", and that "the work as a whole must be licensed under the GPL" ([GPL FAQ #IfLibraryIsGPL](https://www.gnu.org/licenses/gpl-faq.html#IfLibraryIsGPL)). A Dart package compiled into a host app is linked in this sense.
- Linking GPL code to a non-system proprietary library needs an explicit linking exception from the copyright holders ([GPL FAQ #GPLIncompatibleLibs](https://www.gnu.org/licenses/gpl-faq.html#GPLIncompatibleLibs)). The flow links the Regula FaceSDK and the Iris `PassportReader` binaries, and neither is a system library. This problem exists in `idem` today too, but there we are both the GPL licensor and the distributor. In a host app, the relying party is the distributor.
- The FSF considers App Store terms of service to be in conflict with the GPL's distribution requirements ([FSF, 2010](https://www.fsf.org/news/2010-05-app-store-compliance)).

**What it takes:** relicense the packages a host app would depend on (for example to MIT, Apache-2.0, or LGPL plus a static-linking exception), or dual-license them. That needs agreement from every copyright holder of those packages. The repo has no CLA, so we would have to check who those holders are. **Hard (legal).** It's under our control, but it isn't an engineering task.

### 1.2 Regula Face SDK (`flutter_face_api`, `flutter_face_core_basic`)

- The Dart and plugin wrappers are MIT (`flutter_face_api-8.3.1291/LICENSE`, `flutter_face_core_basic-8.3.635/LICENSE`).
- The native SDK they pull in is not MIT. The iOS pod `FaceSDK 8.3.4727` declares `type: 'commercial'`, "© 2026 RegulaForensics. All rights reserved." ([regulaforensics/podspecs](https://github.com/regulaforensics/podspecs/blob/master/FaceSDK/8.3.4727/FaceSDK.podspec)). On Android it comes from `com.regula.face:api` and `com.regula.face.core:basic`, which are hosted on `maven.regulaforensics.com`.
- **Licence binding.** Regula has two licence types. An ML (mobile, offline) licence file lists the "licensed application ID/bundle ID (can be multiple in one license)". An OL (online) licence calls Regula's licensing service ([Face SDK licensing](https://docs.regulaforensics.com/develop/face-sdk/overview/licensing/)).
- **How `idem` uses it.** `idem` initialises Core Basic with no licence file and sets `serviceUrl` to our Face API (`idem/lib/services/regula_face_service.dart`, `defaultServiceUrl = 'https://faceapi.staging.yivi.app'`). Regula documents that Core Basic needs no licence file ([initialization](https://docs.regulaforensics.com/develop/face-sdk/mobile/getting-started/initialization/)). Liveness is assessed on the web service, and the web service is the part that needs a licence ([architecture](https://docs.regulaforensics.com/develop/face-sdk/overview/architecture/)). **So the device-side licence is not bound to our bundle id today. The licence sits on our Face API server.**
- **What a host app would need:**
  - Either the host app keeps calling *our* Face API, and our Regula contract has to allow end users of third-party apps to use it, or the relying party gets its own Regula web-service licence and runs its own Face API. The public docs don't answer whether our contract allows the first option. Check the contract.
  - Either way, the host app ships Regula's commercial native binary. Regula's public pages don't publish redistribution terms. Its support pages point to the Client Portal and to sales ([pricing and licensing models](https://support.regulaforensics.com/hc/en-us/articles/360036943712-Pricing-SDK-Licensing-Models)). Ask Regula.
  - If we ever move to Core Match (on-device matching), an ML licence is bound to bundle ids. Each host app's ids would then have to be added to a licence, or the relying party would need its own.

**Hard (licensing),** until Regula confirms in writing.

### 1.3 Iris SDK (`iris_sdk_flutter`, vendor binary `PassportReader`)

- Our wrapper repo commits the vendor's `PassportReader.aar` and `PassportReader.xcframework` (about 49 MB) and has no `LICENSE` file (`iris-sdk-flutter` README, "Updating the SDK").
- The vendor's terms grant "a revocable, non-exclusive, non-transferable, limited right to install and use relevant Services on devices owned or controlled by you". They also say the app licence "is non-transferable" ([passportreader.app/terms](https://passportreader.app/terms)). Nothing in them covers sublicensing to third-party apps.
- **Licence binding.** The documented integration authenticates with a public key and secret on a backend and passes a per-session token to the SDK ([integration guide](https://passportreader.app/integration-guide), [Android guide](https://passportreader.app/android-integration-guide)). The documents never mention bundle ids. Our wrapper calls `startFaceVerification(container, portrait, handler)` with no key or token at all (`IrisFaceVerificationActivity.kt`), and the vendor's guides don't document that method. The native library does contain `getPackageName`, a `status expired` string and an `appspot.com` endpoint (from running `strings` on `jni/arm64-v8a/libPassportReader.so` and `classes.jar`). That suggests some check tied to the package name or to time. **This is an inference from the binary, not documented behaviour.** Ask the vendor whether the face-only call is metered or locked to an app id, and whether it works in an app that isn't ours.
- **What a host app would need:** most likely its own passportreader.app account (billing is per verification and monthly, per the terms), plus permission from the vendor to use the binaries our repo distributes. **Hard (licensing).**

### 1.4 Google ML Kit (`google_mlkit_text_recognition`, `google_mlkit_barcode_scanning`)

- The plugin wrappers are MIT and community-maintained ("not sponsored or maintained by Google", [pub.dev](https://pub.dev/packages/google_mlkit_text_recognition)).
- The ML Kit terms need no API key and no Firebase project, and don't bind to an app id. Image processing happens on the device. The APIs do send usage metrics to Google, and "You are responsible for informing users of your app about Google's processing of ML Kit metrics data" ([ML Kit terms](https://developers.google.com/ml-kit/terms)).
- **What a host app would need:** nothing it has to obtain. It does need to declare the ML Kit metrics in its own privacy policy, Play Data Safety form and App Store privacy label. **Just work.**

### 1.5 Bundled tflite models (`face_verification/lib/src/models`)

Nothing in the repo says where these models came from. No README, NOTICE or commit message records it, and the files arrived in `db2c221` and `ddfb16d` without attribution. Matching them by name and by embedded strings:

| File | Probable upstream | Code licence | Concern |
|---|---|---|---|
| `face_detector`, `face_landmarks_detector`, `face_blendshapes` | MediaPipe Face Landmarker (the files contain the string `MediaPipe`) | Apache-2.0 ([google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe)) | Needs attribution only |
| `minifasnet_v1se`, `minifasnet_v2` | [minivision-ai/Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing) | Apache-2.0 | Needs attribution only |
| `bigsmall_1..3` | [girishvn/BigSmall](https://github.com/girishvn/BigSmall) (MIT), "adapted from the rPPG-Toolbox" | MIT, but upstream rPPG-Toolbox is the Responsible AI Source Code License 1.1 ([licence](https://github.com/ubicomplab/rPPG-Toolbox/blob/main/LICENSE)) | Use restrictions under RAIL. The training dataset licence is unverified |
| `GhostFaceNet_fp32_V2` | [HamadYA/GhostFaceNets](https://github.com/HamadYA/GhostFaceNets) (MIT code). The file's graph is named `GhostNet_fp32_4d_output` | MIT code, but the published weights are trained on MS1MV2 or MS1MV3 | InsightFace: "The training data ... (and the models trained with these data) are available for non-commercial research purposes only" ([insightface README](https://github.com/deepinsight/insightface#license)) |

**What a host app would need:** nothing it can obtain. We have to establish provenance first. If the face-recognition weights do derive from MS1M, putting them in a commercial host app is not allowed, and we would need to retrain or replace that model. **Hard (licensing)** until the provenance is known.

## 2. Native code and manifest entries a host app would have to provide

The runner (`idem/ios/Runner`, `idem/android/app/src/main`) registers three things by hand. They are not Flutter plugins, so a host app doesn't get them when it adds a pub dependency.

| Runner code | Channel | Who calls it from Dart | What a host app would have to do |
|---|---|---|---|
| `ImageDecodeChannel` (`AppDelegate.swift`, `MainActivity.kt` + `ImageUtil.kt`) | `image_channel` / `decodeImage` | **`face_verification`** (`face_verification_engine.dart:33`), plus `idem` screens and `jpeg2000_converter.dart` | Copy the channel in. On Android also add `com.gemalto.jp2:jp2-android:1.0.3` (BSD-2-Clause, [ThalesGroup/JP2ForAndroid](https://github.com/ThalesGroup/JP2ForAndroid)). Without it, `face_verification` can't decode the JPEG 2000 chip photo, although its pubspec calls it a "standalone package". |
| `ProofingDeepLinkPlugin` | `proofing_deeplink` (`getInitialLink`, `onLink`) | `idem/lib/main.dart` | Copy it in, and register both the UIApplication and the UIScene callbacks. |
| `DeepLinkPlugin` | `deep_link_handler` | **nothing in `idem/lib`** (grep finds no Dart caller) | Nothing. On `master` this code is dead and could be deleted. |

All three are easy to move into a real federated plugin (a `flutter: plugin:` section with an `ios`/`android` `pluginClass`), the way `mrz_capture` already does for `TesseractOcrPlugin`. **Just work.**

### iOS: Info.plist, entitlements, Podfile

The host app needs the following (from `idem/ios/Runner/Info.plist`, `Runner.entitlements` and `Podfile`):

- `NFCReaderUsageDescription`, `NSCameraUsageDescription`.
- `com.apple.developer.nfc.readersession.iso7816.select-identifiers` with the five AIDs listed in `Info.plist`. The eMRTD AID `A0000002471001` is the one the Iris SDK guide also asks for ([iOS guide](https://passportreader.app/ios-integration-guide)).
- The entitlement `com.apple.developer.nfc.readersession.formats = [TAG]`. This means the **relying party has to enable NFC Tag Reading on its own App ID** in its Apple developer account. Only the relying party can do that. It's routine, but it's a step they own.
- Podfile:
  - `platform :ios, '16.0'` (the Iris xcframework's `MinimumOSVersion` is 16.0).
  - `source 'https://github.com/regulaforensics/podspecs.git'` next to the CDN trunk, because the current FaceSDK and FaceCoreBasic pods are only in Regula's spec repo.
  - The `mlkit_apple_silicon_simulator_patch` post-install hook, or the host app can't build for an arm64 simulator.
  - No extra `TensorFlowLiteC` pod (it collides with `flutter_litert`).
- Simulator builds: the Iris xcframework has no x86_64 simulator slice.
- **Conflicts with the host app's own setup:**
  - `FlutterDeepLinkingEnabled = false`. `idem` turns off Flutter's built-in deep linking because it sends `vcmrtd://` URLs to go_router. A host app that relies on Flutter deep linking can't simply copy this. The package's plugin would have to claim only its own URLs, which the UIScene delegate already does by returning `false` for other URLs. The host app's router would also have to ignore those URLs.
  - The `CFBundleURLSchemes` `vcmrtd` and `mrtd`, and an `https` scheme entry that has no effect.
  - `com.apple.developer.associated-domains = applinks:passport-issuer.yivi.app`. A universal link only works if the domain's `apple-app-site-association` file lists the host app's team id and bundle id. See section 2.3.

### Android: manifest and Gradle

- Permissions **are merged in automatically** from plugin manifests. `android.permission.NFC` comes from the `flutter_nfc_kit` fork. `CAMERA` and `RECORD_AUDIO` come from `camera_android_camerax`. `INTERNET`, `VIBRATE`, `CAMERA` and `NFC`, plus `uses-feature android.hardware.camera` and `android.hardware.nfc`, come from the Iris AAR (checked in the unpacked `PassportReader.aar` manifest). The Iris `uses-feature` entries default to `required="true"`, which hides the host app on Google Play from devices without NFC. A host app that doesn't want that has to override them with `tools:replace` (see the `iris-sdk-flutter` README).
- The host app must add the activity entries itself:
  - `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>`. This conflicts the same way as on iOS.
  - The `vcmrtd://` `VIEW` intent filter.
  - The `https://passport-issuer.yivi.app/start-app` App Link with `autoVerify`. It only verifies if that domain's `assetlinks.json` lists the host app's package name and signing certificate.
  - `onNewIntent` forwarding to both deep-link plugins. A real plugin would use `ActivityPluginBinding.addOnNewIntentListener` instead.
- Gradle: `minSdk 26`, `compileSdk 36`, Java 17 (`idem/android/app/build.gradle`). The Iris SDK is "built with Java 17 and compile/target SDK 36" ([Android guide](https://passportreader.app/android-integration-guide)). Regula's plugins add `maven.regulaforensics.com` as a project-level repository. A host app that sets `dependencyResolutionManagement { repositoriesMode = FAIL_ON_PROJECT_REPOS }` has to add that repository in `settings.gradle` itself.

### 2.3 Deep links are tied to our identity

The deep-link design assumes there is one app. That's the biggest native issue that isn't purely mechanical:

- `vcmrtd://` is a custom scheme. If two host apps on one device both register it, Android shows a chooser, and on iOS it's undefined which app opens the link. A relying party's session QR or link could end up opening another relying party's app.
- The App Link and universal link on `passport-issuer.yivi.app` can serve several apps only if we add every host app's ids to that domain's association files. The alternative is that each relying party serves the links from its own domain.

The package should let the host app inject the scheme or host, and the session backend should issue links per relying party. **Work, plus a design decision** about who owns link domains.

## 3. Platform gaps

- **`mrz_capture` on iOS** uses Google ML Kit only. `OcrEngine.tesseract4android` "is Android-only: on iOS the scanner falls back to `googleMlKit`" (`mrz_capture/lib/src/ocr_engine.dart`, `mrz_scanner.dart:120-130`). The package has no `ios/` directory and declares only an Android `pluginClass`. So iOS has no free-software OCR path. The flow works on iOS, but only through Google's closed binary.
- **ML Kit is a hard dependency on both platforms.** `mrz_capture` and `idem` depend on `google_mlkit_text_recognition` and `google_mlkit_barcode_scanning` with no conditions. A host app that wants to avoid Google binaries, as an F-Droid build would, can't drop them. On Android, both OCR engines ship either way: Tesseract4Android 4.9.0 plus OpenCV 4.9.0 (`mrz_capture/android/build.gradle`) *and* ML Kit. That adds APK size.
- **Size.** `face_verification` bundles about 33 MB of tflite models (GhostFaceNet alone is 16 MB). The Iris binaries add about 49 MB in the repo. Every host app pays for both, even if it only uses one face engine, because the engine choice is made at runtime in `idem/lib/routing.dart`. They would need to be split into separate packages.
- **Simulators.** iOS needs the ML Kit arm64 simulator patch, and Iris has no Intel simulator slice (see the Podfile notes above).

## 4. Dependency conflicts with a typical host app

| Dependency | Constraint we impose | Why it clashes |
|---|---|---|
| `flutter_nfc_kit` | git fork `privacybydesign/flutter_nfc_kit@v3.7.0` (MIT). The fork is 3 commits ahead and 1 behind upstream `nfcim/flutter_nfc_kit`, and adds `extraReaderPresenceCheckDelay` to `poll()` on Android | It has the same package name as the pub.dev package. If a host app (or any of its dependencies) uses pub.dev `flutter_nfc_kit`, pub reports a source conflict, and the host app has to add a `dependency_overrides` entry pointing at our fork. Fix: upstream the presence-check change, or publish the fork under its own name. |
| `pointycastle` | git fork `privacybydesign/pc-dart@master`, as a **direct dependency** of `vcmrtd`. It also appears under `dependency_overrides` | Many crypto packages pull `pointycastle` from pub.dev transitively (asn1, JWT, x509 libraries), so this is the conflict a host app is most likely to hit. Our `dependency_overrides` don't help: "Dependency overrides inside any depended-on packages are ignored" ([dart.dev](https://dart.dev/tools/pub/dependencies#dependency-overrides)). It also pins an unversioned `master` branch. |
| `mrz_parser`, `iris_sdk_flutter` | git dependencies | Together with the two above, these mean **`vcmrtd`, `mrz_capture` and `idem` can't be published to pub.dev**. Published packages must "depend only on hosted dependencies from the default pub package server" ([dart.dev publishing](https://dart.dev/tools/pub/publishing)). Host apps would have to use git dependencies. |
| `flutter_riverpod` | `^3.2.0`, and part of `vcmrtd`'s **public API**: `DocumentReader extends Notifier<DocumentReaderState>` (`vcmrtd/lib/src/document_reader.dart:32`) | A host app on Riverpod 2.x can't resolve. A host app on Bloc or Provider has to add a `ProviderScope` only to read a document. The core reader shouldn't depend on a state-management library. |
| `go_router` | `^17.3.0` in `idem`, which also builds the app's top-level `GoRouter` and `MaterialApp.router` (`idem/lib/routing.dart`, `main.dart`) | A host app on go_router 13 to 16, or on auto_route or plain Navigator, conflicts. The flow has to be exposed as a self-contained widget (or a nested `Navigator`) with no app-level router. In `vcmrtd`, go_router is only a dev dependency, so the core package is clean. |
| Dart / Flutter SDK | The lockfile resolves to `dart >=3.12.0`, `flutter >=3.44.0`. That floor comes from `google_mlkit_text_recognition 0.17.1` and `google_mlkit_barcode_scanning 0.16.1`. CI pins Flutter 3.47.0 (`ci_scripts/install_flutter.sh`) | Host apps that lag behind on Flutter (many stay a few releases back) can't resolve. Our own pubspecs say `sdk: ^3.8.0`, which understates the real floor. Lowering it means lowering the ML Kit plugin versions. |
| `camera` | `^0.12.0` | A host app on `camera` 0.10 or 0.11 conflicts. Fix: widen the range. |
| `flutter_face_api` | `^8.2.1149`, resolved to 8.3.1291 | This is Regula's own versioning. A host app that already uses Regula's Document Reader has to keep the shared `RegulaCommon` pod in step. |
| `intl` | `^0.20.2` | `flutter_localizations` pins `intl` per Flutter SDK, so this follows the SDK floor above. |
| Platform minimums | iOS 16.0, Android `minSdk 26`, `compileSdk 36`, Java 17, AGP 8.13, Kotlin 2.3 | The Iris SDK sets iOS 16 and minSdk 26. A host app that supports iOS 15 or Android 7 (API 24/25) would have to raise its minimums. Without Iris, the floor would be iOS 15.5 (ML Kit) and minSdk 24 (Regula). |

## Blockers ranked by severity

1. **GPLv3 on `vcmrtd`, `mrz_capture` and `face_verification`.** Hard (legal). A proprietary host app can't link GPL code, and the GPL itself conflicts with linking Regula and Iris. Fix: relicense or dual-license. That needs every copyright holder to agree.
2. **Iris SDK terms are "non-transferable", and we redistribute the binaries.** Hard (licensing). Each relying party probably needs its own passportreader.app account, and the vendor has to say whether the undocumented `startFaceVerification` call is locked to an app id.
3. **Provenance of the face-model training data, especially GhostFaceNet (MS1M, non-commercial research only).** Hard (licensing). We have to document where the models came from, and replace or retrain any model we can't use commercially.
4. **Regula's native FaceSDK is commercial and its licence sits on our Face API.** Hard (licensing). Our contract has to allow serving third-party apps, or each relying party needs its own Regula web-service licence. An on-device ML licence would be bound to bundle ids.
5. **Git dependencies (`pointycastle`, `flutter_nfc_kit`, `mrz_parser`, `iris_sdk_flutter`).** Just work, but it blocks pub.dev publishing and gives host apps the `pointycastle` and `flutter_nfc_kit` source conflicts. Upstream the changes or rename the forks.
6. **Deep links tied to our identity** (`vcmrtd://`, `passport-issuer.yivi.app`, `FlutterDeepLinkingEnabled = false`). Work plus a design decision: per-relying-party schemes or domains, and plugins that claim only their own URLs.
7. **Native code in the runner** (`image_channel`, the deep-link plugins) instead of in plugins, which leaves `face_verification` incomplete without the runner. Just work: move it into federated plugins.
8. **Version floors.** Flutter ≥ 3.44, Dart ≥ 3.12, iOS 16, minSdk 26, go_router 17, Riverpod 3, camera 0.12. Just work: widen the ranges, take Riverpod out of `vcmrtd`'s public API, and ship the flow as a widget without an app router.
9. **Size and forced engines.** ML Kit, Tesseract and OpenCV, both face engines, and about 80 MB of models and binaries all ship to every host app. Just work: split the packages per engine.
10. **Host-side setup that only the relying party can do.** NFC Tag Reading on its App ID, the Regula pod source, privacy disclosures for ML Kit metrics. Just work, and documentation.

## Open questions for vendors and legal

- Regula: may our Face API web-service licence serve end users of third-party host apps? May a relying party redistribute FaceSDK and FaceCoreBasic in its app under our agreement, or does it need its own?
- passportreader.app: is `startFaceVerification` metered, and is it locked to a package name or bundle id? May our wrapper repo redistribute the binaries to relying parties?
- Copyright holders of `vcmrtd`, `mrz_capture` and `face_verification`: would they agree to relicense?
- Where did each tflite model in `face_verification/lib/src/models` come from, and what were they trained on?
