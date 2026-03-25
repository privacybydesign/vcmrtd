# Getting Started

This guide will help you set up VCMRTD in your Flutter project.

## Prerequisites

- Flutter SDK 3.8.0 or higher
- A physical device with NFC capability (emulators do not support NFC)
- Android Studio or Xcode for mobile development

## Installation

Add VCMRTD to your `pubspec.yaml`:

```yaml
dependencies:
  vcmrtd:
    git:
      url: https://github.com/privacybydesign/vcmrtd.git
      ref: master
```

Then run:

```bash
flutter pub get
```

## Platform Configuration

### Android

Add NFC permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="true" />

    <application ...>
        <!-- Enable NFC discovery -->
        <intent-filter>
            <action android:name="android.nfc.action.TECH_DISCOVERED" />
        </intent-filter>
        <meta-data
            android:name="android.nfc.action.TECH_DISCOVERED"
            android:resource="@xml/nfc_tech_filter" />
    </application>
</manifest>
```

Create `android/app/src/main/res/xml/nfc_tech_filter.xml`:

```xml
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <tech-list>
        <tech>android.nfc.tech.IsoDep</tech>
    </tech-list>
</resources>
```

### iOS

Add NFC capabilities to your iOS project:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability" and add "Near Field Communication Tag Reading"

Add to `ios/Runner/Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to read passport data</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>A0000002471001</string>
    <string>A0000002472001</string>
</array>
```

## Basic Usage

Here's a minimal example to read a passport:

```dart
import 'package:vcmrtd/vcmrtd.dart';

Future<void> readPassport({
  required String documentNumber,
  required DateTime dateOfBirth,
  required DateTime dateOfExpiry,
}) async {
  // 1. Create access key from MRZ data
  final accessKey = DBAKey(
    documentNumber: documentNumber,
    dateOfBirth: dateOfBirth,
    dateOfExpiry: dateOfExpiry,
  );

  // 2. Initialize components
  final nfc = NfcProvider();
  final dataGroupReader = DataGroupReader(
    accessKey: accessKey,
    nfc: nfc,
  );
  final parser = PassportParser();

  // 3. Configure which data groups to read
  final config = DocumentReaderConfig(
    readIfAvailable: {
      DataGroups.dg1,  // MRZ data (required)
      DataGroups.dg2,  // Facial image (required)
      DataGroups.dg15, // Active Authentication public key
    },
  );

  // 4. Create reader
  final reader = DocumentReader(
    documentParser: parser,
    dataGroupReader: dataGroupReader,
    nfc: nfc,
    config: config,
  );

  // 5. Read the document
  final result = await reader.readDocument(
    iosNfcMessages: (state) => _getIosMessage(state),
  );

  if (result != null) {
    final (document, rawData) = result;
    print('Document Number: ${document.documentNumber}');
    print('Name: ${document.firstName} ${document.lastName}');
    print('Nationality: ${document.nationality}');
  }
}

String _getIosMessage(DocumentReaderState state) {
  return switch (state) {
    DocumentReaderConnecting() => 'Hold your passport near the phone',
    DocumentReaderAuthenticating() => 'Authenticating...',
    DocumentReaderReadingDataGroup() => 'Reading passport data...',
    DocumentReaderSuccess() => 'Done!',
    _ => 'Processing...',
  };
}
```

## MRZ Data

To authenticate with the passport chip, you need three pieces of information from the Machine Readable Zone (MRZ):

- **Document Number**: The passport number (9 characters)
- **Date of Birth**: In YYMMDD format
- **Date of Expiry**: In YYMMDD format

These can be obtained by:
1. **Camera scanning**: Use an OCR library to scan the MRZ
2. **Manual entry**: Let the user enter the information manually

The example application demonstrates both approaches.

## Reader States

The `DocumentReader` emits states as it progresses through the reading process:

| State | Description |
|-------|-------------|
| `DocumentReaderPending` | Initial state, ready to start |
| `DocumentReaderConnecting` | Establishing NFC connection |
| `DocumentReaderAuthenticating` | Performing BAC or PACE authentication |
| `DocumentReaderReadingDataGroup` | Reading a specific data group |
| `DocumentReaderReadingSOD` | Reading the Security Object |
| `DocumentReaderActiveAuthentication` | Performing Active Authentication |
| `DocumentReaderSuccess` | Reading completed successfully |
| `DocumentReaderFailed` | An error occurred |
| `DocumentReaderCancelled` | User cancelled the operation |

## Next Steps

- [Integration Guide](./integration) - Learn how to integrate with the backend for verification
- [Example Application](./example/overview) - See a complete implementation
- [API Reference](./api/document-reader) - Detailed API documentation
