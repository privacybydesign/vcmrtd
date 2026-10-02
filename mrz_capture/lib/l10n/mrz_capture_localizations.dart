import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mrz_capture_localizations_en.dart';
import 'mrz_capture_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MrzCaptureLocalizations
/// returned by `MrzCaptureLocalizations.of(context)`.
///
/// Applications need to include `MrzCaptureLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/mrz_capture_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MrzCaptureLocalizations.localizationsDelegates,
///   supportedLocales: MrzCaptureLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MrzCaptureLocalizations.supportedLocales
/// property.
abstract class MrzCaptureLocalizations {
  MrzCaptureLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MrzCaptureLocalizations? of(BuildContext context) {
    return Localizations.of<MrzCaptureLocalizations>(context, MrzCaptureLocalizations);
  }

  static const LocalizationsDelegate<MrzCaptureLocalizations> delegate = _MrzCaptureLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('nl')];

  /// No description provided for @mrzContinueToNfc.
  ///
  /// In en, this message translates to:
  /// **'Continue to NFC Reading'**
  String get mrzContinueToNfc;

  /// No description provided for @mrzEnterDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter {docType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{document}} details'**
  String mrzEnterDetailsLabel(String docType);

  /// No description provided for @mrzWhereToFind.
  ///
  /// In en, this message translates to:
  /// **'Where to find this information:'**
  String get mrzWhereToFind;

  /// No description provided for @mrzHelpPassport.
  ///
  /// In en, this message translates to:
  /// **'• Passport Number: Usually at the top right of the photo page\n• Date of Birth: Listed as \"Date of birth\" or \"DOB\"\n• Expiry Date: Listed as \"Date of expiry\" or \"Valid until\"'**
  String get mrzHelpPassport;

  /// No description provided for @mrzHelpIdentityCard.
  ///
  /// In en, this message translates to:
  /// **'• Identity Card Number: On the front of the card\n• Date of Birth: Listed as \"Date of birth\" or \"DOB\"\n• Expiry Date: Listed as \"Date of expiry\" or \"Valid until\"'**
  String get mrzHelpIdentityCard;

  /// No description provided for @mrzHelpDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'• The MRZ is at the bottom of the front side of your driver\'s licence\n• You can also get this by scanning the QR Code on the back of your driver\'s licence\n• It\'s a single line of exactly 30 characters\n• Starts with \"D1\", \"D2\", or \"DL\"'**
  String get mrzHelpDrivingLicence;

  /// No description provided for @mrzDocNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Passport Number} identityCard{Identity Card Number} drivingLicence{Driving Licence Number} other{Document Number}}'**
  String mrzDocNumberTitle(String docType);

  /// No description provided for @mrzDocNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your {docType, select, passport{passport} identityCard{identity card} drivingLicence{driving licence} other{document}} number'**
  String mrzDocNumberHint(String docType);

  /// No description provided for @mrzDocNumberExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., AB1234567'**
  String get mrzDocNumberExample;

  /// No description provided for @mrzDocNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{Document}} number is required'**
  String mrzDocNumberRequired(String docType);

  /// No description provided for @mrzDocNumberTooShort.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{Document}} number must be at least 6 characters'**
  String mrzDocNumberTooShort(String docType);

  /// No description provided for @mrzDobTitle.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get mrzDobTitle;

  /// No description provided for @mrzDobHint.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get mrzDobHint;

  /// No description provided for @mrzTapToSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Tap to select date'**
  String get mrzTapToSelectDate;

  /// No description provided for @mrzDobRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get mrzDobRequired;

  /// No description provided for @mrzDobInFuture.
  ///
  /// In en, this message translates to:
  /// **'Date of birth cannot be in the future'**
  String get mrzDobInFuture;

  /// No description provided for @mrzExpiryTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get mrzExpiryTitle;

  /// No description provided for @mrzExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'Select {docType, select, passport{passport} identityCard{identity card} drivingLicence{driving licence} other{document}} expiry date'**
  String mrzExpiryHint(String docType);

  /// No description provided for @mrzExpiryRequired.
  ///
  /// In en, this message translates to:
  /// **'Expiry date is required'**
  String get mrzExpiryRequired;

  /// No description provided for @mrzDocumentExpired.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{Document}} has expired'**
  String mrzDocumentExpired(String docType);

  /// No description provided for @mrzExpiryBeforeDob.
  ///
  /// In en, this message translates to:
  /// **'Expiry date cannot be before date of birth'**
  String get mrzExpiryBeforeDob;

  /// No description provided for @mrzStringTitle.
  ///
  /// In en, this message translates to:
  /// **'MRZ String'**
  String get mrzStringTitle;

  /// No description provided for @mrzStringHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the MRZ line from your driver\'s licence'**
  String get mrzStringHint;

  /// No description provided for @mrzStringRequired.
  ///
  /// In en, this message translates to:
  /// **'MRZ string is required'**
  String get mrzStringRequired;

  /// No description provided for @mrzStringLength.
  ///
  /// In en, this message translates to:
  /// **'MRZ must be exactly 30 characters'**
  String get mrzStringLength;

  /// No description provided for @mrzStringPrefix.
  ///
  /// In en, this message translates to:
  /// **'MRZ must start with D1, D2, or DL'**
  String get mrzStringPrefix;

  /// No description provided for @mrzCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'Character count:'**
  String get mrzCharacterCount;

  /// No description provided for @mrzParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse MRZ: {error}'**
  String mrzParseFailed(String error);

  /// No description provided for @mrzHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Your {docType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{Document}} Information'**
  String mrzHeaderTitle(String docType);

  /// No description provided for @mrzHeaderTitleMrz.
  ///
  /// In en, this message translates to:
  /// **'Enter MRZ String'**
  String get mrzHeaderTitleMrz;

  /// No description provided for @mrzHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter the information exactly as it appears on your {docType, select, passport{passport} identityCard{identity card} drivingLicence{driving licence} other{document}}'**
  String mrzHeaderSubtitle(String docType);

  /// No description provided for @mrzHeaderSubtitleMrz.
  ///
  /// In en, this message translates to:
  /// **'Type the Machine Readable Zone text exactly as it appears'**
  String get mrzHeaderSubtitleMrz;
}

class _MrzCaptureLocalizationsDelegate extends LocalizationsDelegate<MrzCaptureLocalizations> {
  const _MrzCaptureLocalizationsDelegate();

  @override
  Future<MrzCaptureLocalizations> load(Locale locale) {
    return SynchronousFuture<MrzCaptureLocalizations>(lookupMrzCaptureLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_MrzCaptureLocalizationsDelegate old) => false;
}

MrzCaptureLocalizations lookupMrzCaptureLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return MrzCaptureLocalizationsEn();
    case 'nl':
      return MrzCaptureLocalizationsNl();
  }

  throw FlutterError(
    'MrzCaptureLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
