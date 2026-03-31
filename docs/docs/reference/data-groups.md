# Data Groups

ICAO defines 16 data groups (DG1-DG16) that can be stored on a travel document chip. This document describes each data group and how to access them with VCMRTD.

## Overview

| DG | Name | Content | Required | Protected |
|----|------|---------|----------|-----------|
| DG1 | MRZ | Machine Readable Zone data | Yes | No |
| DG2 | Facial Image | Encoded face photograph | Yes | No |
| DG3 | Fingerprints | Encoded fingerprint images | No | Yes (EAC) |
| DG4 | Iris | Encoded iris images | No | Yes (EAC) |
| DG5 | Displayed Portrait | Optional displayed photo | No | No |
| DG6 | Reserved | Reserved for future use | No | - |
| DG7 | Signature | Handwritten signature/mark | No | No |
| DG8 | Data Features | Encoded security features | No | No |
| DG9 | Structure Features | Structural info | No | No |
| DG10 | Substance Features | Material info | No | No |
| DG11 | Additional Personal Details | Extra personal data | No | No |
| DG12 | Additional Document Details | Extra document data | No | No |
| DG13 | Optional Details | Discretionary data | No | No |
| DG14 | Security Options | CA public key, security info | No | No |
| DG15 | Active Authentication | AA public key | No | No |
| DG16 | Persons to Notify | Emergency contact info | No | No |

## DG1 - MRZ Data

Contains the Machine Readable Zone information in electronic form.

### Contents

- Document type (P, I, etc.)
- Issuing country code
- Holder's name
- Document number
- Nationality
- Date of birth
- Sex
- Date of expiry
- Optional data

### Encoding

DG1 uses ASN.1 encoding with the MRZ stored as ASCII text.

### Access in VCMRTD

Include DataGroups.dg1 in your DocumentReaderConfig's readIfAvailable set. After reading, access document properties like documentNumber, firstName, lastName, nationality, and dateOfBirth.

## DG2 - Facial Image

Contains the holder's facial photograph.

### Contents

- Biometric header
- Facial image in JPEG or JPEG2000 format
- Image dimensions and quality metrics

### Size

DG2 is typically the largest data group:
- Minimum: ~15 KB
- Typical: 20-50 KB
- Maximum: Several hundred KB (high-resolution)

### Access in VCMRTD

Include DataGroups.dg2 in your config. After reading, access the photo property on the document.

:::note
Reading DG2 takes the longest due to its size. Expect 5-15 seconds depending on the document.
:::

## DG3 - Fingerprints

Contains encoded fingerprint images. **Protected by EAC**.

### Contents

- Biometric header
- Fingerprint images (typically index fingers)
- Image format and quality metrics

### Access Requirements

Accessing DG3 requires:
1. Completed Chip Authentication
2. Terminal Authentication with valid DV certificate
3. DV certificate chain to CVCA

### VCMRTD Support

DG3 reading is not currently supported due to Terminal Authentication infrastructure requirements.

## DG4 - Iris

Contains encoded iris images. **Protected by EAC**.

Similar to DG3, requires EAC and is not commonly used.

## DG5 - Displayed Portrait

Optional copy of the printed portrait for display purposes.

### Usage

Some countries include a lower-resolution version of the photo for display in reader applications.

## DG7 - Signature/Mark

Contains an image of the holder's signature or mark.

### Contents

- Signature image (grayscale or binary)
- Image format information

### Access in VCMRTD

Include DataGroups.dg7 in your config.

## DG11 - Additional Personal Details

Contains additional personal information not in the MRZ.

### Possible Contents

- Full name in national characters
- Other names
- Personal number
- Place of birth
- Permanent address
- Telephone number
- Profession
- Title
- Personal summary
- Custody information

### Access in VCMRTD

Include DataGroups.dg11 in your config. Content varies by issuing country.

## DG12 - Additional Document Details

Contains additional document information.

### Possible Contents

- Issuing authority
- Date of issue
- Tax/exit requirements
- Endorsements
- Image of front page

## DG13 - Optional Details

Discretionary data defined by the issuing state.

### Contents

Varies by country. May include:
- National ID number
- Voter registration
- Healthcare identifiers
- Other government identifiers

## DG14 - Security Options

Contains security-related information for EAC.

### Contents

- Chip Authentication public key
- Chip Authentication protocol info
- Security options

### Usage

Read during EAC to get Chip Authentication parameters.

## DG15 - Active Authentication

Contains the public key for Active Authentication.

### Contents

- RSA or ECDSA public key
- Key algorithm identifier

### Access in VCMRTD

Include DataGroups.dg15 in your config. Required for Active Authentication.

### Importance

- Essential for detecting cloned chips
- Not all passports include DG15
- Public key used to verify AA signature

## DG16 - Persons to Notify

Contains emergency contact information.

### Possible Contents

- Name of person to notify
- Address
- Phone number
- Relationship

### Usage

Rarely implemented in practice.

## Configuring Data Groups

### Minimal Configuration

Include DataGroups.dg1 (required) and DataGroups.dg2 (required) in your readIfAvailable set.

### With Active Authentication

Add DataGroups.dg15 to enable Active Authentication.

### Full Read (where supported)

Include dg1, dg2, dg5, dg7, dg11, dg12, dg13, dg14, and dg15 for maximum data extraction.

## EF.COM

The EF.COM file lists which data groups are present on the chip.

VCMRTD reads EF.COM automatically to determine available data groups.

## EF.SOD

The Security Object Document contains:
- Hash of each data group
- Digital signature from Document Signer
- Document Signer Certificate

EF.SOD is always read for Passive Authentication.

## Reading Time Estimates

| Data Group | Typical Size | Read Time |
|------------|--------------|-----------|
| DG1 | ~200 bytes | &lt;1 sec |
| DG2 | 20-50 KB | 5-15 sec |
| DG7 | 5-15 KB | 2-5 sec |
| DG11 | ~1 KB | &lt;1 sec |
| DG15 | ~500 bytes | &lt;1 sec |
| EF.SOD | 2-5 KB | 1-2 sec |

Total reading time depends on which groups are present and their sizes.

## Country Variations

Different countries include different optional data groups:

| Country | DG7 | DG11 | DG12 | DG13 | DG15 |
|---------|-----|------|------|------|------|
| Netherlands | ✓ | ✓ | ✓ | - | ✓ |
| Germany | ✓ | ✓ | ✓ | - | ✓ |
| France | - | ✓ | - | - | ✓ |
| USA | - | - | - | - | - |
| UK | - | ✓ | - | - | - |

Note: This table is indicative only. Actual support varies by passport generation and issuing authority.
