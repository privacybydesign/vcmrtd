# GitHub Actions workflows

Two workflows, both driving the Fastlane scripts in [`idem/fastlane`](../../idem/fastlane/README.md).

## Three builds

| Track | Workflow | Trigger | iOS | Android |
|---|---|---|---|---|
| **dev** | Status checks | every pull request | unsigned (`--no-codesign`) | `alpha` + `beta`, APK and AAB, debug-signed |
| **alpha** | Delivery | every push to `master` | ad hoc, `…idem.alpha` | `alpha` flavor, APK and AAB |
| **beta** | Delivery | version bump in `idem/pubspec.yaml` | app store, `…idem` | `beta` flavor, AAB with the Play upload key |

The dev builds are deliberately unsigned so they need no secrets and still run on
pull requests from forks. They exist to catch compile breakage — in particular on
iOS, which previously was never built outside `master`.

Ad hoc builds do not need unique build numbers, so alpha runs on every push. The
stores reject a build number they have already seen, so beta runs only when the
`version:` line in `idem/pubspec.yaml` changes.

## Flavors

Android uses Gradle product flavors on a `track` dimension: `alpha` carries an
`applicationIdSuffix` of `.alpha` so it installs alongside `beta`, and each
flavor sets its own label (`Idem Alpha` / `Idem`) in
`android/app/src/<flavor>/AndroidManifest.xml`.

iOS has no per-flavor Xcode schemes. `ios_build_app` rewrites the bundle
identifier and display name in `Info.plist` before building, and picks the
export method from the flavor — the same approach irmamobile uses.

## Environments and secrets

Secrets should be uploaded as
[environment secrets](https://github.com/privacybydesign/vcmrtd/settings/environments)
rather than repository secrets, so that a pull-request build can never reach a
distribution certificate.

### `ad-hoc-alpha` — iOS internal distribution

- `APPLE_DISTRIBUTION_CERTIFICATE` — base64 PKCS#12 distribution certificate. Expires yearly.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE` — base64 **ad hoc** profile for `foundation.privacybydesign.idem.alpha`, listing the test devices' UDIDs.

### `app-store-beta` — iOS store builds

- `APPLE_DISTRIBUTION_CERTIFICATE`, `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE` — base64 **app store** profile for `foundation.privacybydesign.idem`.

### `android-alpha` and `android-beta`

- `ANDROID_SIGNING_KEYSTORE` — base64 Java keystore.
- `ANDROID_SIGNING_KEYSTORE_PASSWORD`
- `ANDROID_SIGNING_KEY_ALIAS` — the alias inside that keystore. It is a secret only so each environment can point at a different keystore; the value itself is not sensitive.

For `android-beta` this must be the upload key registered with Google Play. It
also signs the app bundle's code transparency file.

Instructions for generating certificates, profiles and keystores are in the
[Fastlane README](../../idem/fastlane/README.md).

## Setup still required

Both Apple identifiers are new, so before the alpha and beta jobs can pass:

1. Create App IDs for `foundation.privacybydesign.idem` and
   `foundation.privacybydesign.idem.alpha`, both with the NFC Tag Reading and
   Associated Domains capabilities.
2. Issue an app-store profile for the first and an ad-hoc profile for the second.
3. Create the four environments above and populate them.

The existing repository-level secrets were issued against the old
`foundation.privacybydesign.vcmrtd` identifier and will not sign these builds.
