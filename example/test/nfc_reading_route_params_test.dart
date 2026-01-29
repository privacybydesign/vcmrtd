import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';

void main() {
  group('NfcReadingRouteParams', () {
    final testDateOfBirth = DateTime(1990, 6, 8);
    final testDateOfExpiry = DateTime(2025, 12, 31);

    group('toQueryParams and fromQueryParams - Passport', () {
      test('should serialize and deserialize passport correctly', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'L898902C3',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.passport,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.passport,
        );

        final queryParams = params.toQueryParams();
        final reconstructed = NfcReadingRouteParams.fromQueryParams(queryParams);

        expect(reconstructed.documentType, equals(DocumentType.passport));
        expect(reconstructed.scannedMRZ.documentNumber, equals('L898902C3'));
        expect(reconstructed.scannedMRZ.countryCode, equals('UTO'));
        expect(reconstructed.scannedMRZ.documentType, equals(DocumentType.passport));

        final passportMRZ = reconstructed.scannedMRZ as ScannedPassportMRZ;
        expect(passportMRZ.dateOfBirth, equals(testDateOfBirth));
        expect(passportMRZ.dateOfExpiry, equals(testDateOfExpiry));
      });

      test('should use "passport" string for passport type', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'L898902C3',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.passport,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.passport,
        );

        final queryParams = params.toQueryParams();
        expect(queryParams['document_type'], equals('passport'));
      });
    });

    group('toQueryParams and fromQueryParams - Identity Card', () {
      test('should serialize and deserialize identity card correctly', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'D23145890',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.identityCard,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.identityCard,
        );

        final queryParams = params.toQueryParams();
        final reconstructed = NfcReadingRouteParams.fromQueryParams(queryParams);

        expect(reconstructed.documentType, equals(DocumentType.identityCard));
        expect(reconstructed.scannedMRZ.documentNumber, equals('D23145890'));
        expect(reconstructed.scannedMRZ.countryCode, equals('UTO'));
        expect(reconstructed.scannedMRZ.documentType, equals(DocumentType.identityCard));

        final idCardMRZ = reconstructed.scannedMRZ as ScannedPassportMRZ;
        expect(idCardMRZ.dateOfBirth, equals(testDateOfBirth));
        expect(idCardMRZ.dateOfExpiry, equals(testDateOfExpiry));
      });

      test('should use "identity_card" string for identity card type', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'D23145890',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.identityCard,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.identityCard,
        );

        final queryParams = params.toQueryParams();
        expect(queryParams['document_type'], equals('identity_card'));
      });

      test('should preserve identity card type through serialization', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'D23145890',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.identityCard,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.identityCard,
        );

        final queryParams = params.toQueryParams();

        // Verify the query params have the right type
        expect(queryParams['document_type'], equals('identity_card'));

        // Reconstruct and verify type is preserved
        final reconstructed = NfcReadingRouteParams.fromQueryParams(queryParams);
        expect(reconstructed.documentType, equals(DocumentType.identityCard));
        expect(reconstructed.scannedMRZ.documentType, equals(DocumentType.identityCard));
      });
    });

    group('toQueryParams and fromQueryParams - Driving Licence', () {
      test('should serialize and deserialize driving licence correctly', () {
        final scannedMRZ = ScannedDriverLicenseMRZ(
          documentNumber: '123456789',
          countryCode: 'NLD',
          version: '1',
          randomData: 'RANDOM123',
          configuration: 'CONFIG',
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.drivingLicence,
        );

        final queryParams = params.toQueryParams();
        final reconstructed = NfcReadingRouteParams.fromQueryParams(queryParams);

        expect(reconstructed.documentType, equals(DocumentType.drivingLicence));
        expect(reconstructed.scannedMRZ.documentNumber, equals('123456789'));
        expect(reconstructed.scannedMRZ.countryCode, equals('NLD'));
        expect(reconstructed.scannedMRZ.documentType, equals(DocumentType.drivingLicence));

        final licenseMRZ = reconstructed.scannedMRZ as ScannedDriverLicenseMRZ;
        expect(licenseMRZ.version, equals('1'));
        expect(licenseMRZ.randomData, equals('RANDOM123'));
        expect(licenseMRZ.configuration, equals('CONFIG'));
      });

      test('should use "drivers_license" string for driving licence type', () {
        final scannedMRZ = ScannedDriverLicenseMRZ(
          documentNumber: '123456789',
          countryCode: 'NLD',
          version: '1',
          randomData: 'RANDOM123',
          configuration: 'CONFIG',
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.drivingLicence,
        );

        final queryParams = params.toQueryParams();
        expect(queryParams['document_type'], equals('drivers_license'));
      });
    });

    group('fromQueryParams error handling', () {
      test('should throw exception for unknown document type', () {
        final queryParams = {
          'document_type': 'unknown_type',
          'doc_number': 'TEST123',
          'country_code': 'XXX',
          'date_of_birth': testDateOfBirth.toIso8601String(),
          'date_of_expiry': testDateOfExpiry.toIso8601String(),
        };

        expect(
          () => NfcReadingRouteParams.fromQueryParams(queryParams),
          throwsException,
        );
      });
    });

    group('query params structure', () {
      test('should include correct fields for passport/identity card', () {
        final scannedMRZ = ScannedPassportMRZ(
          documentNumber: 'L898902C3',
          countryCode: 'UTO',
          dateOfBirth: testDateOfBirth,
          dateOfExpiry: testDateOfExpiry,
          documentType: DocumentType.passport,
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.passport,
        );

        final queryParams = params.toQueryParams();

        expect(queryParams.keys, contains('doc_number'));
        expect(queryParams.keys, contains('country_code'));
        expect(queryParams.keys, contains('document_type'));
        expect(queryParams.keys, contains('date_of_birth'));
        expect(queryParams.keys, contains('date_of_expiry'));
      });

      test('should include correct fields for driving licence', () {
        final scannedMRZ = ScannedDriverLicenseMRZ(
          documentNumber: '123456789',
          countryCode: 'NLD',
          version: '1',
          randomData: 'RANDOM123',
          configuration: 'CONFIG',
        );

        final params = NfcReadingRouteParams(
          scannedMRZ: scannedMRZ,
          documentType: DocumentType.drivingLicence,
        );

        final queryParams = params.toQueryParams();

        expect(queryParams.keys, contains('doc_number'));
        expect(queryParams.keys, contains('country_code'));
        expect(queryParams.keys, contains('document_type'));
        expect(queryParams.keys, contains('version'));
        expect(queryParams.keys, contains('random_data'));
        expect(queryParams.keys, contains('configuration'));
      });
    });
  });
}
