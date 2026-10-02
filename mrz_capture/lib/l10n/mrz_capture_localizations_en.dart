// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mrz_capture_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MrzCaptureLocalizationsEn extends MrzCaptureLocalizations {
  MrzCaptureLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get mrzContinueToNfc => 'Continue to NFC Reading';

  @override
  String mrzEnterDetailsLabel(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'document',
    });
    return 'Enter $_temp0 details';
  }

  @override
  String get mrzWhereToFind => 'Where to find this information:';

  @override
  String get mrzHelpPassport =>
      '• Passport Number: Usually at the top right of the photo page\n• Date of Birth: Listed as \"Date of birth\" or \"DOB\"\n• Expiry Date: Listed as \"Date of expiry\" or \"Valid until\"';

  @override
  String get mrzHelpIdentityCard =>
      '• Identity Card Number: On the front of the card\n• Date of Birth: Listed as \"Date of birth\" or \"DOB\"\n• Expiry Date: Listed as \"Date of expiry\" or \"Valid until\"';

  @override
  String get mrzHelpDrivingLicence =>
      '• The MRZ is at the bottom of the front side of your driver\'s licence\n• You can also get this by scanning the QR Code on the back of your driver\'s licence\n• It\'s a single line of exactly 30 characters\n• Starts with \"D1\", \"D2\", or \"DL\"';

  @override
  String mrzDocNumberTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport Number',
      'identityCard': 'Identity Card Number',
      'drivingLicence': 'Driving Licence Number',
      'other': 'Document Number',
    });
    return '$_temp0';
  }

  @override
  String mrzDocNumberHint(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Enter your $_temp0 number';
  }

  @override
  String get mrzDocNumberExample => 'e.g., AB1234567';

  @override
  String mrzDocNumberRequired(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'Document',
    });
    return '$_temp0 number is required';
  }

  @override
  String mrzDocNumberTooShort(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'Document',
    });
    return '$_temp0 number must be at least 6 characters';
  }

  @override
  String get mrzDobTitle => 'Date of Birth';

  @override
  String get mrzDobHint => 'Select your date of birth';

  @override
  String get mrzTapToSelectDate => 'Tap to select date';

  @override
  String get mrzDobRequired => 'Date of birth is required';

  @override
  String get mrzDobInFuture => 'Date of birth cannot be in the future';

  @override
  String get mrzExpiryTitle => 'Expiry Date';

  @override
  String mrzExpiryHint(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Select $_temp0 expiry date';
  }

  @override
  String get mrzExpiryRequired => 'Expiry date is required';

  @override
  String mrzDocumentExpired(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'Document',
    });
    return '$_temp0 has expired';
  }

  @override
  String get mrzExpiryBeforeDob => 'Expiry date cannot be before date of birth';

  @override
  String get mrzStringTitle => 'MRZ String';

  @override
  String get mrzStringHint => 'Enter the MRZ line from your driver\'s licence';

  @override
  String get mrzStringRequired => 'MRZ string is required';

  @override
  String get mrzStringLength => 'MRZ must be exactly 30 characters';

  @override
  String get mrzStringPrefix => 'MRZ must start with D1, D2, or DL';

  @override
  String get mrzCharacterCount => 'Character count:';

  @override
  String mrzParseFailed(String error) {
    return 'Failed to parse MRZ: $error';
  }

  @override
  String mrzHeaderTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'Document',
    });
    return 'Enter Your $_temp0 Information';
  }

  @override
  String get mrzHeaderTitleMrz => 'Enter MRZ String';

  @override
  String mrzHeaderSubtitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Please enter the information exactly as it appears on your $_temp0';
  }

  @override
  String get mrzHeaderSubtitleMrz => 'Type the Machine Readable Zone text exactly as it appears';
}
