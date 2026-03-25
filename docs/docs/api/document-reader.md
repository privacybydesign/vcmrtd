# DocumentReader API

The `DocumentReader` class is the main entry point for reading travel documents with VCMRTD.

## Overview

`DocumentReader` is a generic class that manages the complete document reading lifecycle, including NFC connection, authentication, data group reading, and Active Authentication.

```dart
class DocumentReader<DocType extends DocumentData> extends Notifier<DocumentReaderState>
```

## Constructor

```dart
DocumentReader({
  required DocumentParser<DocType> documentParser,
  required DataGroupReader dataGroupReader,
  required NfcProvider nfc,
  required DocumentReaderConfig config,
})
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `documentParser` | `DocumentParser<DocType>` | Parser for the specific document type (passport, ID card, or driving license) |
| `dataGroupReader` | `DataGroupReader` | Low-level reader for data groups |
| `nfc` | `NfcProvider` | NFC communication provider |
| `config` | `DocumentReaderConfig` | Configuration specifying which data groups to read |

## Methods

### readDocument

Reads the document and returns the parsed data along with raw data for backend verification.

```dart
Future<(DocType, RawDocumentData)?> readDocument({
  required IosNfcMessageMapper iosNfcMessages,
  NonceAndSessionId? activeAuthenticationParams,
})
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `iosNfcMessages` | `IosNfcMessageMapper` | Function that returns iOS NFC dialog messages for each state |
| `activeAuthenticationParams` | `NonceAndSessionId?` | Optional session parameters for Active Authentication |

#### Returns

A tuple of `(DocType, RawDocumentData)` on success, or `null` if reading failed or was cancelled.

#### Example

```dart
final result = await reader.readDocument(
  iosNfcMessages: (state) => switch (state) {
    DocumentReaderConnecting() => 'Hold passport near phone',
    DocumentReaderAuthenticating() => 'Authenticating...',
    DocumentReaderReadingDataGroup() => 'Reading data...',
    _ => 'Processing...',
  },
  activeAuthenticationParams: session,
);

if (result != null) {
  final (document, rawData) = result;
  // Use document data...
}
```

### reset

Resets the reader to its initial state.

```dart
void reset()
```

### cancel

Cancels an ongoing read operation.

```dart
Future<void> cancel()
```

### checkNfcAvailability

Checks if NFC is available and enabled on the device.

```dart
Future<void> checkNfcAvailability()
```

### getLogs / getSensitiveLogs

Returns logs from the reading process for debugging.

```dart
String getLogs()
String getSensitiveLogs()
```

## States

The `DocumentReader` emits states as it progresses. Access the current state via the `state` property.

### DocumentReaderPending

Initial state, ready to begin reading.

### DocumentReaderNfcUnavailable

NFC is not available or not enabled on the device.

### DocumentReaderConnecting

Establishing NFC connection with the document.

### DocumentReaderAuthenticating

Performing BAC or PACE authentication.

### DocumentReaderReadingCardAccess

Reading EF.CardAccess for PACE parameters (only for PACE authentication).

### DocumentReaderReadingCOM

Reading EF.COM to determine which data groups are present.

### DocumentReaderReadingDataGroup

Reading a specific data group.

```dart
class DocumentReaderReadingDataGroup extends DocumentReaderState {
  final String dataGroup;  // e.g., "DG1", "DG2"
  final double progress;   // 0.0 to 1.0
}
```

### DocumentReaderReadingSOD

Reading the Security Object Document (EF.SOD).

### DocumentReaderActiveAuthentication

Performing Active Authentication challenge-response.

### DocumentReaderSuccess

Reading completed successfully.

### DocumentReaderFailed

Reading failed with an error.

```dart
class DocumentReaderFailed extends DocumentReaderState {
  final DocumentReadingError error;
  final String logs;
  final String sensitiveLogs;
}
```

### DocumentReaderCancelled

Reading was cancelled by the user.

### DocumentReaderCancelling

Cancellation is in progress.

## Configuration

### DocumentReaderConfig

Specifies which data groups to read.

```dart
class DocumentReaderConfig {
  final Set<DataGroups> readIfAvailable;

  const DocumentReaderConfig({required this.readIfAvailable});
}
```

#### Example

```dart
final config = DocumentReaderConfig(
  readIfAvailable: {
    DataGroups.dg1,   // MRZ data (required for all documents)
    DataGroups.dg2,   // Facial image
    DataGroups.dg7,   // Signature image
    DataGroups.dg11,  // Additional personal data
    DataGroups.dg15,  // Active Authentication public key
  },
);
```

### DataGroups Enum

The following table describes data groups for passports and ID cards. Driving licenses use a different data group layout.

| Value | Description | Required |
|-------|-------------|----------|
| `dg1` | MRZ data | Yes |
| `dg2` | Facial image | Yes |
| `dg3` | Fingerprint (EAC required) | No |
| `dg4` | Iris (EAC required) | No |
| `dg5` | Displayed portrait | No |
| `dg6` | Reserved | No |
| `dg7` | Signature/mark image | No |
| `dg8` | Data features | No |
| `dg9` | Structure features | No |
| `dg10` | Substance features | No |
| `dg11` | Additional personal details | No |
| `dg12` | Additional document details | No |
| `dg13` | Optional details | No |
| `dg14` | Security options | No |
| `dg15` | Active Authentication public key | No* |
| `dg16` | Person(s) to notify | No |

*DG15 is required if you want to perform Active Authentication.

## Document Parsers

### PassportParser

For reading ePassports.

```dart
final parser = PassportParser();
```

### DrivingLicenceParser

For reading Dutch electronic driving licenses.

```dart
final parser = DrivingLicenceParser();
```

## Access Keys

### DBAKey

Document Basic Access key derived from MRZ data.

```dart
final accessKey = DBAKey(
  documentNumber: 'AB1234567',
  dateOfBirth: DateTime(1990, 1, 15),
  dateOfExpiry: DateTime(2030, 1, 15),
);
```

### CANKey

Card Access Number key for PACE authentication (alternative to MRZ-derived key).

```dart
final accessKey = CANKey(can: '123456');
```

## Progress Tracking

Use `progressForState()` to get a normalized progress value:

```dart
double progressForState(DocumentReaderState state)
```

Returns a value between 0.0 and 1.0:

| State | Progress |
|-------|----------|
| Pending | 0.0 |
| Connecting | 0.1 |
| CardAccess | 0.2 |
| Authenticating | 0.3 |
| ReadingCOM | 0.4 |
| ReadingDataGroup | 0.5-0.75 |
| ReadingSOD | 0.8 |
| ActiveAuth | 0.9 |
| Success | 1.0 |

## Error Handling

```dart
enum DocumentReadingError {
  unknown,
  timeoutWaitingForTag,
  tagLost,
  failedToInitiateSession,
  invalidatedByUser,
}
```

Handle errors by checking the state:

```dart
if (state is DocumentReaderFailed) {
  final error = state.error;
  final logs = state.logs;
  // Handle error...
}
```

## Complete Example

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

// Create a provider for the document reader
final documentReaderProvider = NotifierProvider<DocumentReader<PassportData>, DocumentReaderState>(() {
  final accessKey = DBAKey(
    documentNumber: 'AB1234567',
    dateOfBirth: DateTime(1990, 1, 15),
    dateOfExpiry: DateTime(2030, 1, 15),
  );

  final nfc = NfcProvider();
  return DocumentReader(
    documentParser: PassportParser(),
    dataGroupReader: DataGroupReader(accessKey: accessKey, nfc: nfc),
    nfc: nfc,
    config: DocumentReaderConfig(
      readIfAvailable: {DataGroups.dg1, DataGroups.dg2, DataGroups.dg15},
    ),
  );
});

// In your widget
class PassportReaderWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentReaderProvider);
    final reader = ref.read(documentReaderProvider.notifier);

    return Column(
      children: [
        LinearProgressIndicator(value: progressForState(state)),
        Text(_getStatusText(state)),
        ElevatedButton(
          onPressed: () => _startReading(reader),
          child: Text('Start Reading'),
        ),
      ],
    );
  }

  String _getStatusText(DocumentReaderState state) {
    return switch (state) {
      DocumentReaderPending() => 'Ready to scan',
      DocumentReaderConnecting() => 'Connecting...',
      DocumentReaderAuthenticating() => 'Authenticating...',
      DocumentReaderReadingDataGroup(:final dataGroup) => 'Reading $dataGroup...',
      DocumentReaderSuccess() => 'Complete!',
      DocumentReaderFailed(:final error) => 'Error: $error',
      _ => 'Processing...',
    };
  }

  Future<void> _startReading(DocumentReader reader) async {
    final result = await reader.readDocument(
      iosNfcMessages: (state) => _getStatusText(state),
    );

    if (result != null) {
      final (document, rawData) = result;
      // Process document...
    }
  }
}
```
