# API reference

This document describes the HTTP API exposed by the Go Passport Issuer backend.

## Health Check

**Endpoint:** `GET /api/health`

Returns a simple status object that can be used by load balancers or monitoring to verify that the service is running.

**Response**

```json
{
  "ok": true
}
```

## Start Passport Validation

**Endpoint:** `POST /api/start-validation`

Starts a new passport validation session. The body of the request is empty.

**Response**

```json
{
  "session_id": "4f3c2a1b5e6d7c8f9a0b1c2d3e4f5a6b",
  "nonce": "d4e5f6a7"
}
```

`session_id` is a unique identifier for the validation session and `nonce` is an 8 byte hex string that must be echoed back in the next step.

## Verify and Issue Passport Credential

**Endpoint:** `POST /api/verify-and-issue`

Submits the e-passport data for validation. The request body must conform to the `PassportValidationRequest` schema.

**Request body**

```json
{
  "session_id": "4f3c2a1b5e6d7c8f9a0b1c2d3e4f5a6b",
  "nonce": "d4e5f6a7",
  "data_groups": {
    "DG1": "<Base64 encoded DG1 data>",
    "DG2": "<Base64 encoded DG2 data>"
  },
  "ef_sod": "<Base64 encoded EF.SOD file>",
  "aa_signature": "<Base64 encoded active authentication signature>"
}
```

`data_groups` is a mapping of ICAO data group numbers to their base64 encoded contents. `ef_sod` contains the base64 encoded Security Object Document file. `aa_signature` is optional and carries the base64 encoded active authentication signature when active authentication is performed.

**Response**

```json
{
  "jwt": "<JWT containing the passport credential>",
  "irma_server_url": "https://is.staging.yivi.app"
}
```

The returned JWT can be submitted to the IRMA server referenced by `irma_server_url` to complete issuance.

## Mobile Application Association Files

The server also exposes endpoints that return association files used by mobile operating systems to link the web service to native applications.

### Android

**Endpoint:** `GET /.well-known/assetlinks.json`

Returns an [Android Digital Asset Links](https://developer.android.com/training/app-links/verify-site-associations) declaration.

### iOS

**Endpoints:**

- `GET /.well-known/apple-app-site-association`
- `GET /apple-app-site-association`

Both endpoints return the [Apple App Site Association](https://developer.apple.com/documentation/xcode/supporting-associated-domains) file.