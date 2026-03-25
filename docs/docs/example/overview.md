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

<div class="screenshot-grid">

<div style={{display: 'flex', flexWrap: 'wrap', gap: '1rem', justifyContent: 'center'}}>
  <figure style={{margin: 0, textAlign: 'center'}}>
    <img src="/images/home.jpg" alt="Home Screen" style={{width: '180px'}} />
    <figcaption>Choose reading mode</figcaption>
  </figure>
  <figure style={{margin: 0, textAlign: 'center'}}>
    <img src="/images/scan.jpg" alt="MRZ Scanning" style={{width: '180px'}} />
    <figcaption>MRZ scanning</figcaption>
  </figure>
  <figure style={{margin: 0, textAlign: 'center'}}>
    <img src="/images/info.jpg" alt="NFC Positioning" style={{width: '180px'}} />
    <figcaption>NFC positioning</figcaption>
  </figure>
  <figure style={{margin: 0, textAlign: 'center'}}>
    <img src="/images/read.jpg" alt="Reading Progress" style={{width: '180px'}} />
    <figcaption>Reading progress</figcaption>
  </figure>
  <figure style={{margin: 0, textAlign: 'center'}}>
    <img src="/images/result.png" alt="Results" style={{width: '180px'}} />
    <figcaption>Results</figcaption>
  </figure>
</div>

</div>

## Running the Example

### Prerequisites

- Flutter SDK 3.8.0+
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
