## Verifiable Credentials from Machine Readable Travel Documents (MRTD) 
This Dart library and sample app enable reading and verifying Machine Readable Travel Documents (MRTD) such as ePassports and eID cards using a mobile phone.

It interfaces with the [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer), which retrieves passport data, performs Passive Authentication (PA), and converts the data into Verifiable Credentials (VCs) used in the Yivi ecosystem.

> [!WARNING]  
> The library and app are currently under construction and mainly tested with Dutch passports.

> [!NOTE]  
> This library is orginally forked from [dmrtd](https://github.com/ZeroPass/dmrtd) repository, but has been significantly modified and improved by the Yivi team.

## Documentation
This repository includes documentation for the library, the example app, and background information.
Published documentation is available via GitHub Pages: [privacybydesign.github.io/vcmrtd](https://privacybydesign.github.io/vcmrtd)

## Example App
This repository contains an example app that demonstrates how to use the library to read and verify MRTD data. The app is built using Flutter and can be run on both Android and iOS devices. It can be run with or without Veriable Credential generation.

Some screenshots of the example app:

<p float="left"> 
<img src="/dmrtd-docs/static/images/home.png?raw=true" width="200px" alt="Choose between MRZ or manual" />
<img src="/dmrtd-docs/static/images/mrz.png?raw=true" width="200px" alt="MRZ scanning" />
<img src="/dmrtd-docs/static/images/nfc.png?raw=true" width="200px" alt="NFC explanation" />
<img src="/dmrtd-docs/static/images/reading.png?raw=true" width="200px" alt="Reading data" />
<img src="/dmrtd-docs/static/images/result.png?raw=true" width="200px" alt="Results" />
</p>


## Development
Make sure your local Android keystore certificate SHA256 fingerpint is added to the Android AssetsLinks in the `go-passport-issuer`.
One can simpy retrieve the SHA265 hash with the following command:

```sh
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
```

The SHA256 hash should be available here: 

## License
Copyright (C) 2025 Yivi B.V. vcmrtd is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This project builds upon the work of [dmrtd](https://github.com/ZeroPass/dmrtd), we hard forked it for our own use and made significant improvements. dmrtd is also licensed under the GNU General Public License v3.
