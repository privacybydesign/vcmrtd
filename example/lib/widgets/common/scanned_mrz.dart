import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';

sealed class ScannedMRZ {
  final String documentNumber;
  final String countryCode;
  final DocumentType documentType;

  ScannedMRZ({
    required this.documentNumber,
    required this.countryCode,
    required this.documentType,
  });
}

// =====================
// PASSPORT / ID CARD SHAPE
// (mrz_parser v3 returns PassportMrzResult for both passport and ID card parsers)
// =====================
class ScannedPassportMRZ extends ScannedMRZ {
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;

  ScannedPassportMRZ({
    required super.documentNumber,
    required super.countryCode,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    super.documentType = DocumentType.passport,
  });

  factory ScannedPassportMRZ.fromMRZResult(
      PassportMrzResult mrz, {
        DocumentType documentType = DocumentType.passport,
      }) {
    return ScannedPassportMRZ(
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      dateOfBirth: mrz.birthDate,
      dateOfExpiry: mrz.expiryDate,
      documentType: documentType,
    );
  }

  factory ScannedPassportMRZ.fromManualEntry({
    required String documentNumber,
    required DateTime dateOfBirth,
    required DateTime dateOfExpiry,
    String countryCode = '', // TODO: Get country code from manual entry screen as well
    DocumentType documentType = DocumentType.passport,
  }) {
    return ScannedPassportMRZ(
      documentNumber: documentNumber,
      countryCode: countryCode,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
      documentType: documentType,
    );
  }
}

// =====================
// ID CARD (TD1)
// =====================
class ScannedIdCardMRZ extends ScannedMRZ {
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;

  ScannedIdCardMRZ({
    required super.documentNumber,
    required super.countryCode,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    super.documentType = DocumentType.identityCard,
  });

  factory ScannedIdCardMRZ.fromMRZResult(
      PassportMrzResult mrz, {
        DocumentType documentType = DocumentType.identityCard,
      }) {
    return ScannedIdCardMRZ(
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      dateOfBirth: mrz.birthDate,
      dateOfExpiry: mrz.expiryDate,
      documentType: documentType,
    );
  }

  factory ScannedIdCardMRZ.fromManualEntry({
    required String documentNumber,
    required DateTime dateOfBirth,
    required DateTime dateOfExpiry,
    String countryCode = '', // TODO: Get country code from manual entry screen as well
    DocumentType documentType = DocumentType.identityCard,
  }) {
    return ScannedIdCardMRZ(
      documentNumber: documentNumber,
      countryCode: countryCode,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
      documentType: documentType,
    );
  }
}

// =====================
// DRIVING LICENCE
// =====================
class ScannedDriverLicenseMRZ extends ScannedMRZ {
  final String version;
  final String randomData;
  final String configuration;

  ScannedDriverLicenseMRZ({
    required super.documentNumber,
    required super.countryCode,
    required this.version,
    required this.randomData,
    required this.configuration,
    super.documentType = DocumentType.drivingLicence,
  });

  factory ScannedDriverLicenseMRZ.fromMRZResult(
      DrivingLicenceMrzResult mrz, {
        DocumentType documentType = DocumentType.drivingLicence,
      }) {
    return ScannedDriverLicenseMRZ(
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      version: mrz.version,
      randomData: mrz.randomData,
      configuration: mrz.configuration,
      documentType: documentType,
    );
  }

  factory ScannedDriverLicenseMRZ.fromManualEntry({
    required String mrzString,
    DocumentType documentType = DocumentType.drivingLicence,
  }) {
    final parsed = DrivingLicenceMrzParser().parse([mrzString]);
    return ScannedDriverLicenseMRZ.fromMRZResult(parsed, documentType: documentType);
  }
}
