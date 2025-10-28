enum DocumentType { passport, driverLicense }

String documentTypeToString(DocumentType t) {
  return switch (t) {
    DocumentType.passport => 'passport',
    DocumentType.driverLicense => 'drivers_license',
  };
}

DocumentType stringToDocumentType(String t) {
  return switch (t) {
    'passport' => DocumentType.passport,
    'drivers_license' => DocumentType.driverLicense,
    _ => throw Exception('Unexpected/unsupported DocumentType: $t'),
  };
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    return switch (this) {
      DocumentType.passport => 'Passport',
      DocumentType.driverLicense => 'Driver\'s license',
    };
  }
}
