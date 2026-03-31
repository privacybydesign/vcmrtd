# MRTD Standards

Machine Readable Travel Documents (MRTDs) are built on multiple international standards. Understanding these standards helps when working with the VCMRTD library.

## ISO/IEC 14443 - Contactless Interface

ISO/IEC 14443 defines the contactless communication protocol used by electronic passports.

### Key Points

- **Frequency**: 13.56 MHz radio frequency
- **Range**: ~10 cm (proximity coupling)
- **Types**: Both Type A and Type B are permitted for e-passports
- **Speed**: Up to 848 kbit/s

### What It Covers

- Physical characteristics of the contactless interface
- Radio frequency power and signal interface
- Initialization and anti-collision procedures
- Data framing and error detection

The short read range is a security feature, making it difficult to read a passport without physical proximity.

## ISO/IEC 7816 - APDU Commands

ISO/IEC 7816 defines the command structure and file system used by smart cards, including e-passports.

### APDU Commands

After establishing the NFC connection, communication uses Application Protocol Data Units (APDUs):

| Command | Description |
|---------|-------------|
| `SELECT` | Select the e-passport application or specific files |
| `READ BINARY` | Read data from a selected file |
| `GET CHALLENGE` | Request a random challenge for authentication |
| `EXTERNAL AUTHENTICATE` | Prove knowledge of a key to the chip |
| `INTERNAL AUTHENTICATE` | Chip proves knowledge of its private key |

### File System Structure

The e-passport file system consists of:
- Master File (MF) at the root
- Dedicated File (DF) for the MRTD Application
- Elementary Files: EF.COM, EF.SOD, EF.DG1 through EF.DG16

### Application Identifier

The e-passport application is selected using its AID: `A0 00 00 02 47 10 01`

### Response Status Words

| Status | Meaning |
|--------|---------|
| `90 00` | Success |
| `69 82` | Security status not satisfied |
| `6A 82` | File not found |

## ICAO Doc 9303 - Machine Readable Travel Documents

ICAO Document 9303 is the primary standard for e-passports, defining:

- Logical Data Structure (LDS)
- Data elements and encodings
- Security protocols
- Interoperability requirements

### Data Groups

| Group | Contents | Required |
|-------|----------|----------|
| DG1 | MRZ data | Yes |
| DG2 | Facial image | Yes |
| DG3 | Fingerprints | No (EAC) |
| DG4 | Iris image | No (EAC) |
| DG5 | Displayed portrait | No |
| DG6 | Reserved | No |
| DG7 | Signature/mark | No |
| DG8-10 | Data/structure/substance features | No |
| DG11 | Additional personal details | No |
| DG12 | Additional document details | No |
| DG13 | Optional details | No |
| DG14 | Security options | No |
| DG15 | Active Authentication public key | No |
| DG16 | Persons to notify | No |

### Machine Readable Zone (MRZ)

The MRZ is printed on the passport data page and contains:
- Document type
- Issuing country
- Document number
- Date of birth
- Expiry date
- Holder's name
- Check digits

MRZ data is also stored electronically in DG1 and is used to derive access keys.

### EF.COM

Lists which data groups are present on the chip and the LDS version.

### EF.SOD (Security Object Document)

Contains:
- Hash values of all data groups
- Digital signature from Document Signer
- Document Signer Certificate

## EU Standards

The European Union has additional standards on top of ICAO requirements.

### BSI TR-03110

Defines Extended Access Control (EAC) with:
- **Chip Authentication (CA)**: Verify chip authenticity, establish session keys
- **Terminal Authentication (TA)**: Authorize terminal to access protected data

Required for accessing fingerprints and iris data on EU passports.

### PACE (Password Authenticated Connection Establishment)

Stronger replacement for BAC:
- Uses Diffie-Hellman key agreement
- Resistant to eavesdropping
- Can use MRZ, PIN, or CAN (Card Access Number)

EU passports since 2014 must support PACE.

### EF.CardAccess

Contains PACE parameters:
- Supported protocols
- Domain parameters
- Algorithm identifiers

## LDS Versions

| Version | Features |
|---------|----------|
| LDS 1.7 | Data groups 1-16 |
| LDS 2.0 | Data groups 1-19, additional applications |

Most passports use LDS 1.7 or 1.8.

## Protocol Support Matrix

| Protocol | ICAO Required | EU Required | VCMRTD Support |
|----------|---------------|-------------|----------------|
| BAC | Optional | Until 2018 | ✓ |
| PACE | Optional | Since 2014 | ✓ |
| PA | Mandatory | Mandatory | Via backend |
| AA | Optional | Optional | ✓ |
| CA | Optional | For EAC | Partial |
| TA | Optional | For EAC | Partial |

## References

- [ICAO Doc 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303) - Machine Readable Travel Documents
- [BSI TR-03110](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/Technische-Richtlinien/TR-nach-Thema-sortiert/tr03110/tr-03110.html) - Advanced Security Mechanisms
- [ISO/IEC 14443](https://www.iso.org/standard/73598.html) - Contactless Interface
- [ISO/IEC 7816](https://www.iso.org/standard/54550.html) - Smart Card Commands
