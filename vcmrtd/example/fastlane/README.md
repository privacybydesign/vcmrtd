fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

Furthermore, you need to follow the development setup instructions in the repository root directory's README.
Setup scripts for CI platforms can be found in the _ci_scripts_ directory.

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Apple provisioning profiles
The `ios_build_app` and the `ios_build_integration_test` actions needs the app's provisioning profile and the
corresponding PKCS#12 certificate bundle. Therefore, these actions require the parameters
`provisioning_profile_path`, `certificate_path` and `certificate_password`.

There are two types of certificate bundles: development certificates and distribution certificates.
Development certificates are bound to individual developers and can be used to build for the developer's own iOS device.
The distribution certificate belongs to the organization and is needed for app store builds.

Note: provisioning profiles can only be used to sign app builds. To upload the builds to Apple,
you additionally need your personal App Store Connect account with the right permissions.
Uploading can be done using [Transporter for MacOS](https://apps.apple.com/us/app/transporter/id1450874784?mt=12).

## Generating new certificates
Below we describe how to generate these assets. For distribution certificates, this can only be done by users with the
'Admin' role or the 'App Manager' role with access to certificates, identifiers and profiles in Apple App Store Connect.

Generated certificates and the provisioning profiles linked it are valid for one year.

 1. Go to the ./example/fastlane directory
 2. Run `mkdir -p ./profiles && cd ./profiles`
 3. Choose a name for your new certificate, i.e. `KEY_NAME=ios_distribution`
 4. Run the following and follow the instructions:
    ```
    openssl req -nodes -newkey rsa:2048 -keyout $KEY_NAME.key -out $KEY_NAME.csr
    ```
    There are no strict requirements about which values to use for the CSR-fields.
 5. Upload the CSR to Apple: go to https://developer.apple.com/account/resources/certificates/list, press the '+' sign
    and choose "iOS Distribution (App Store and Ad Hoc)" for a distribution certificate.
 6. When finished, download the .cer file and save it to the directory created in step 2 as `$KEY_NAME.cer`
 7. Convert the .cer file to a .pem file:
    ```
    openssl x509 -in $KEY_NAME.cer -inform DER -out $KEY_NAME.pem -outform PEM
    ```
 8. Convert the .pem to a .p12 and choose the certificate password:
    ```
    openssl pkcs12 -export -inkey $KEY_NAME.key -in $KEY_NAME.pem -out $KEY_NAME.p12
    ```
    If you use OpenSSL 3.x, then you need to add `-legacy` to the command for compatibility with OpenSSL 1.x.
 9. Safely store the certificate password in a password manager or a secret vault for later use
 10. You can now create a provisioning profile: go to https://developer.apple.com/account/resources/profiles/list,
     press the '+' sign and follow the instructions. This can only be done by users with the 'Admin' role or the
     'App Manager' role with access to certificates, identifiers and profiles in Apple App Store Connect. If you only
     have the 'Developer' role, then you need to ask someone else to create the provisioning profile for you.
 11. When finished, download the provisioning profile and save it to the directory created in step 2. We refer to this
     as $PROVISIONING_PROFILE.mobileprovision in this README.
 12. In case you need to upload the assets to a secret vault, then you need to encode the files you want to upload with base64:
     ```
     cat $KEY_NAME.p12 | base64 > $KEY_NAME.p12.base64
     cat $PROVISIONING_PROFILE.mobileprovision | base64 > $PROVISIONING_PROFILE.mobileprovision.base64
     ```

When generating distribution certificates for CI platforms, it's recommended to protect the certificate bundle as a secret in
protected deployment environments. In this way, you prevent that development builds get signed. For more information about the
secrets in our GitHub Actions workflows, please check the [workflow README](../../.github/workflows/README.md).

Don't forget to delete the local file copies after you've uploaded the profiles and certificates to your CI's secret vault.

# Android signing/upload keys
The artifacts produced by the `android_build_apk` and the `android_build_appbundle` actions need to be signed in order
to distribute them. For the Google Play Store, you need an app bundle signed with the right upload key.
The corresponding certificate needs to be registered with Google. This upload key is also used as signing key for
Android Code Transparency.
The `android_build_apk` and the `android_build_appbundle` actions have built-in support for signing.
The key should be given as Java Keystore and can be passed using the `keystore_path`, `key_alias`, `keystore_password`
and `key_password` parameters.

Below we describe how you can generate a Java Keystore for signing.

 1. Specify a key name, i.e. `KEY_ALIAS=upload-key`
 2. Run `keytool -genkey -alias $KEY_ALIAS -keyalg RSA -keystore $KEY_ALIAS.jks -keysize 4096 -validity 10000`
 3. If you need to register the key as upload key to Google Play, you can generate the certificate in the following way:
    `keytool -export -rfc -keystore $KEY_ALIAS.jks -alias $KEY_ALIAS -file $KEY_ALIAS.pem`
 4. In case you need to upload the assets to a secret vault, then you need to encode the files with base64,
    i.e. `cat $KEY_ALIAS.jks | base64 > $KEY_ALIAS.jks.base64`

# Available Actions

### lint

```sh
[bundle exec] fastlane lint
```

Checks the code quality of the project.

### unit_test

```sh
[bundle exec] fastlane unit_test
```

Checks whether all unit tests pass.

### android_build

```sh
[bundle exec] fastlane android_build
```

Builds the Android AAB.
The AAB is written to the `build` directory (so `fastlane/build` from the repository's root).

Optionally, you can specify the key properties of the upload key that should be used to sign the build.
This key is also used to sign the app bundle's code transparency file.

```sh
[bundle exec] fastlane android_build keystore_path:<VALUE> key_alias:<VALUE> keystore_password:<VALUE> key_password:<VALUE>
```

### android_build_apk

```sh
[bundle exec] fastlane android_build_apk
```

Builds the Android APK. Only a universal build is included. Check the `android_build`
or the `android_build_appbundle` action if you want to build for the Google Play Store.
The Android APK is written to the `build` directory (so `fastlane/build` from the repository's root).

Optionally, you can specify the key properties of the signing key that should be used.

```sh
[bundle exec] fastlane android_build_apk keystore_path:<VALUE> key_alias:<VALUE> keystore_password:<VALUE> key_password:<VALUE>
```

### android_build_appbundle

```sh
[bundle exec] fastlane android_build_appbundle
```

Builds the Android AAB.
Check the `android_build` action if you want to do a full build.
The AAB is written to the `build` directory (so `fastlane/build` from the repository's root).

Optionally, you can specify the key properties of the upload key that should be used to sign the build.
This key is also used to sign the app bundle's code transparency file.

```sh
[bundle exec] fastlane android_build_appbundle keystore_path:<VALUE> key_alias:<VALUE> keystore_password:<VALUE> key_password:<VALUE>
```

### ios_build

```sh
[bundle exec] fastlane ios_build
```

Builds an iOS IPA file.

For all extra parameters, please check the [documentation of `ios_build_app`](#iosbuildapp).

### ios_build_app

```sh
[bundle exec] fastlane ios_build_app
```

Builds an iOS IPA file.
The signed iOS IPA file is written to the `build` directory (so `fastlane/build` from the repository's root).

Optionally, you can specify the paths to the app provisioning profile and the corresponding PKCS#12 certificate bundle
that should be used to provision and sign the build. If the given path is relative, then it is evaluated using the
fastlane directory as base (so `./fastlane` from the repository's root).

```sh
[bundle exec] fastlane ios_build_app provisioning_profile_path:<VALUE> certificate_path:<VALUE> certificate_password:<VALUE>
```

More information on how to achieve app provisioning profiles can be found [above](#apple-provisioning-profiles).

----

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
