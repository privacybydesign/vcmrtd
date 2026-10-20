enum DocumentType { passport, drivingLicence, identityCard, residencePermit }

String documentTypeToString(DocumentType t) {
  return switch (t) {
    DocumentType.passport => 'passport',
    DocumentType.drivingLicence => 'drivers_license',
    DocumentType.identityCard => 'id_card',
    DocumentType.residencePermit => 'residence_permit',
  };
}

DocumentType stringToDocumentType(String t) {
  return switch (t) {
    'passport' => DocumentType.passport,
    'drivers_license' => DocumentType.drivingLicence,
    'id_card' => DocumentType.identityCard,
    'residence_permit' => DocumentType.residencePermit,
    _ => throw Exception('Unexpected/unsupported DocumentType: $t'),
  };
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    return switch (this) {
      DocumentType.identityCard => 'Identity Card',
      DocumentType.passport => 'Passport',
      DocumentType.drivingLicence => 'Driving Licence',
      DocumentType.residencePermit => 'Residence Permit',
    };
  }
}

// Codes from issued permits. The code alone can't settle it the other way:
// Belgium, Denmark and Poland also put ID on residence permits.
const _residencePermitCodes = {'AD', 'AR', 'CR', 'IB', 'IE', 'IF', 'IK', 'IO', 'IR', 'IT', 'IW', 'IZ', 'RP', 'RT'};

/// Whether a TD1 card is an identity card or a residence permit, as far as
/// its MRZ tells; null when it doesn't. No state issues its own nationals a
/// residence permit.
DocumentType? td1DocumentType({
  required String documentCode,
  required String issuingState,
  required String nationality,
}) {
  if (nationality.isNotEmpty && nationality == issuingState) return DocumentType.identityCard;
  if (_residencePermitCodes.contains(documentCode.replaceAll('<', ''))) return DocumentType.residencePermit;
  return null;
}
