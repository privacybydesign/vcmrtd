# Idem

Idem reads an identity document's chip, verifies that the holder's face matches
the portrait on it, and issues the result as a Verifiable Credential. It handles
passports, eID cards and driving licences.

The name is the claim the app makes: the person and the document are the same.

## Architecture Overview
The app implements the complete verification workflow:
1. **NFC Reading**: Uses the [vcmrtd](../vcmrtd) library to read document data via NFC
2. **Backend Verification**: Communicates with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) for document verification
3. **Authentication**: Supports both Passive Authentication (PA) and Active Authentication (AA) through the gmrtd Go library
4. **Masterlist Validation**: Leverages Dutch and German Certificate Authority masterlists for comprehensive verification

## Getting Started
```bash
flutter pub get
flutter run
```
`pubspec.lock` was resolved with Flutter 3.38.4, the version `ci_scripts/install_flutter.sh` pins for CI. Running `flutter pub get` on a newer Flutter rewrites the SDK-pinned test packages in it, so check those changes back out if they are not part of your work.

## Branding
The app uses the guided layout: a dark hero on the home screen, a three-step progress bar, and camera screens with a scrim and cut-out frame. The shared pieces live in `lib/widgets/guided/`.

It starts in Idem's own look. Once a QR code or link is opened, the session's `branding` (the businesswallet org's theme, or its customer's) dresses the whole app, so it looks like the requester's own: name, logo, colours and font (`AppBranding.fromSession` in `lib/theme/app_theme.dart`, held by `activeBrandingProvider`). It goes back to Idem's look when the session ends or is declined. Anything a theme leaves out keeps the design's own; a theme font the app doesn't bundle (`assets/fonts/`) uses the platform's.

The app only opens sessions from the servers it is built for, so no one can run a server of their own that shows the app in someone else's branding:
```bash
flutter run --dart-define=PROOFING_TRUSTED_SERVERS=https://wallet.example,https://staging.wallet.example
```
A debug build without the define trusts every server (a dev backend on a LAN address); **a release build without it opens no session at all.**

## Backend Integration
The app connects to the go-passport-issuer backend service, which provides:
- Document verification using the [gmrtd](https://github.com/gmrtd/gmrtd) library
- Passive and Active Authentication implementation
- Certificate validation against trusted masterlists
- Verifiable Credential generation for the Yivi ecosystem