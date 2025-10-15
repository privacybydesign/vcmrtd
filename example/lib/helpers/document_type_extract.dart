import 'mrz_scanner.dart';
import 'package:vcmrtd/vcmrtd.dart';

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.driverLicence:
        return 'Driver\'s Licence';
    }
  }

  String get displayNameLowerCase {
    return displayName.toLowerCase();
  }
}