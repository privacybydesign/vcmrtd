# Getting Started

This guide will help you set up VCMRTD in your Flutter project.

## Prerequisites

- Dart SDK 3.8.0+ (Flutter 3.32.0+)
- A physical device with NFC capability (emulators do not support NFC)
- Android Studio or Xcode for mobile development

## Installation

Add VCMRTD to your `pubspec.yaml` and then run `flutter pub get`.

## Platform Configuration

### Android

Add NFC permissions to `android/app/src/main/AndroidManifest.xml`.

### iOS

Add NFC capabilities to your iOS project:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability" and add "Near Field Communication Tag Reading"

Add the NFCReaderUsageDescription and ISO7816 select identifiers to `ios/Runner/Info.plist`.

## Basic Usage

To read a passport, you need to:

1. Create an access key from MRZ data (document number, date of birth, date of expiry)
2. Initialize NfcProvider and DataGroupReader components
3. Configure which data groups to read using DocumentReaderConfig
4. Create a DocumentReader with the appropriate parser
5. Call readDocument() to read the passport via NFC

## MRZ Data

To authenticate with the passport chip, you need three pieces of information from the Machine Readable Zone (MRZ):

- **Document Number**: The number of the document.
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
