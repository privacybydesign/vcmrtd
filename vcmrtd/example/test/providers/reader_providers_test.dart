// Coverage tests for the reader provider factories.
//
// These exercise the bodies of passportReaderProvider, identityCardReaderProvider
// and drivingLicenceReaderProvider (both the version-1 BAC path and the
// CAN/non-version-1 path). Reading the provider constructs the DocumentReader
// but does not touch any NFC hardware.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/reader_providers.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';

ScannedPassportMRZ _passportMrz({DocumentType type = DocumentType.passport}) {
  return ScannedPassportMRZ(
    documentNumber: 'L898902C3',
    countryCode: 'UTO',
    dateOfBirth: DateTime(1974, 8, 12),
    dateOfExpiry: DateTime(2030, 1, 1),
    documentType: type,
  );
}

ScannedDriverLicenseMRZ _driverMrz({required String version}) {
  // The non-version-1 (CAN) path requires a 10-character capital-alphanumeric
  // document number; the version-1 (BAP) path accepts any string.
  return ScannedDriverLicenseMRZ(
    documentNumber: version == '1' ? '123456789' : 'AB12345678',
    countryCode: 'NLD',
    version: version,
    randomData: 'RANDOM123',
    configuration: 'D1',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nfcChannel = MethodChannel('flutter_nfc_kit');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Make NfcProvider.nfcStatus resolve to "available" so the DocumentReader's
    // build() -> checkNfcAvailability() does not flip into NfcUnavailable.
    messenger.setMockMethodCallHandler(nfcChannel, (call) async {
      if (call.method == 'getNFCAvailability') return 'available';
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(nfcChannel, null);
  });

  group('passportReaderProvider', () {
    test('constructs a DocumentReader for a passport MRZ', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reader = container.read(passportReaderProvider(_passportMrz()).notifier);
      expect(reader, isA<DocumentReader<PassportData>>());
      expect(reader.config.shouldRead(DataGroups.dg1), isTrue);
      expect(reader.config.shouldRead(DataGroups.dg2), isTrue);
      expect(reader.config.shouldRead(DataGroups.dg16), isTrue);
    });

    test('initial state is pending', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(passportReaderProvider(_passportMrz()));
      expect(state, isA<DocumentReaderPending>());
    });

    test('same MRZ resolves to the same reader instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mrz = _passportMrz();
      final a = container.read(passportReaderProvider(mrz).notifier);
      final b = container.read(passportReaderProvider(mrz).notifier);
      expect(identical(a, b), isTrue);
    });
  });

  group('identityCardReaderProvider', () {
    test('constructs a DocumentReader for an identity card MRZ', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mrz = _passportMrz(type: DocumentType.identityCard);
      final reader = container.read(identityCardReaderProvider(mrz).notifier);
      expect(reader, isA<DocumentReader<PassportData>>());
      expect(reader.config.shouldRead(DataGroups.dg14), isTrue);
    });

    test('initial state is pending', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mrz = _passportMrz(type: DocumentType.identityCard);
      expect(container.read(identityCardReaderProvider(mrz)), isA<DocumentReaderPending>());
    });
  });

  group('drivingLicenceReaderProvider', () {
    test('version 1 uses the BAC/BAP access key path', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reader = container.read(drivingLicenceReaderProvider(_driverMrz(version: '1')).notifier);
      expect(reader, isA<DocumentReader<DrivingLicenceData>>());
      // DG5 is intentionally skipped, DG1 read.
      expect(reader.config.shouldRead(DataGroups.dg1), isTrue);
      expect(reader.config.shouldRead(DataGroups.dg5), isFalse);
      expect(reader.config.shouldRead(DataGroups.dg13), isTrue);
    });

    test('non-version-1 uses the CAN access key path', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mrz = _driverMrz(version: '2');
      final reader = container.read(drivingLicenceReaderProvider(mrz).notifier);
      expect(reader, isA<DocumentReader<DrivingLicenceData>>());
      expect(reader.config.shouldRead(DataGroups.dg1), isTrue);
      expect(container.read(drivingLicenceReaderProvider(mrz)), isA<DocumentReaderPending>());
    });

    test('initial state is pending', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(drivingLicenceReaderProvider(_driverMrz(version: '1'))), isA<DocumentReaderPending>());
    });
  });
}
