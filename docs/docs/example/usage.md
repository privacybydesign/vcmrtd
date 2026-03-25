# Using the Example App

This guide walks through the complete flow of reading a travel document with the example application.

## Step 1: Choose Reading Mode

When you open the app, you'll see two options:

- **Camera Mode**: Scan the MRZ using the device camera (recommended)
- **Manual Mode**: Enter MRZ data manually

<img src="/vcmrtd/images/home.jpg" alt="Home Screen" width="200" />

Camera mode is faster and less error-prone for passports with clear MRZ printing.

## Step 2: Provide MRZ Data

### Camera Mode

Point the camera at the Machine Readable Zone on the passport's data page. The MRZ consists of two lines of text at the bottom of the page.

<img src="/vcmrtd/images/scan.jpg" alt="MRZ Scanning" width="200" />

The app will automatically detect and extract:
- Document number
- Date of birth
- Expiry date

### Manual Mode

If camera scanning isn't working, enter the data manually:

1. **Document Number**: 9-character passport number
2. **Date of Birth**: Your birth date (YYMMDD format)
3. **Expiry Date**: Passport expiry date (YYMMDD format)

:::tip
The document number is typically found in the top right of the passport data page, and also encoded in the MRZ.
:::

## Step 3: Position for NFC Reading

Once MRZ data is captured, the app will prompt you to position the passport for NFC reading.

<img src="/vcmrtd/images/info.jpg" alt="NFC Positioning" width="200" />

### Tips for Successful NFC Reading

1. **Enable NFC**: Ensure NFC is enabled in your device settings
2. **Remove cases**: Phone cases can interfere with NFC
3. **Find the chip**: The NFC chip is usually near the photo, embedded in the cover
4. **Stay still**: Keep both the phone and passport stationary during reading
5. **Flat surface**: Place the passport on a flat surface if possible

### Chip Location by Document Type

| Document | Typical Chip Location |
|----------|----------------------|
| Passport (booklet) | Front cover, near the photo |
| Passport (card) | Center of the card |
| ID Card | Center or corner |
| Driving License | Varies by country |

## Step 4: Reading Progress

During reading, the app shows progress through various stages:

<img src="/vcmrtd/images/read.jpg" alt="Reading Progress" width="200" />

| Stage | Description |
|-------|-------------|
| Connecting | Establishing NFC connection |
| Authenticating | Performing BAC or PACE |
| Reading DG1 | Extracting MRZ data |
| Reading DG2 | Extracting facial image |
| Reading DG15 | Getting AA public key |
| Reading SOD | Getting security object |
| Active Auth | Challenge-response verification |

:::warning
Do not move the passport during reading. If connection is lost, the app will attempt to reconnect automatically.
:::

### Reading Time

Typical reading times:

- **DG1 (MRZ)**: ~1 second
- **DG2 (Photo)**: 5-15 seconds (largest data group)
- **Total**: 10-30 seconds depending on document

## Step 5: View Results

After successful reading, the app displays the extracted information:

<img src="/vcmrtd/images/result.png" alt="Results" width="200" />

### Displayed Information

- **Personal Data**: Name, nationality, date of birth, gender
- **Document Data**: Document number, issuing country, expiry date
- **Photo**: Facial image from DG2
- **Verification Status**: Results of PA and AA (if backend connected)

### Verification Indicators

| Icon | Meaning |
|------|---------|
| ✓ Green | Verification passed |
| ✗ Red | Verification failed |
| ○ Gray | Not performed |

## Troubleshooting

### "NFC not available"

- Ensure NFC is enabled in device settings
- Some devices have NFC in unusual locations
- Very old devices may not support ISO-DEP NFC

### "Authentication failed"

- Verify MRZ data was entered correctly
- Check that document number includes any leading zeros
- Ensure dates are in correct format

### "Tag was lost"

- Keep the phone and passport completely still
- Try a different position
- Remove any phone case
- Some passports have weak NFC chips

### "Reading timeout"

- The photo (DG2) is large and may take time
- Keep the connection stable
- Try in an area with less electromagnetic interference

## Privacy Note

:::info
No personal data is sent to any server during the NFC reading process. All document reading and parsing happens locally on your device.

Server communication only occurs during:
1. Starting a verification session (session ID only)
2. Verifying the document (encrypted data groups and signatures)

The server does not store personal data after verification.
:::

## Next Steps

- [Integration Guide](../integration) - Integrate VCMRTD in your own app
- [API Reference](../api/document-reader) - Learn about the DocumentReader API
