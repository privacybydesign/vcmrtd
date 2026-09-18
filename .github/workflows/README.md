# GitHub Actions workflows

Three workflows, all driving the Fastlane scripts in [`idem/fastlane`](../../idem/fastlane/README.md).

## Three builds

| Track | Workflow | Trigger | iOS | Android |
|---|---|---|---|---|
| **dev** | Status checks | every pull request | unsigned (`--no-codesign`) | `alpha` + `beta`, APK and AAB, debug-signed |
| **alpha** | Delivery | every push to `master` | ad hoc, `…idem.alpha` | `alpha` flavor, APK and AAB |
| **beta** | Delivery | build number increase in `idem/pubspec.yaml` | app store, `…idem` → **TestFlight** | `beta` flavor, AAB → **Play internal track** |

The dev builds are deliberately unsigned so they need no secrets and still run on
pull requests from forks. They exist to catch compile breakage — in particular on
iOS, which previously was never built outside `master`.

Ad hoc builds do not need unique build numbers, so alpha runs on every push.

The stores reject a build number they have already seen, so beta triggers on the
build number — the `+N` suffix in `idem/pubspec.yaml` — actually increasing.
Changing only the semver does not trigger it, because the resulting upload would
be refused by both stores.

## Automatic distribution

A merge to `master` that increases the build number builds both platforms and
uploads them:

- **iOS → TestFlight**, internal testers only. No external beta review is
  requested, so widening the audience or submitting to App Store review stays a
  manual decision.
- **Android → Play internal track**, the closest analogue to TestFlight.
  Promoting to closed/open testing or production stays manual.

Uploads run *after* the artifact upload step, so a failed or rejected upload
still leaves a downloadable build on the workflow run. The Play store listing is
never touched — this repository holds no metadata.

The first release on each store has to be done by hand: neither tool can create
an app record, and Play generally wants the first bundle through the console to
establish Play App Signing.

### Dry run

`Distribution dry run` (`dry-run-distribution.yml`) exercises the whole upload
path without publishing. It runs two ways:

- **Automatically**, on every merge to `master` that does *not* increase the
  build number — the exact complement of the beta trigger. Delivery calls it as
  a reusable workflow, so every merge either ships or validates, never neither.
- **Manually**, from the Actions tab, where you can pick a single platform.

iOS runs Apple's binary validation through deliver's `verify_only`; Android uses
supply's `validate_only`. Nothing is uploaded and no build number is consumed,
so it is safe to run repeatedly — including before the first real release, to
find credential, entitlement and privacy-manifest problems while they are still
cheap to fix. It is a separate workflow so that a manual run cannot set the
alpha or beta jobs going.

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

### `app-store-ad-hoc` — iOS internal distribution

- `APPLE_DISTRIBUTION_CERTIFICATE` — base64 PKCS#12 distribution certificate. Expires yearly.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE` — base64 **ad hoc** profile for `foundation.privacybydesign.idem.alpha`, listing the test devices' UDIDs.

### `app-store-beta` — iOS store builds

- `APPLE_DISTRIBUTION_CERTIFICATE`, `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE` — base64 **app store** profile for `foundation.privacybydesign.idem`.

Additionally for `app-store-beta`, for the TestFlight upload:

- `APP_STORE_CONNECT_KEY` — base64 of the `.p8` App Store Connect API key.
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

An API key is used rather than an Apple ID so there is no 2FA session to keep
alive in CI. It needs the App Manager role.

### `android-alpha` and `android-beta`

- `ANDROID_SIGNING_KEYSTORE` — base64 Java keystore.
- `ANDROID_SIGNING_KEYSTORE_PASSWORD`
- `ANDROID_SIGNING_KEY_ALIAS` — the alias inside that keystore. It is a secret only so each environment can point at a different keystore; the value itself is not sensitive.

For `android-beta` this must be the upload key registered with Google Play. It
also signs the app bundle's code transparency file.

`android-beta` additionally needs, for the Play upload:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — base64 of the service account key, granted
  release permissions in the Play Console. The grant takes a while to propagate
  after it is issued.

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
