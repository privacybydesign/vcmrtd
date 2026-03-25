# PassportIssuer API

The `PassportIssuer` interface and its default implementation handle communication with the backend verification service.

## Overview

```dart
abstract class PassportIssuer {
  Future<NonceAndSessionId> startSessionAtPassportIssuer();
  Future<IrmaSessionPointer> startIrmaIssuanceSession(RawDocumentData documentData, DocumentType docType);
  Future<VerificationResponse> verifyPassport(RawDocumentData passportData);
  Future<VerificationResponse> verifyDrivingLicence(RawDocumentData drivingLicenceData);
}
```

## DefaultPassportIssuer

The default implementation that communicates with [go-passport-issuer](https://github.com/privacybydesign/go-passport-issuer).

### Constructor

```dart
DefaultPassportIssuer({required String hostName})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `hostName` | `String` | Base URL of the go-passport-issuer backend |

### Example

```dart
final issuer = DefaultPassportIssuer(
  hostName: 'https://passport-issuer.example.com',
);
```

## Methods

### startSessionAtPassportIssuer

Starts a verification session and returns a nonce for Active Authentication.

```dart
Future<NonceAndSessionId> startSessionAtPassportIssuer()
```

#### Returns

`NonceAndSessionId` containing:
- `sessionId`: Unique identifier for the verification session
- `nonce`: Challenge bytes for Active Authentication

#### Example

```dart
final session = await issuer.startSessionAtPassportIssuer();
print('Session: ${session.sessionId}');
print('Nonce: ${session.nonce}');
```

### verifyPassport

Verifies passport data server-side without issuing credentials.

```dart
Future<VerificationResponse> verifyPassport(RawDocumentData passportData)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `passportData` | `RawDocumentData` | Raw data from the document reader |

#### Returns

`VerificationResponse` with verification results.

#### Example

```dart
final result = await reader.readDocument(...);
if (result != null) {
  final (_, rawData) = result;
  final verification = await issuer.verifyPassport(rawData);

  if (verification.passiveAuthenticationPassed) {
    print('Document is authentic');
  }
}
```

### verifyDrivingLicence

Verifies driving licence data server-side without issuing credentials.

```dart
Future<VerificationResponse> verifyDrivingLicence(RawDocumentData drivingLicenceData)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `drivingLicenceData` | `RawDocumentData` | Raw data from the document reader |

#### Returns

`VerificationResponse` with verification results.

### startIrmaIssuanceSession

Verifies document data and initiates a Verifiable Credential issuance session.

```dart
Future<IrmaSessionPointer> startIrmaIssuanceSession(
  RawDocumentData documentData,
  DocumentType docType,
)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `documentData` | `RawDocumentData` | Raw data from the document reader |
| `docType` | `DocumentType` | Type of document (passport, identityCard, drivingLicence) |

#### Returns

`IrmaSessionPointer` that can be used to open the Yivi app for credential acceptance.

#### Example

```dart
final sessionPointer = await issuer.startIrmaIssuanceSession(
  rawData,
  DocumentType.passport,
);

// Use sessionPointer to construct Yivi universal link
final yiviUrl = 'https://irma.app/-/session/${sessionPointer.sessionPtr}';
```

## Data Types

### NonceAndSessionId

Session information returned by `startSessionAtPassportIssuer`.

```dart
class NonceAndSessionId {
  final String sessionId;
  final String nonce;
}
```

### RawDocumentData

Raw document data to be sent for verification.

```dart
class RawDocumentData {
  final Map<String, String> dataGroups;  // Hex-encoded data groups
  final String efSod;                     // Hex-encoded EF.SOD
  final String? sessionId;                // Session ID for AA
  final Uint8List? nonce;                 // Nonce used for AA
  final Uint8List? aaSignature;           // Active Authentication signature
}
```

### VerificationResponse

Result of server-side verification.

```dart
class VerificationResponse {
  final bool passiveAuthenticationPassed;
  final bool activeAuthenticationPassed;
  // Additional fields may be present
}
```

### DocumentType

Enum for document types.

```dart
enum DocumentType {
  passport,
  identityCard,
  drivingLicence,
}
```

### IrmaSessionPointer

Session pointer for IRMA/Yivi credential issuance.

```dart
class IrmaSessionPointer {
  final String sessionPtr;
  // Additional session information
}
```

## Custom Implementation

You can provide a custom implementation for testing or alternative backends:

```dart
class MockPassportIssuer implements PassportIssuer {
  @override
  Future<NonceAndSessionId> startSessionAtPassportIssuer() async {
    return NonceAndSessionId(
      sessionId: 'test-session',
      nonce: 'test-nonce',
    );
  }

  @override
  Future<VerificationResponse> verifyPassport(RawDocumentData data) async {
    // Simulate verification
    return VerificationResponse(
      passiveAuthenticationPassed: true,
      activeAuthenticationPassed: true,
    );
  }

  // ... implement other methods
}
```

## Error Handling

The issuer methods throw exceptions on failure:

```dart
try {
  final session = await issuer.startSessionAtPassportIssuer();
} on Exception catch (e) {
  // Handle network error, server error, etc.
  print('Failed to start session: $e');
}
```

Common error scenarios:
- Network connectivity issues
- Server not reachable
- Invalid or expired session
- Verification failure (signature mismatch, invalid certificate chain)

## Complete Example

```dart
import 'package:vcmrtd/vcmrtd.dart';

class VerificationService {
  final PassportIssuer issuer;

  VerificationService({required this.issuer});

  Future<VerificationResult> verifyDocument({
    required DocumentReader reader,
  }) async {
    // 1. Start session
    final session = await issuer.startSessionAtPassportIssuer();

    // 2. Read document with AA
    final result = await reader.readDocument(
      iosNfcMessages: (state) => 'Reading...',
      activeAuthenticationParams: session,
    );

    if (result == null) {
      throw VerificationException('Failed to read document');
    }

    final (document, rawData) = result;

    // 3. Verify server-side
    final verification = await issuer.verifyPassport(rawData);

    return VerificationResult(
      document: document,
      isAuthentic: verification.passiveAuthenticationPassed,
      isNotCloned: verification.activeAuthenticationPassed,
    );
  }
}

class VerificationResult {
  final DocumentData document;
  final bool isAuthentic;
  final bool isNotCloned;

  VerificationResult({
    required this.document,
    required this.isAuthentic,
    required this.isNotCloned,
  });
}

class VerificationException implements Exception {
  final String message;
  VerificationException(this.message);
}
```
