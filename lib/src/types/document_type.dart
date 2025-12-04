enum DocumentType { passport, drivingLicence, idCard }

String documentTypeToString(DocumentType t) {
  return switch (t) {
    DocumentType.passport => 'passport',
    DocumentType.drivingLicence => 'drivers_license',
    DocumentType.idCard => 'id_card',
  };
}

DocumentType stringToDocumentType(String t) {
  return switch (t) {
    'passport' => DocumentType.passport,
    'drivers_license' => DocumentType.drivingLicence,
    'id_card' => DocumentType.idCard,
    _ => throw Exception('Unexpected/unsupported DocumentType: $t'),
  };
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    return switch (this) {
      DocumentType.idCard => 'Identity Card',
      DocumentType.passport => 'Passport',
      DocumentType.drivingLicence => 'Driving Licence',
    };
  }
}
