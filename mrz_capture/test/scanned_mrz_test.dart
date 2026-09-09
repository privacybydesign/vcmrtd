import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:mrz_capture/mrz_capture.dart';

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

    group('fromMRZResult', () {
      test('creates passport MRZ from parser result', () {
        final parsed = PassportMrzParser().parse([
          'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
          'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
        ]);

        final scanned = ScannedPassportMRZ.fromMRZResult(parsed);

        expect(scanned.documentType, DocumentType.passport);
        expect(scanned.documentNumber, 'L898902C3');
        expect(scanned.countryCode, 'UTO');
        expect(scanned.dateOfBirth, DateTime(1974, 8, 12));
        expect(scanned.dateOfExpiry, DateTime(2012, 4, 15));
      });

      test('can create identity-card-shaped result with identityCard document type', () {
        final parsed = IdCardMrzParser().parse([
          'I<UTOD231458907<<<<<<<<<<<<<<<',
          '7408122F1204159UTO<<<<<<<<<<<6',
          'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
        ]);

        final scanned = ScannedPassportMRZ.fromMRZResult(parsed, documentType: DocumentType.identityCard);

        expect(scanned.documentType, DocumentType.identityCard);
        expect(scanned.documentNumber, 'D23145890');
        expect(scanned.countryCode, 'UTO');
      });
    });

    group('equality', () {
      ScannedPassportMRZ build({
        String documentNumber = 'L898902C3',
        String countryCode = 'UTO',
        DateTime? dateOfBirth,
        DateTime? dateOfExpiry,
        DocumentType documentType = DocumentType.passport,
      }) => ScannedPassportMRZ(
        documentNumber: documentNumber,
        countryCode: countryCode,
        dateOfBirth: dateOfBirth ?? testDate1,
        dateOfExpiry: dateOfExpiry ?? testDate2,
        documentType: documentType,
      );

      test('is equal to itself', () {
        final mrz = build();
        expect(mrz, equals(mrz));
      });

      test('is equal to a distinct instance with the same fields, with matching hashCode', () {
        expect(build(), equals(build()));
        expect(build().hashCode, equals(build().hashCode));
      });

      test('is not equal when documentNumber differs', () {
        expect(build(), isNot(equals(build(documentNumber: 'D23145890'))));
      });

      test('is not equal when countryCode differs', () {
        expect(build(), isNot(equals(build(countryCode: 'NLD'))));
      });

      test('is not equal when documentType differs', () {
        expect(build(), isNot(equals(build(documentType: DocumentType.identityCard))));
      });

      test('is not equal when dateOfBirth differs', () {
        expect(build(), isNot(equals(build(dateOfBirth: DateTime(2000, 1, 1)))));
      });

      test('is not equal when dateOfExpiry differs', () {
        expect(build(), isNot(equals(build(dateOfExpiry: DateTime(2030, 1, 1)))));
      });

      test('is not equal to an unrelated object', () {
        expect(build(), isNot(equals('not a ScannedPassportMRZ')));
      });
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

      test('fromMRZResult preserves parsed driving licence fields', () {
        final parsed = DrivingLicenceMrzParser().parse(['D<NLD11234567890ABCDEFGHIJ<<<9']);

        final mrz = ScannedDriverLicenseMRZ.fromMRZResult(parsed);

        expect(mrz.documentType, equals(DocumentType.drivingLicence));
        expect(mrz.documentNumber, equals('1234567890'));
        expect(mrz.countryCode, equals('NLD'));
        expect(mrz.version, equals('1'));
        expect(mrz.randomData, equals('ABCDEFGHIJ'));
        expect(mrz.configuration, equals(''));
      });

      test('throws when manual driving licence MRZ cannot be parsed', () {
        expect(
          () => ScannedDriverLicenseMRZ.fromManualEntry(mrzString: 'not-a-driving-licence-mrz'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('equality', () {
      ScannedDriverLicenseMRZ build({
        String documentNumber = '123456789',
        String countryCode = 'NLD',
        String version = '1',
        String randomData = 'RANDOM123',
        String configuration = 'CONFIG',
        DocumentType documentType = DocumentType.drivingLicence,
      }) => ScannedDriverLicenseMRZ(
        documentNumber: documentNumber,
        countryCode: countryCode,
        version: version,
        randomData: randomData,
        configuration: configuration,
        documentType: documentType,
      );

      test('is equal to itself', () {
        final mrz = build();
        expect(mrz, equals(mrz));
      });

      test('is equal to a distinct instance with the same fields, with matching hashCode', () {
        expect(build(), equals(build()));
        expect(build().hashCode, equals(build().hashCode));
      });

      test('is not equal when documentNumber differs', () {
        expect(build(), isNot(equals(build(documentNumber: '987654321'))));
      });

      test('is not equal when countryCode differs', () {
        expect(build(), isNot(equals(build(countryCode: 'UTO'))));
      });

      test('is not equal when documentType differs', () {
        expect(build(), isNot(equals(build(documentType: DocumentType.passport))));
      });

      test('is not equal when version differs', () {
        expect(build(), isNot(equals(build(version: '2'))));
      });

      test('is not equal when randomData differs', () {
        expect(build(), isNot(equals(build(randomData: 'OTHER'))));
      });

      test('is not equal when configuration differs', () {
        expect(build(), isNot(equals(build(configuration: 'OTHER'))));
      });

      test('is not equal to an unrelated object', () {
        expect(build(), isNot(equals('not a ScannedDriverLicenseMRZ')));
      });
    });
  });
}
