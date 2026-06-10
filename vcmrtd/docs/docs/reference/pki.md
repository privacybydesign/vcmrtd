# Public Key Infrastructure

E-passport security relies on a hierarchical Public Key Infrastructure (PKI). This document explains the PKI structure and how VCMRTD uses it.

## PKI Hierarchy

The PKI hierarchy consists of:

1. **ICAO PKD (Public Key Directory)** - Central repository
2. **Country Signing CA (CSCA)** - Root of trust for each country
3. **Document Signer (DS)** - Signs individual passports
4. **Passport (EF.SOD)** - Contains signed data

## Country Signing CA (CSCA)

The CSCA is the root certificate authority for a country's passport system.

### Characteristics

- Self-signed certificate
- Long validity (10-20+ years)
- High-security key storage (HSM)
- Signs Document Signer certificates

### Trust Establishment

Countries exchange CSCA certificates through:
- Bilateral agreements
- ICAO Public Key Directory (PKD)
- Regional organizations (EU Master List)

## Document Signer (DS)

Document Signers are intermediate certificates that sign passports.

### Characteristics

- Signed by CSCA
- One DS may sign many passports
- Countries may have multiple active DS certificates
- Embedded in EF.SOD on each passport

### Certificate Contents

- Subject: Issuing authority
- Issuer: Country Signing CA
- Public key
- Validity period
- Extended key usage: Document Signing

## Security Object Document (EF.SOD)

EF.SOD contains the signed security data for a passport.

### Structure

EF.SOD is a CMS SignedData structure containing:
- Version
- Digest Algorithms
- Encapsulated Content (LDS Security Object with hash algorithm and data group hash values)
- Certificates (Document Signer Certificate)
- Signer Info (signature algorithm and value)

### Verification Process

1. Extract DS certificate from EF.SOD
2. Verify DS certificate against trusted CSCA
3. Verify signature on LDS Security Object
4. Hash each data group
5. Compare computed hashes to signed hashes

## Masterlists

A masterlist is a collection of trusted CSCA certificates.

### VCMRTD Masterlist Support

go-passport-issuer includes:
- **Dutch Masterlist**: Netherlands CSCA and related certificates
- **German Masterlist**: German CSCA and related certificates