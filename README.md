[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![Technical Debt](https://sonarcloud.io/api/project_badges/measure?project=privacybydesign_vcmrtd&metric=sqale_index)](https://sonarcloud.io/summary/new_code?id=privacybydesign_vcmrtd)
[![codecov](https://codecov.io/gh/privacybydesign/vcmrtd/graph/badge.svg)](https://codecov.io/gh/privacybydesign/vcmrtd)

# VCMRTD 

This repository contains two Flutter packages for reading and verifying electronic travel documents (ePassports, eID cards, driving licences) and performing biometric face verification built for the [Yivi](https://yivi.app) ecosystem.

## Packages

### [vcmrtd](vcmrtd/)

A Dart/Flutter library for reading Machine Readable Travel Documents (MRTDs) via NFC. Implements ICAO 9303 with BAC and PACE authentication, reads all standard data groups, and integrates with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) for server-side Passive Authentication and Verifiable Credential issuance.

### [face_verification](face_verification/)

A Flutter package for face verification and liveness detection. Supports active liveness (gesture challenges) and passive liveness (anti-spoofing + rPPG heart rate), plus face matching against the DG2 photo from the NFC chip. Runs entirely on-device in a background isolate using bundled TFLite models.

## Example app

The [`vcmrtd/example`](vcmrtd/example/) app demonstrates the full flow: MRZ scanning, NFC reading, face verification, and Verifiable Credential issuance.

<p float="left">
<img src="vcmrtd/docs/static/images/home.jpg?raw=true" width="180px" alt="Home screen" />
<img src="vcmrtd/docs/static/images/scan.jpg?raw=true" width="180px" alt="MRZ scanning" />
<img src="vcmrtd/docs/static/images/info.jpg?raw=true" width="180px" alt="NFC positioning" />
<img src="vcmrtd/docs/static/images/read.jpg?raw=true" width="180px" alt="Reading progress" />
<img src="vcmrtd/docs/static/images/result.png?raw=true" width="180px" alt="Results" />
</p>

```sh
cd vcmrtd/example
flutter pub get
flutter run
```

## Related projects

- [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) — backend service for document verification and VC issuance
- [GMRTD](https://github.com/gmrtd/gmrtd) — Go library for MRTD operations (used by go-passport-issuer)
- [Yivi](https://yivi.app) — privacy-preserving identity platform

## Attribution

The `vcmrtd` package is based on [dmrtd](https://github.com/ZeroPass/dmrtd) by ZeroPass, with significant modifications and improvements by the Yivi team.

## License

Copyright (C) 2025-2026 Yivi B.V.

This software is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
