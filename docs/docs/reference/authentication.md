# Authentication Protocols

MRTD security involves multiple authentication protocols. This document explains each protocol and how VCMRTD implements them.

## Overview

| Protocol | Purpose | Where Performed |
|----------|---------|-----------------|
| BAC | Prevent unauthorized reading | Client (VCMRTD) |
| PACE | Prevent unauthorized reading (stronger) | Client (VCMRTD) |
| PA | Verify data integrity | Server (go-passport-issuer) |
| AA | Prevent chip cloning | Client + Server |
| EAC | Access protected biometrics | Partial support |

## Basic Access Control (BAC)

BAC prevents unauthorized reading of passport data by requiring knowledge of MRZ information.

### How It Works

BAC uses a challenge-response protocol:
1. Reader derives Kenc and Kmac keys from MRZ data
2. Reader requests a challenge from the chip (GET CHALLENGE)
3. Chip returns random bytes (RND.IC)
4. Reader generates its own random data, encrypts with Kenc, and MACs with Kmac
5. Reader sends EXTERNAL AUTHENTICATE command
6. Chip verifies the data, generates its own key material
7. Both parties derive session keys (KSenc, KSmac)

### Key Derivation

Session keys are derived from:
- Document number (from MRZ)
- Date of birth (from MRZ)
- Date of expiry (from MRZ)

### VCMRTD Implementation

Create a DBAKey with documentNumber, dateOfBirth, and dateOfExpiry to use BAC authentication.

### Limitations

- Susceptible to eavesdropping if MRZ data is known
- Uses 3DES encryption (considered weak by modern standards)
- Brute-force attacks possible with sufficient captured traffic

## PACE (Password Authenticated Connection Establishment)

PACE is a stronger alternative to BAC, required on EU passports since 2014.

### Advantages Over BAC

- Uses Diffie-Hellman key agreement
- Resistant to eavesdropping
- Uses AES encryption
- Multiple password sources (MRZ, CAN, PIN)

### How It Works

PACE uses the following protocol:
1. Reader selects PACE via MSE:Set AT
2. Reader requests encrypted nonce from chip
3. Reader decrypts nonce with password-derived key
4. Diffie-Hellman key agreement occurs
5. Keys are mapped to new domain parameters
6. Authentication tokens are exchanged and verified
7. Session is established

### Password Sources

| Source | Description |
|--------|-------------|
| MRZ | Derived from document number, DOB, expiry |
| CAN | Card Access Number (6 digits printed on card) |
| PIN | Personal identification number |

### VCMRTD Implementation

VCMRTD automatically attempts PACE if BAC fails and EF.CardAccess is present. You can also explicitly use CAN with CANKey.

## Passive Authentication (PA)

PA verifies that passport data is genuine and unmodified. It is the **only mandatory** security protocol.

### How It Works

1. **At Issuance**:
   - Issuing authority hashes all data groups
   - Signs the hash collection with Document Signer key
   - Stores signature in EF.SOD

2. **At Verification**:
   - Read EF.SOD from chip
   - Verify signature against Document Signer Certificate
   - Verify certificate chain to trusted CSCA
   - Hash each data group, compare to signed hashes

### Why Server-Side?

PA requires:
- Access to trusted CSCA certificates (masterlists)
- Regular masterlist updates
- Certificate Revocation List (CRL) checking
- Secure key storage

These are better handled server-side.

### VCMRTD Implementation

VCMRTD reads EF.SOD and sends it to go-passport-issuer for verification. Check the passiveAuthenticationPassed flag in the verification response.

## Active Authentication (AA)

AA prevents chip cloning by proving the chip possesses a unique private key.

### How It Works

1. Server generates a nonce (challenge)
2. Reader sends nonce to chip via INTERNAL AUTHENTICATE
3. Chip signs the nonce with its private key
4. Reader sends signature and DG15 (public key) to server
5. Server verifies the signature with the public key

### Key Points

- Private key never leaves the chip
- Public key stored in DG15
- Challenge-response prevents replay
- Not all passports support AA

### VCMRTD Implementation

Start a session to get a nonce, read the document with activeAuthenticationParams set to the session, then verify with the backend. Check activeAuthenticationPassed in the response.

### Limitations

- Optional protocol - not all passports include DG15
- Requires server round-trip for nonce
- Only proves chip authenticity, not data integrity

## Extended Access Control (EAC)

EAC protects sensitive biometric data (fingerprints, iris) on EU passports.

### Components

1. **Chip Authentication (CA)**: Proves chip is genuine, establishes secure session
2. **Terminal Authentication (TA)**: Proves terminal is authorized to read protected data

### Chip Authentication

Similar to AA but:
- Uses Diffie-Hellman for key agreement
- Establishes stronger session keys
- Public key in DG14 or EF.CardSecurity

### Terminal Authentication

Requires:
- Certificate issued by Document Verifier (DV)
- DV certificate issued by Country Verifying CA (CVCA)
- Countries must exchange CVCA certificates

### Current Support

VCMRTD has partial EAC support:
- ✓ Chip Authentication
- ✗ Terminal Authentication (requires infrastructure)

Without TA, protected data groups (DG3, DG4) cannot be read.

## Protocol Selection

VCMRTD automatically selects the best available protocol:

1. Try BAC
2. If BAC fails, read EF.CardAccess
3. Try PACE with MRZ-derived key

## Security Recommendations

1. **Always verify server-side**: Client-side checks can be bypassed
2. **Use both PA and AA**: PA verifies data, AA prevents cloning
3. **Check certificate validity**: Ensure certificates haven't expired or been revoked
4. **Keep masterlists updated**: New certificates are regularly issued
5. **Handle failures gracefully**: Not all documents support all protocols
