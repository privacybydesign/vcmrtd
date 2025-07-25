## Dart Library for Verifiable Credentials from Machine Readable Travel Documents (MRTD) 
This Dart library provides functionality to read and verify Machine Readable Travel Documents (MRTD) such as ePassports and eID cards. It supports Basic Access Control (BAC), Active Authentication (AA), and other protocols defined by ICAO standards.

This library orginally forked from [dmrtd](https://github.com/ZeroPass/dmrtd) and is maintained by the [Yivi team](https://yivi.app). We broke the upstream fork because we are planning to add the following features:
- [x] MRZ parsing using OCR.
- [ ] Passive Authentication (PA), validating signatures against country CA certificates.
- [ ] Support for Anglo Saxion countries (like USA, UK) and EU.
- [ ] Creating of Verifiable Credentials (VC) from MRTD data, such as `SD-JWT VC` and `Idemix crendentials`.

The goal is to incorporate this library into the [Yivi app](https://github.com/privacybydesign/irmamobile) to allow users to verify their ePassports and eID cards, and to create verifiable credentials from the data.

## Documentation
We documented the example app, library and background information in this repository. The documentation is published using Github Pages and can be visited [here](https://privacybydesign.github.io/dmrtd).

## Example App
This respotitory contains an example app that demonstrates how to use the library to read and verify MRTD data. The app is built using Flutter and can be run on both Android and iOS devices.

Some screenshots of the example app:
![Alt text](/dmrtd-docs/static/images/home.png?raw=true "Home Screen")


## Usage

## License
Since this project builds upon the work of [dmrtd](https://github.com/ZeroPass/dmrtd), it is subject to the same licensing terms.

This project is licensed under the terms of the GNU Lesser General Public License (LGPL) for open-source use and a Commercial License for proprietary use. See the LICENSE.LGPL and LICENSE.COMMERCIAL files for details.