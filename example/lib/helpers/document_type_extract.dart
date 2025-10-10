import 'mrz_scanner.dart';

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.driverLicense:
        return 'Driver\'s Licence';
    }
  }

  String get displayNameLowerCase {
    return displayName.toLowerCase();
  }
}