# VCMRTD

A Dart/Flutter library for reading and verifying Machine Readable Travel Documents (MRTDs) via NFC.

VCMRTD enables mobile applications to read ePassports, eID cards, and electronic driving licenses using NFC technology. It implements ICAO 9303 standards and supports both Basic Access Control (BAC) and Password Authenticated Connection Establishment (PACE) authentication protocols.

## Features

- **NFC Document Reading**: Read data from ePassports, eID cards, and electronic driving licenses
- **Multiple Authentication Protocols**: Supports BAC and PACE for secure chip communication
- **Data Group Support**: Access all standard ICAO data groups (DG1-DG16)
- **Security Verification**: Performs Active Authentication (AA) to prevent chip cloning
- **Backend Integration**: Works with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) for server-side Passive Authentication and certificate chain validation
- **Verifiable Credentials**: Generate VCs for the [Yivi](https://yivi.app) ecosystem

## Architecture

VCMRTD is designed as a client-side library that handles NFC communication and document parsing. Server-side verification is performed by [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer), which uses the [GMRTD](https://github.com/gmrtd/gmrtd) Go library for:

- Passive Authentication (PA) with certificate chain validation
- Active Authentication (AA) signature verification
- Masterlist support for Dutch and German Certificate Authorities

```
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│   Mobile App    │     │  go-passport-issuer │     │   IRMA Server   │
│   (VCMRTD)      │────▶│  (GMRTD)            │────▶│   (Optional)    │
└─────────────────┘     └─────────────────────┘     └─────────────────┘
        │
        │ NFC
        ▼
┌─────────────────┐
│    ePassport    │
│    / eID Card   │
└─────────────────┘
```

## Installation

Add VCMRTD to your `pubspec.yaml`:

```yaml
dependencies:
  vcmrtd:
    git:
      url: https://github.com/privacybydesign/vcmrtd.git
      ref: master
```

## Quick Start

```dart
import 'package:vcmrtd/vcmrtd.dart';

// 1. Create access key from MRZ data
final accessKey = DBAKey(
  documentNumber: 'AB1234567',
  dateOfBirth: DateTime(1990, 1, 15),
  dateOfExpiry: DateTime(2030, 1, 15),
);

// 2. Initialize the document reader
final nfc = NfcProvider();
final dataGroupReader = DataGroupReader(accessKey: accessKey, nfc: nfc);
final parser = PassportParser();

final reader = DocumentReader(
  documentParser: parser,
  dataGroupReader: dataGroupReader,
  nfc: nfc,
  config: DocumentReaderConfig(
    readIfAvailable: {
      DataGroups.dg1,  // MRZ data
      DataGroups.dg2,  // Facial image
      DataGroups.dg15, // Active Authentication public key
    },
  ),
);

// 3. Read the document
final result = await reader.readDocument(
  iosNfcMessages: (state) => 'Reading passport...',
);

if (result != null) {
  final (document, rawData) = result;
  print('Name: ${document.firstName} ${document.lastName}');
}
```

## Backend Verification

For production use, document data should be verified server-side:

```dart
final issuer = DefaultPassportIssuer(
  hostName: 'https://your-passport-issuer.example.com',
);

// Start verification session
final session = await issuer.startSessionAtPassportIssuer();

// Read document with session nonce for Active Authentication
final result = await reader.readDocument(
  iosNfcMessages: (state) => 'Reading passport...',
  activeAuthenticationParams: session,
);

// Verify document server-side
final verification = await issuer.verifyPassport(result.rawData);
```

## Supported Documents

| Document Type | BAC | PACE | Active Auth |
|--------------|-----|------|-------------|
| ePassports   | ✓   | ✓    | ✓           |
| eID Cards    | ✓   | ✓    | ✓           |
| eDriving Licenses (NL) | ✓ | ✓ | ✓       |

## Roadmap

- [ ] **Face Verification**: Biometric face matching against DG2 facial image (planned)
- [x] PACE-CAM (Chip Authentication Mapping) support
- [x] Extended Access Control (EAC) support

## Documentation

Full documentation is available at [privacybydesign.github.io/vcmrtd](https://privacybydesign.github.io/vcmrtd)

## Example App

The repository includes a complete example application demonstrating:

- MRZ scanning via camera or manual entry
- NFC document reading with progress indication
- Backend verification integration
- Verifiable Credential issuance

<p float="left">
<img src="/docs/static/images/home.jpg?raw=true" width="180px" alt="Home screen" />
<img src="/docs/static/images/scan.jpg?raw=true" width="180px" alt="MRZ scanning" />
<img src="/docs/static/images/info.jpg?raw=true" width="180px" alt="NFC positioning" />
<img src="/docs/static/images/read.jpg?raw=true" width="180px" alt="Reading progress" />
<img src="/docs/static/images/result.png?raw=true" width="180px" alt="Results" />
</p>

## Development

### Prerequisites

- Flutter SDK 3.8.0+
- Android Studio or Xcode for mobile development
- A physical device with NFC capability (emulators do not support NFC)

### Running the Example App

```sh
cd example
flutter pub get
flutter run
```

### Android Keystore Setup

For Android development, ensure your debug keystore SHA256 fingerprint is registered:

```sh
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

## Related Projects

- [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) - Backend service for document verification and VC issuance
- [GMRTD](https://github.com/gmrtd/gmrtd) - Go library for MRTD operations (used by go-passport-issuer)
- [Yivi](https://yivi.app) - Privacy-preserving identity platform

## Attribution

This library is based on [dmrtd](https://github.com/ZeroPass/dmrtd) by ZeroPass, with significant modifications and improvements by the Yivi team.

## License

Copyright (C) 2025-2026 Yivi B.V.

VCMRTD is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
