# Example Application

The VCMRTD repository includes a complete example application demonstrating how to read and verify travel documents.

## Features

The example app demonstrates:

- **MRZ Scanning**: Camera-based OCR scanning of the Machine Readable Zone
- **Manual Entry**: Alternative input method for MRZ data
- **NFC Reading**: Full document reading with progress indication
- **Backend Integration**: Verification via go-passport-issuer
- **Credential Issuance**: Optional Verifiable Credential generation for Yivi

## Screenshots

| | | | | |
|:---:|:---:|:---:|:---:|:---:|
| <img src="/vcmrtd/images/home.jpg" width="150" /> | <img src="/vcmrtd/images/scan.jpg" width="150" /> | <img src="/vcmrtd/images/info.jpg" width="150" /> | <img src="/vcmrtd/images/read.jpg" width="150" /> | <img src="/vcmrtd/images/result.png" width="150" /> |
| Choose mode | MRZ scanning | NFC positioning | Reading | Results |

## Running the Example

### Prerequisites

- Dart SDK 3.8.0+ (Flutter 3.32.0+)
- A physical Android or iOS device with NFC
- A test passport or eID card

### Steps

1. Clone the repository:

```bash
git clone https://github.com/privacybydesign/vcmrtd.git
cd vcmrtd/example
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run on a connected device:

```bash
flutter run
```

:::note
The app must run on a physical device. NFC is not available in emulators or simulators.
:::

## Configuration

### Backend URL

By default, the example app connects to the Yivi staging server. To use a different backend, update the configuration in the app.

### Android Debug Keystore

For Android, ensure your debug keystore SHA256 fingerprint is registered with the backend:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

Add the SHA256 fingerprint to the `assetlinks.json` configuration on the backend.

## App Structure

```
example/
├── lib/
│   ├── main.dart              # App entry point
│   ├── screens/
│   │   ├── home_screen.dart   # Mode selection
│   │   ├── mrz_screen.dart    # MRZ scanning
│   │   ├── manual_screen.dart # Manual entry
│   │   ├── nfc_screen.dart    # NFC reading
│   │   └── result_screen.dart # Results display
│   └── services/
│       └── passport_service.dart
├── android/
├── ios/
└── pubspec.yaml
```

## Without Backend

The example can also run without a backend for testing purposes:

```dart
// Read document without Active Authentication
final result = await reader.readDocument(
  iosNfcMessages: (state) => _getIosMessage(state),
  // Omit activeAuthenticationParams to skip AA
);
```

In this mode:
- Document data is read and parsed locally
- No server-side verification is performed
- Active Authentication is skipped

This is useful for development and testing but should not be used in production.

## Next Steps

- [Usage Guide](./usage) - Detailed walkthrough of app features
- [Integration Guide](../integration) - Integrate VCMRTD in your own app
