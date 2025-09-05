# Passport based Verifiable Credentials

This library and example app demonstrate how to read and verify Machine Readable Travel Documents (MRTDs) such as passports using NFC technology. The Passport Reader app is designed to work on modern smartphones, leveraging their NFC capabilities to read data stored in the passport's chip, including personal information and security features.

## System Architecture

The system consists of the following components:
- **dmrtd**: The core Dart library that provides the functionality to read and verify MRTDs via NFC
- **docs**: Comprehensive documentation for the library, including usage instructions and examples
- **vcmrtd-app**: A mobile application that utilizes the dmrtd library to read and verify passports
- **Backend Integration**: [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) backend service

## Technical Implementation

### Core Libraries
The backend leverages the [gmrtd](https://github.com/gmrtd/gmrtd) Go library, which provides:
- Low-level MRTD chip communication protocols
- Implementation of ICAO 9303 standards
- Support for various passport security mechanisms
- Cryptographic operations for document verification

### Authentication Mechanisms

#### Passive Authentication (PA) 
- **Purpose**: Verifies the authenticity and integrity of data stored on the passport chip
- **Implementation**: Digital signature verification using the Document Signer Certificate (DSC)
- **Process**: Validates that passport data hasn't been tampered with since issuance
- **Coverage**: Mandatory for all ICAO-compliant e-passports

#### Active Authentication (AA)
- **Purpose**: Prevents passport chip cloning by verifying chip authenticity
- **Implementation**: Challenge-response protocol using chip's unique key pair
- **Process**: Chip proves possession of private key corresponding to public key in DG15
- **Coverage**: Optional feature, varies by issuing country (see support table)

### Certificate Authority Support
The system includes comprehensive masterlist support for:
- **Dutch Masterlists**: Full support for Netherlands passport verification infrastructure
- **German Masterlists**: Complete integration with German Certificate Authority chains
- **Multi-country Support**: Extensible framework for additional country-specific certificate validation
