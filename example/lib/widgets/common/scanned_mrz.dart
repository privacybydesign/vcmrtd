import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';

sealed class ScannedMRZ {
  final String documentNumber;
  final String countryCode;
  final DocumentType documentType;

  ScannedMRZ({required this.documentNumber, required this.countryCode, required this.documentType});
}

class ScannedPassportMRZ extends ScannedMRZ {
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;

  ScannedPassportMRZ({
    required super.documentNumber,
    required super.countryCode,
    required this.dateOfBirth,
    required this.dateOfExpiry,
  }) : super(documentType: DocumentType.passport);

  factory ScannedPassportMRZ.fromMRZResult(MRZResult mrz) {
    return ScannedPassportMRZ(
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      dateOfBirth: mrz.birthDate,
      dateOfExpiry: mrz.expiryDate,
    );
  }
}

class ScannedDriverLicenseMRZ extends ScannedMRZ {
  ScannedDriverLicenseMRZ({required super.documentNumber, required super.countryCode})
    : super(documentType: DocumentType.driverLicense);

  factory ScannedDriverLicenseMRZ.fromMRZResult(MRZResult mrz) {
    return ScannedDriverLicenseMRZ(documentNumber: mrz.documentNumber, countryCode: mrz.countryCode);
  }
}
