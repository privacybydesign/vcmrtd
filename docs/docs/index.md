# VCMRTD

VCMRTD (Verifiable Credentials from Machine Readable Travel Documents) is a Dart/Flutter library for reading and verifying MRTDs via NFC. It enables mobile applications to securely read ePassports, eID cards, and Dutch electronic driving licenses and issue Verifiable Credentials for use in the [Yivi](https://yivi.app) ecosystem.

## Overview
VCMRTD implements the ICAO 9303 standards for machine readable travel documents. It handles:

- **NFC Communication**: Establish secure connections with document chips
- **Authentication**: Support for BAC and PACE protocols
- **Data Extraction**: Read all selected data groups (DG1-DG16)
- **Security**: Active Authentication to prevent chip cloning

For production deployments, VCMRTD works with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer) which provides server-side verification including Passive Authentication and certificate chain validation using the [GMRTD](https://github.com/gmrtd/gmrtd) library.

## Architecture

### Client-Side (VCMRTD)

The VCMRTD library runs on the mobile device and handles:

1. **NFC Connection**: Manages the low-level communication with the document chip
2. **Access Control**: Performs BAC or PACE authentication using MRZ-derived keys
3. **Data Reading**: Extracts data groups from the chip's file system
4. **Active Authentication**: Executes challenge-response to prove chip authenticity

### Server-Side (go-passport-issuer)

The backend service performs cryptographic verification:

1. **Passive Authentication**: Validates digital signatures against trusted Certificate Authorities
2. **Certificate Chain Validation**: Verifies Document Signer Certificates against Country Signing CA
3. **Masterlist Support**: Includes Dutch and German CA certificates
4. **Credential Issuance**: Optionally generates Verifiable Credentials for the Yivi ecosystem

## Supported Documents

| Document Type | Countries Tested | BAC | PACE | Active Auth |
|--------------|------------------|-----|------|-------------|
| ePassports | Netherlands, Germany | ✓ | ✓ | ✓ |
| eID Cards | Netherlands | ✓ | ✓ | ✓ |
| eDriving Licenses | Netherlands | ✓ | ✓ | ✓ |

The library should work with ICAO-compliant documents from other countries, though these have not been extensively tested.

## Current Limitations

- **Face Verification**: Biometric matching against the DG2 facial image is not yet implemented but is planned for a future release
- **Extended Access Control**: While EAC is partially implemented, accessing protected biometric data (fingerprints, iris) requires additional Terminal Authentication infrastructure

## Next Steps

- [Getting Started](./getting-started) - Install and configure VCMRTD
- [Integration Guide](./integration) - Integrate VCMRTD into your application
- [Example Application](./example/overview) - See a complete implementation
