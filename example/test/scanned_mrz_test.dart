import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';

void main() {
  group('ScannedPassportMRZ', () {
    final testDate1 = DateTime(1990, 6, 8);
    final testDate2 = DateTime(2025, 12, 31);

    group('constructor', () {
      test('should default to passport document type', () {
        final mrz = ScannedPassportMRZ(
          documentNumber: 'L898902C3',
          countryCode: 'UTO',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
        );

        expect(mrz.documentType, equals(DocumentType.passport));
      });

      test('should accept identity card document type', () {
        final mrz = ScannedPassportMRZ(
          documentNumber: 'D23145890',
          countryCode: 'UTO',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          documentType: DocumentType.identityCard,
        );

        expect(mrz.documentType, equals(DocumentType.identityCard));
      });

      test('should store all fields correctly', () {
        final mrz = ScannedPassportMRZ(
          documentNumber: 'L898902C3',
          countryCode: 'UTO',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          documentType: DocumentType.passport,
        );

        expect(mrz.documentNumber, equals('L898902C3'));
        expect(mrz.countryCode, equals('UTO'));
        expect(mrz.dateOfBirth, equals(testDate1));
        expect(mrz.dateOfExpiry, equals(testDate2));
      });
    });

    group('fromManualEntry', () {
      test('should default to passport document type', () {
        final scanned = ScannedPassportMRZ.fromManualEntry(
          documentNumber: 'L898902C3',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
        );

        expect(scanned.documentType, equals(DocumentType.passport));
        expect(scanned.documentNumber, equals('L898902C3'));
        expect(scanned.countryCode, equals(''));
        expect(scanned.dateOfBirth, equals(testDate1));
        expect(scanned.dateOfExpiry, equals(testDate2));
      });

      test('should accept identity card document type parameter', () {
        final scanned = ScannedPassportMRZ.fromManualEntry(
          documentNumber: 'D23145890',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          documentType: DocumentType.identityCard,
        );

        expect(scanned.documentType, equals(DocumentType.identityCard));
        expect(scanned.documentNumber, equals('D23145890'));
      });

      test('should accept country code', () {
        final scanned = ScannedPassportMRZ.fromManualEntry(
          documentNumber: 'L898902C3',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          countryCode: 'NLD',
        );

        expect(scanned.countryCode, equals('NLD'));
      });

      test('should preserve passport type when specified', () {
        final scanned = ScannedPassportMRZ.fromManualEntry(
          documentNumber: 'L898902C3',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          documentType: DocumentType.passport,
        );

        expect(scanned.documentType, equals(DocumentType.passport));
      });

      test('should preserve identity card type when specified', () {
        final scanned = ScannedPassportMRZ.fromManualEntry(
          documentNumber: 'D23145890',
          dateOfBirth: testDate1,
          dateOfExpiry: testDate2,
          documentType: DocumentType.identityCard,
        );

        expect(scanned.documentType, equals(DocumentType.identityCard));
      });
    });
  });

  group('ScannedIdCardMRZ', () {
    final testDate1 = DateTime(1990, 6, 8);
    final testDate2 = DateTime(2025, 12, 31);

    test('constructor defaults to identity card document type', () {
      final mrz = ScannedIdCardMRZ(
        documentNumber: 'D23145890',
        countryCode: 'UTO',
        dateOfBirth: testDate1,
        dateOfExpiry: testDate2,
      );

      expect(mrz.documentType, equals(DocumentType.identityCard));
      expect(mrz.documentNumber, equals('D23145890'));
      expect(mrz.countryCode, equals('UTO'));
      expect(mrz.dateOfBirth, equals(testDate1));
      expect(mrz.dateOfExpiry, equals(testDate2));
    });

    test('fromManualEntry preserves supplied fields and type', () {
      final mrz = ScannedIdCardMRZ.fromManualEntry(
        documentNumber: 'I12345678',
        dateOfBirth: testDate1,
        dateOfExpiry: testDate2,
        countryCode: 'NLD',
        documentType: DocumentType.identityCard,
      );

      expect(mrz.documentType, equals(DocumentType.identityCard));
      expect(mrz.documentNumber, equals('I12345678'));
      expect(mrz.countryCode, equals('NLD'));
      expect(mrz.dateOfBirth, equals(testDate1));
      expect(mrz.dateOfExpiry, equals(testDate2));
    });
  });

  group('ScannedDriverLicenseMRZ', () {
    group('constructor', () {
      test('should create with driving licence document type', () {
        final mrz = ScannedDriverLicenseMRZ(
          documentNumber: '123456789',
          countryCode: 'NLD',
          version: '1',
          randomData: 'RANDOM123',
          configuration: 'CONFIG',
        );

        expect(mrz.documentType, equals(DocumentType.drivingLicence));
        expect(mrz.documentNumber, equals('123456789'));
        expect(mrz.countryCode, equals('NLD'));
        expect(mrz.version, equals('1'));
        expect(mrz.randomData, equals('RANDOM123'));
        expect(mrz.configuration, equals('CONFIG'));
      });
    });

    group('fromManualEntry', () {
      test('parses a valid single-line driving licence MRZ', () {
        final mrz = ScannedDriverLicenseMRZ.fromManualEntry(mrzString: 'D1NLD11234567890ABCDEFGHIJKLM5');

        expect(mrz.documentType, equals(DocumentType.drivingLicence));
        expect(mrz.documentNumber, equals('1234567890'));
        expect(mrz.countryCode, equals('NLD'));
        expect(mrz.version, equals('1'));
        expect(mrz.randomData, equals('ABCDEFGHIJKLM'));
        expect(mrz.configuration, equals('1'));
      });

      test('throws when manual driving licence MRZ cannot be parsed', () {
        expect(
          () => ScannedDriverLicenseMRZ.fromManualEntry(mrzString: 'not-a-driving-licence-mrz'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
