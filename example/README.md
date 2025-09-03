# DMRTD Example App
This is a demonstration app for the `dmrtd` library, showcasing how to read and verify Machine Readable Travel Documents using NFC technology.

## Architecture Overview
The example app demonstrates the complete passport verification workflow:
1. **NFC Reading**: Uses the DMRTD library to read passport data via NFC
2. **Backend Verification**: Communicates with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) for document verification
3. **Authentication**: Supports both Passive Authentication (PA) and Active Authentication (AA) through the gmrtd Go library
4. **Masterlist Validation**: Leverages Dutch and German Certificate Authority masterlists for comprehensive verification

## Getting Started
```bash
flutter pub get
flutter run
```

## Backend Integration
The app connects to the go-passport-issuer backend service, which provides:
- Document verification using the [gmrtd](https://github.com/gmrtd/gmrtd) library
- Passive and Active Authentication implementation
- Certificate validation against trusted masterlists
- Verifiable Credential generation for the Yivi ecosystem