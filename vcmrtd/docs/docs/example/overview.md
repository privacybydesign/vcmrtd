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

1. Clone the repository and navigate to the example directory
2. Install dependencies with `flutter pub get`
3. Run on a connected device with `flutter run`

:::note
The app must run on a physical device. NFC is not available in emulators or simulators.
:::

## Configuration

### Backend URL

By default, the example app connects to the Yivi staging server. To use a different backend, update the configuration in the app.

### Android Debug Keystore

For Android, ensure your debug keystore SHA256 fingerprint is registered with the backend. Use keytool to get the fingerprint and add it to the assetlinks.json configuration on the backend.

## App Structure

The example app is organized with:
- `lib/main.dart` - App entry point
- `lib/screens/` - UI screens (home, mrz, manual, nfc, result)
- `lib/services/` - Business logic (passport_service.dart)
- `android/` and `ios/` - Platform-specific configuration

## Without Backend

The example can also run without a backend for testing purposes by omitting the activeAuthenticationParams when calling readDocument.

In this mode:
- Document data is read and parsed locally
- No server-side verification is performed
- Active Authentication is skipped

This is useful for development and testing but should not be used in production.

## Next Steps

- [Usage Guide](./usage) - Detailed walkthrough of app features
- [Integration Guide](../integration) - Integrate VCMRTD in your own app
