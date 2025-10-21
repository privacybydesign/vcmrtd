# GitHub Actions workflows

We currently have two workflows. The workflows use our Fastlane scripts. More details about the functioning of the Fastlane
scripts can be found in the [README](../../example/fastlane/README.md).

## Delivery
This workflow generates distribution app builds. It generates iOS builds (IPA) and Android builds (APK and App Bundle).

For iOS, an app-store build is made on every version change in `pubspec.yaml` using the production app ID.

For Android, an APK and App Bundle are made on every version change in `pubspec.yaml` an App Bundle is made using the upload key that is registered with Google.

### Secrets
Below a list of the secrets that are needed. The secrets should be uploaded as [environment secrets](https://github.com/privacybydesign/vcmrtd/settings/environments).

Secrets for the `android-beta` (Android production builds) environment:

- `ANDROID_SIGNING_KEYSTORE`: Base64 encoded Android upload keystore, check the [Fastlane docs](../../example/fastlane/README.md#android-signingupload-keys) for generating instructions.
- `ANDROID_SIGNING_KEYSTORE_PASSWORD`: password of the Android keystore (see above).

Secrets for the `app-store-beta` (iOS production builds) environment:

- `APPLE_DISTRIBUTION_CERTIFICATE`: Base64 encoded PKCS12 certificate of the Apple distribution certificate, check the [Fastlane docs](../../example/fastlane/README.md#generating-new-certificates) for generating instructions. This certificate expires every year.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`: password of the Apple distribution certificate (see above).
- `APPLE_PROVISIONING_PROFILE`: Base64 encoded Apple provisioning profile that is linked to the distribution certificate (see above). In the `app-store-beta` environment the `GitHub Actions app store beta` app store provisioning profile should be uploaded (linked to `foundation.privacybydesign.vcmrtd`). This should be renewed when the distribution certificate is being renewed.
