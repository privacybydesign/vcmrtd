import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// An MRZ that was read, either by the scanner or through manual entry.
///
/// Sealed, so a caller can switch over it exhaustively. There are two shapes,
/// not three: identity cards come back as a [ScannedPassportMRZ] carrying
/// `DocumentType.identityCard`, because `mrz_parser` returns the same result
/// type for the passport and the ID card parser.
sealed class ScannedMRZ {
  final String documentNumber;
  final String countryCode;
  final DocumentType documentType;

  ScannedMRZ({required this.documentNumber, required this.countryCode, required this.documentType});
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

  factory ScannedPassportMRZ.fromMRZResult(PassportMrzResult mrz, {DocumentType documentType = DocumentType.passport}) {
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
    String countryCode = '',
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
