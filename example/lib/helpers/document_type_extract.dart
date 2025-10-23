import 'package:vcmrtd/vcmrtd.dart';

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    return switch (this) {
      DocumentType.passport => 'Passport',
      DocumentType.driverLicence => 'Driver\'s licence',
    };
  }
}
