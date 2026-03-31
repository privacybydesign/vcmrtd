# Integration Guide

This guide explains how to integrate VCMRTD with your backend for secure document verification.

## Why Server-Side Verification?

While VCMRTD reads document data directly from the chip via NFC, the data must still be verified for authenticity. **Passive Authentication** is the process of cryptographically verifying that the data on the chip was signed by the issuing country and has not been tampered with. This must be performed server-side because:

1. **Certificate Chain Validation**: Verifying the Document Signer Certificate requires access to trusted Country Signing CA certificates (masterlists)
2. **Masterlist Management**: Masterlists must be regularly updated and securely stored
3. **Security**: Keeping verification logic server-side prevents tampering

## go-passport-issuer

VCMRTD is designed to work with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer), a Go backend service that handles:

- Passive Authentication (PA)
- Active Authentication (AA) verification
- Certificate chain validation
- Dutch and German masterlist support
- Optional Verifiable Credential issuance via IRMA

### Verification Flow

The verification flow involves:
1. Mobile app requests a session from the backend (POST /api/start-validation)
2. Backend returns session_id and nonce
3. Mobile app authenticates with passport via NFC (BAC/PACE)
4. Mobile app reads data groups (DG1, DG2, DG15, EF.SOD)
5. Mobile app performs Active Authentication with nonce
6. Mobile app sends data to backend (POST /api/verify-passport)
7. Backend performs Passive Authentication, certificate validation, and AA signature verification
8. Backend returns verification result

## Verifiable Credentials

For integration with the [Yivi](https://yivi.app) ecosystem, you can issue Verifiable Credentials after successful verification using the startIrmaIssuanceSession method.

## API Endpoints

The go-passport-issuer backend exposes the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/start-validation` | POST | Start verification session |
| `/api/verify-passport` | POST | Verify passport data |
| `/api/verify-driving-licence` | POST | Verify driving license data |
| `/api/issue-passport` | POST | Verify and issue passport credential |
| `/api/issue-id-card` | POST | Verify and issue ID card credential |
| `/api/issue-driving-licence` | POST | Verify and issue driving license credential |
| `/api/health` | GET | Health check |

See the [Backend API Reference](./api/backend) for detailed request/response formats.

## Driving License Support

VCMRTD also supports Dutch electronic driving licenses. Use DrivingLicenceParser instead of PassportParser and verify with the verifyDrivingLicence endpoint.

## Error Handling

Handle verification failures gracefully by catching exceptions and checking the passiveAuthenticationPassed and activeAuthenticationPassed flags in the verification response.

## Next Steps

- [Backend API Reference](./api/backend) - Detailed API documentation
- [Technical Reference](./reference/standards) - Learn about MRTD standards
- [Example Application](./example/overview) - See a complete implementation
