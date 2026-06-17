enum DocumentType { passport, drivingLicence, identityCard }

String documentTypeToString(DocumentType t) {
  return switch (t) {
    DocumentType.passport => 'passport',
    DocumentType.drivingLicence => 'drivers_license',
    DocumentType.identityCard => 'id_card',
  };
}

DocumentType stringToDocumentType(String t) {
  return switch (t) {
    'passport' => DocumentType.passport,
    'drivers_license' => DocumentType.drivingLicence,
    'id_card' => DocumentType.identityCard,
    _ => throw Exception('Unexpected/unsupported DocumentType: $t'),
  };
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    return switch (this) {
      DocumentType.identityCard => 'Identity Card',
      DocumentType.passport => 'Passport',
      DocumentType.drivingLicence => 'Driving Licence',
    };
  }
}
