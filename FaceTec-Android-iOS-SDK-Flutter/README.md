# flutter_facetec_sample_app

This project is a starting point for a Flutter Application using the native Android and iOS FaceTec SDK. It is by no means an exhaustive or complete implementation and is only meant as an initial guide.

## Running the App

**NOTE:** Before running the Sample App, you must first set the config values in facetec_config.dart.

This application uses modules, such as HTTP, that are a third party to Flutter's internal libraries. As such, make sure to run `flutter packages get` before running the code.

- **Android:**
  - Place the facetec*.aar file in '/android/apps/libs' directory in project.
  - If you do not know how to run a Flutter App, see <https://docs.flutter.dev/get-started/test-drive> for instructions.
- **iOS:**
  - Place FaceTecSDK.xcframework in '/ios' directory in project.
  - If you do not know how to run a Flutter App, see <https://docs.flutter.dev/get-started/test-drive> for instructions.
