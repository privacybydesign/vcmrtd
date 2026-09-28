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

## White-label builds
The brand is picked at compile time. Without a define you get the stock Idem app:
```bash
flutter run --flavor alpha --dart-define=BRAND=cm   # CM.com (Android needs a flavor: alpha or beta)
```
A brand is a `ThemeData` plus a `BrandTheme` extension (`lib/theme/brand_theme.dart`) whose colours and styles only override the widgets' own defaults, so the Idem build stays as it was. Brands live in `lib/theme/brands/`, are listed in `AppBrand` (`lib/theme/app_brand.dart`), and keep their logos and fonts under `assets/brands/<name>/`.

The define changes the Flutter UI only. App name, launcher icon and bundle ID are still Idem's.

## Backend Integration
The app connects to the go-passport-issuer backend service, which provides:
- Document verification using the [gmrtd](https://github.com/gmrtd/gmrtd) library
- Passive and Active Authentication implementation
- Certificate validation against trusted masterlists
- Verifiable Credential generation for the Yivi ecosystem