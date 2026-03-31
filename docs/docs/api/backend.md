# Backend API Reference

This document describes the HTTP API exposed by [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer).

## Base URL

The API is typically deployed at a URL like:
- Production: `https://passport-issuer.example.com`
- Staging: `https://staging.passport-issuer.example.com`

## Endpoints

### Health Check

Check if the service is running.

**GET** `/api/health`

**Response**: Returns `{"ok": true}` on success.

---

### Start Validation Session

Start a new document validation session. Returns a session ID and nonce for Active Authentication.

**POST** `/api/start-validation`

**Request Body**: Empty

**Response**:

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Unique session identifier (32 hex characters) |
| `nonce` | string | Challenge for Active Authentication (8 hex characters) |

---

### Verify Passport

Verify passport data without issuing credentials.

**POST** `/api/verify-passport`

**Request Body**:

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session ID from start-validation |
| `nonce` | string | Nonce from start-validation |
| `data_groups` | object | Map of data group names to base64-encoded contents |
| `ef_sod` | string | Base64-encoded EF.SOD (Security Object Document) |
| `aa_signature` | string? | Base64-encoded Active Authentication signature (optional) |

**Response**: Returns `passive_authentication_passed`, `active_authentication_passed`, and `document_signer_certificate` information.

---

### Verify Driving Licence

Verify Dutch electronic driving licence data.

**POST** `/api/verify-driving-licence`

**Request Body**: Same format as verify-passport

**Response**: Same format as verify-passport

---

### Issue Passport Credential

Verify passport and initiate Verifiable Credential issuance.

**POST** `/api/issue-passport`

**Request Body**: Same format as verify-passport

**Response**:

| Field | Type | Description |
|-------|------|-------------|
| `jwt` | string | Signed JWT for IRMA session |
| `irma_server_url` | string | URL of the IRMA server |

---

### Issue ID Card Credential

Verify ID card and initiate Verifiable Credential issuance.

**POST** `/api/issue-id-card`

**Request/Response**: Same format as issue-passport

---

### Issue Driving Licence Credential

Verify driving licence and initiate Verifiable Credential issuance.

**POST** `/api/issue-driving-licence`

**Request/Response**: Same format as issue-passport

---

## Mobile App Association Files

### Android Asset Links

**GET** `/.well-known/assetlinks.json`

Returns [Android Digital Asset Links](https://developer.android.com/training/app-links/verify-site-associations) for app deep linking.

### iOS App Site Association

**GET** `/.well-known/apple-app-site-association`
**GET** `/apple-app-site-association`

Returns [Apple App Site Association](https://developer.apple.com/documentation/xcode/supporting-associated-domains) for universal links.

---

## Error Responses

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad request (invalid input) |
| 401 | Unauthorized (invalid or expired session) |
| 500 | Internal server error |

### Error Format

Errors are returned as JSON with `error` and `code` fields.

### Common Error Codes

| Code | Description |
|------|-------------|
| `INVALID_SESSION` | Session ID not found or expired |
| `INVALID_NONCE` | Nonce doesn't match session |
| `PA_FAILED` | Passive Authentication failed |
| `AA_FAILED` | Active Authentication failed |
| `INVALID_CERTIFICATE` | Certificate chain validation failed |
| `EXPIRED_DOCUMENT` | Document has expired |

---

## Verification Process

The backend performs the following verification steps:

### Passive Authentication

1. Parse the EF.SOD (Security Object Document)
2. Extract the Document Signer Certificate
3. Validate the certificate chain against trusted masterlists
4. Verify the digital signature on the SOD
5. Hash each data group and compare to signed hashes

### Active Authentication

1. Verify the session ID and nonce match
2. Extract the AA public key from DG15
3. Verify the signature was created by the document's private key
4. Confirm the nonce was used in the challenge

---

## Data Group Encoding

Data groups must be base64-encoded. The raw bytes from the chip should be encoded directly.

The data groups typically included are:

| Data Group | Required | Description |
|------------|----------|-------------|
| DG1 | Yes | MRZ data |
| DG2 | Yes | Facial image |
| DG15 | For AA | Active Authentication public key |

---

## IRMA Session Flow

After successful verification with credential issuance:

1. Backend returns JWT and IRMA server URL
2. Client starts session with IRMA server
3. IRMA server returns session pointer
4. Client opens Yivi app with session pointer
5. User accepts credentials in Yivi app

---

## Related Documentation

- [go-passport-issuer Repository](https://github.com/privacybydesign/go-passport-issuer)
- [GMRTD Library](https://github.com/gmrtd/gmrtd)
- [IRMA Documentation](https://irma.app/docs/)
