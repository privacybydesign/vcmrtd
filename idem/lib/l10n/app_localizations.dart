import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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

  /// No description provided for @accessHandedOver.
  ///
  /// In en, this message translates to:
  /// **'This verification session has been handed over to another device.'**
  String get accessHandedOver;

  /// No description provided for @accessExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification session has expired. Please start a new verification.'**
  String get accessExpired;

  /// No description provided for @accessCancelled.
  ///
  /// In en, this message translates to:
  /// **'This verification session was cancelled. Please start a new verification.'**
  String get accessCancelled;

  /// No description provided for @accessUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'This device is no longer allowed to continue this verification session.'**
  String get accessUnauthorized;

  /// No description provided for @accessComplete.
  ///
  /// In en, this message translates to:
  /// **'This verification session is already complete.'**
  String get accessComplete;

  /// No description provided for @accessGone.
  ///
  /// In en, this message translates to:
  /// **'This verification session no longer exists. Please start a new verification.'**
  String get accessGone;

  /// No description provided for @accessAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'This verification session is already open on another device. To continue here, scan the handover QR code shown in the browser.'**
  String get accessAlreadyClaimed;

  /// No description provided for @accessHandoverInvalid.
  ///
  /// In en, this message translates to:
  /// **'This handover QR code is not valid. Ask for a new one in the browser.'**
  String get accessHandoverInvalid;

  /// No description provided for @accessHandoverExpired.
  ///
  /// In en, this message translates to:
  /// **'This handover QR code has expired. Ask for a new one in the browser.'**
  String get accessHandoverExpired;

  /// No description provided for @accessHandoverUsed.
  ///
  /// In en, this message translates to:
  /// **'This handover QR code was already used. Ask for a new one in the browser.'**
  String get accessHandoverUsed;

  /// No description provided for @accessClaimTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'This QR code is from an older version of the verification service and can no longer be used. Ask for a new one in the browser.'**
  String get accessClaimTokenRequired;

  /// No description provided for @accessBrowserHandover.
  ///
  /// In en, this message translates to:
  /// **'This QR code moves the browser part of the verification to another browser. Open it with your phone\'s camera instead, or scan the QR code the browser shows for the IDEM app.'**
  String get accessBrowserHandover;

  /// No description provided for @sessionOpenFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not open verification'**
  String get sessionOpenFailedTitle;

  /// No description provided for @sessionCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification complete'**
  String get sessionCompleteTitle;

  /// No description provided for @sessionCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re done. Your verification was sent to {relyingParty}.'**
  String sessionCompleteMessage(String relyingParty);

  /// No description provided for @sessionRestartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification restarted'**
  String get sessionRestartedTitle;

  /// No description provided for @sessionRestartedMessage.
  ///
  /// In en, this message translates to:
  /// **'{relyingParty} reset this verification, so everything you did so far was discarded. Please start again from the beginning.'**
  String sessionRestartedMessage(String relyingParty);

  /// No description provided for @sessionStoppedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification stopped'**
  String get sessionStoppedTitle;

  /// No description provided for @idDocumentPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get idDocumentPassport;

  /// No description provided for @idDocumentIdentityCard.
  ///
  /// In en, this message translates to:
  /// **'Identity card'**
  String get idDocumentIdentityCard;

  /// No description provided for @idDocumentDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get idDocumentDrivingLicence;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @nfcAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'NFC available:'**
  String get nfcAvailableLabel;

  /// No description provided for @docNewScan.
  ///
  /// In en, this message translates to:
  /// **'New scan'**
  String get docNewScan;

  /// No description provided for @docConnectedBanner.
  ///
  /// In en, this message translates to:
  /// **'Connected — will send results to {relyingParty}'**
  String docConnectedBanner(String relyingParty);

  /// No description provided for @docPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get docPassport;

  /// No description provided for @docPassportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a machine readable passport'**
  String get docPassportSubtitle;

  /// No description provided for @docMostCommon.
  ///
  /// In en, this message translates to:
  /// **'Most common'**
  String get docMostCommon;

  /// No description provided for @docIdentityCard.
  ///
  /// In en, this message translates to:
  /// **'Identity Card'**
  String get docIdentityCard;

  /// No description provided for @docIdentityCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a machine readable identity card'**
  String get docIdentityCardSubtitle;

  /// No description provided for @docDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'Driving Licence'**
  String get docDrivingLicence;

  /// No description provided for @docDrivingLicenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a machine readable driving licence. Currently works primarily with Dutch licences.'**
  String get docDrivingLicenceSubtitle;

  /// No description provided for @docScanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get docScanQrTitle;

  /// No description provided for @docScanQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan any QR code with the camera'**
  String get docScanQrSubtitle;

  /// No description provided for @docAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get docAdvancedSettings;

  /// No description provided for @docAdvancedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ocr Engine, Face Verification and more'**
  String get docAdvancedSettingsSubtitle;

  /// No description provided for @docVerifyIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your Identity'**
  String get docVerifyIdentityTitle;

  /// No description provided for @docSelectDocumentTypePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select the type of document you want to use for verification.'**
  String get docSelectDocumentTypePrompt;

  /// No description provided for @docSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get docSettingsTitle;

  /// No description provided for @docBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get docBack;

  /// No description provided for @docActiveAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Active authentication'**
  String get docActiveAuthentication;

  /// No description provided for @docActiveAuthenticationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Perform active authentication when reading the document'**
  String get docActiveAuthenticationSubtitle;

  /// No description provided for @docFaceEngine.
  ///
  /// In en, this message translates to:
  /// **'Face verification engine'**
  String get docFaceEngine;

  /// No description provided for @docFaceEngineOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get docFaceEngineOpenSource;

  /// No description provided for @docLivenessDetection.
  ///
  /// In en, this message translates to:
  /// **'Liveness detection'**
  String get docLivenessDetection;

  /// No description provided for @docLivenessPassive.
  ///
  /// In en, this message translates to:
  /// **'Passive'**
  String get docLivenessPassive;

  /// No description provided for @docLivenessActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get docLivenessActive;

  /// No description provided for @docOcrEngine.
  ///
  /// In en, this message translates to:
  /// **'OCR engine'**
  String get docOcrEngine;

  /// No description provided for @docNfcStepStart.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get docNfcStepStart;

  /// No description provided for @docNfcStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Reading details'**
  String get docNfcStepDetails;

  /// No description provided for @docNfcStepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Getting photo'**
  String get docNfcStepPhoto;

  /// No description provided for @docNfcStepAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done'**
  String get docNfcStepAlmostDone;

  /// No description provided for @docNfcStepStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the chip'**
  String get docNfcStepStartSubtitle;

  /// No description provided for @docNfcStepDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Getting personal data'**
  String get docNfcStepDetailsSubtitle;

  /// No description provided for @docNfcStepPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Getting the document photo'**
  String get docNfcStepPhotoSubtitle;

  /// No description provided for @docNfcStepAlmostDoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verifying document security'**
  String get docNfcStepAlmostDoneSubtitle;

  /// No description provided for @docNfcTipFirst.
  ///
  /// In en, this message translates to:
  /// **'Place your document behind your phone and move it around until it buzzes or beeps.'**
  String get docNfcTipFirst;

  /// No description provided for @docNfcTipHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Keep your phone and the document still - this can take a moment.'**
  String get docNfcTipHoldSteady;

  /// No description provided for @docNfcTipStuck.
  ///
  /// In en, this message translates to:
  /// **'Reading was interrupted. Slowly lift your phone off the document and place it back down until it buzzes or beeps again.'**
  String get docNfcTipStuck;

  /// No description provided for @docReadDocument.
  ///
  /// In en, this message translates to:
  /// **'Read {documentType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{document}}'**
  String docReadDocument(String documentType);

  /// No description provided for @docIosNfcHoldClose.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone close to {documentType, select, passport{passport} identityCard{identity card} drivingLicence{driving license} other{document}}'**
  String docIosNfcHoldClose(String documentType);

  /// No description provided for @docIosNfcCancelled.
  ///
  /// In en, this message translates to:
  /// **'Session cancelled by user'**
  String get docIosNfcCancelled;

  /// No description provided for @docIosNfcCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling...'**
  String get docIosNfcCancelling;

  /// No description provided for @docIosNfcFailed.
  ///
  /// In en, this message translates to:
  /// **'Tag lost, try again.'**
  String get docIosNfcFailed;

  /// No description provided for @docIosNfcConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get docIosNfcConnecting;

  /// No description provided for @docIosNfcReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading {file}'**
  String docIosNfcReadingFile(String file);

  /// No description provided for @docIosNfcAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating'**
  String get docIosNfcAuthenticating;

  /// No description provided for @docIosNfcReadingData.
  ///
  /// In en, this message translates to:
  /// **'Reading {documentType, select, passport{passport} identityCard{identity card} drivingLicence{driving license} other{document}} data'**
  String docIosNfcReadingData(String documentType);

  /// No description provided for @docIosNfcSecurityCheck.
  ///
  /// In en, this message translates to:
  /// **'Performing security verification...'**
  String get docIosNfcSecurityCheck;

  /// No description provided for @docIosNfcSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get docIosNfcSuccess;

  /// No description provided for @docIosNfcReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Slowly lift your phone and place it back down.'**
  String get docIosNfcReconnecting;

  /// No description provided for @docNfcGuidanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Read the chip'**
  String get docNfcGuidanceTitle;

  /// No description provided for @docNfcGuidancePlacePhone.
  ///
  /// In en, this message translates to:
  /// **'Place your phone on the {documentType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{document}}'**
  String docNfcGuidancePlacePhone(String documentType);

  /// No description provided for @docNfcGuidanceTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips for better results:'**
  String get docNfcGuidanceTipsTitle;

  /// No description provided for @docNfcGuidanceTips.
  ///
  /// In en, this message translates to:
  /// **'• Place the {documentType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{document}} behind your phone like in the example\n• Remove phone case if reading fails\n• The process may take 10–30 seconds'**
  String docNfcGuidanceTips(String documentType);

  /// No description provided for @docScanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan {documentType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{document}}'**
  String docScanDocument(String documentType);

  /// No description provided for @docNfcNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'NFC is not available'**
  String get docNfcNotAvailable;

  /// No description provided for @docHavingTrouble.
  ///
  /// In en, this message translates to:
  /// **'Having trouble?'**
  String get docHavingTrouble;

  /// No description provided for @docPersonalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get docPersonalInformation;

  /// No description provided for @docSurname.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get docSurname;

  /// No description provided for @docOtherNames.
  ///
  /// In en, this message translates to:
  /// **'Other Names'**
  String get docOtherNames;

  /// No description provided for @docDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get docDateOfBirth;

  /// No description provided for @docPlaceOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Place of Birth'**
  String get docPlaceOfBirth;

  /// No description provided for @docDocumentInformation.
  ///
  /// In en, this message translates to:
  /// **'Document Information'**
  String get docDocumentInformation;

  /// No description provided for @docDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document Number'**
  String get docDocumentNumber;

  /// No description provided for @docIssuingMemberState.
  ///
  /// In en, this message translates to:
  /// **'Issuing Member State'**
  String get docIssuingMemberState;

  /// No description provided for @docIssuingAuthority.
  ///
  /// In en, this message translates to:
  /// **'Issuing Authority'**
  String get docIssuingAuthority;

  /// No description provided for @docDateOfIssue.
  ///
  /// In en, this message translates to:
  /// **'Date of Issue'**
  String get docDateOfIssue;

  /// No description provided for @docDateOfExpiry.
  ///
  /// In en, this message translates to:
  /// **'Date of Expiry'**
  String get docDateOfExpiry;

  /// No description provided for @docDrivingLicenceDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Driving Licence Data'**
  String get docDrivingLicenceDataTitle;

  /// No description provided for @docUnableToLoadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Unable to load photo'**
  String get docUnableToLoadPhoto;

  /// No description provided for @docCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get docCategories;

  /// No description provided for @docCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get docCategory;

  /// No description provided for @docCategoryDateOfIssue.
  ///
  /// In en, this message translates to:
  /// **'Date of issue'**
  String get docCategoryDateOfIssue;

  /// No description provided for @docCategoryDateOfExpiry.
  ///
  /// In en, this message translates to:
  /// **'Date of expiry'**
  String get docCategoryDateOfExpiry;

  /// No description provided for @docNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get docNotAvailable;

  /// No description provided for @docWalletEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is empty'**
  String get docWalletEmpty;

  /// No description provided for @docWalletEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a document and tap \"{addToWallet}\" to see it here.'**
  String docWalletEmptyHint(String addToWallet);

  /// No description provided for @docWalletDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get docWalletDocumentNumber;

  /// No description provided for @docWalletAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get docWalletAdded;

  /// No description provided for @docRemoveFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Remove from wallet'**
  String get docRemoveFromWallet;

  /// No description provided for @docFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get docFullName;

  /// No description provided for @docNationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get docNationality;

  /// No description provided for @docDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get docDocument;

  /// No description provided for @docGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get docGender;

  /// No description provided for @docExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get docExpiryDate;

  /// No description provided for @docCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get docCountry;

  /// No description provided for @docVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get docVersion;

  /// No description provided for @docOptionalData.
  ///
  /// In en, this message translates to:
  /// **'Optional Data'**
  String get docOptionalData;

  /// No description provided for @docNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No Photo'**
  String get docNoPhoto;

  /// No description provided for @docAvailableDataGroups.
  ///
  /// In en, this message translates to:
  /// **'Available Data Groups'**
  String get docAvailableDataGroups;

  /// No description provided for @docDataGroupsRead.
  ///
  /// In en, this message translates to:
  /// **'Data Groups Read: {count}/{total}'**
  String docDataGroupsRead(int count, int total);

  /// No description provided for @docActiveAuthenticationAvailable.
  ///
  /// In en, this message translates to:
  /// **'Active Authentication Available'**
  String get docActiveAuthenticationAvailable;

  /// No description provided for @docWebAuthSession.
  ///
  /// In en, this message translates to:
  /// **'Web Authentication Session'**
  String get docWebAuthSession;

  /// No description provided for @docWebAuthSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session IID: {sessionId}'**
  String docWebAuthSessionId(String sessionId);

  /// No description provided for @docDocumentDataTitle.
  ///
  /// In en, this message translates to:
  /// **'{documentType, select, passport{Passport} identityCard{Identity Card} drivingLicence{Driving Licence} other{Document}} Data'**
  String docDocumentDataTitle(String documentType);

  /// No description provided for @docCanNumber.
  ///
  /// In en, this message translates to:
  /// **'CAN number'**
  String get docCanNumber;

  /// No description provided for @docCanNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter CAN number'**
  String get docCanNumberRequired;

  /// No description provided for @docPassportNumber.
  ///
  /// In en, this message translates to:
  /// **'Passport number'**
  String get docPassportNumber;

  /// No description provided for @docPassportNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter passport number'**
  String get docPassportNumberRequired;

  /// No description provided for @docDateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select Date of Birth'**
  String get docDateOfBirthRequired;

  /// No description provided for @docDateOfExpiryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select Date of Expiry'**
  String get docDateOfExpiryRequired;

  /// No description provided for @docDbaWithPace.
  ///
  /// In en, this message translates to:
  /// **'DBA with PACE'**
  String get docDbaWithPace;

  /// No description provided for @docAccessProtocol.
  ///
  /// In en, this message translates to:
  /// **'Access protocol: {protocol}'**
  String docAccessProtocol(String protocol);

  /// No description provided for @docAccessKeyType.
  ///
  /// In en, this message translates to:
  /// **'Access key type: {keyType}'**
  String docAccessKeyType(String keyType);

  /// No description provided for @docCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get docCopy;

  /// No description provided for @docImageNoData.
  ///
  /// In en, this message translates to:
  /// **'No image data available.'**
  String get docImageNoData;

  /// No description provided for @docImageJpegError.
  ///
  /// In en, this message translates to:
  /// **'Error displaying JPEG image.'**
  String get docImageJpegError;

  /// No description provided for @docImageConvertingJpeg2000.
  ///
  /// In en, this message translates to:
  /// **'Converting JPEG2000 image...'**
  String get docImageConvertingJpeg2000;

  /// No description provided for @docImageJpeg2000DisplayError.
  ///
  /// In en, this message translates to:
  /// **'Error displaying converted JPEG2000 image.'**
  String get docImageJpeg2000DisplayError;

  /// No description provided for @docImageJpeg2000ConvertFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to convert JPEG2000 image.'**
  String get docImageJpeg2000ConvertFailed;

  /// No description provided for @docImageUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'Unknown or unsupported image type.'**
  String get docImageUnsupportedType;

  /// No description provided for @docIllustrationPassport.
  ///
  /// In en, this message translates to:
  /// **'PASSPORT'**
  String get docIllustrationPassport;

  /// No description provided for @docIllustrationIssuer.
  ///
  /// In en, this message translates to:
  /// **'Kingdom of Example'**
  String get docIllustrationIssuer;

  /// No description provided for @docIllustrationName.
  ///
  /// In en, this message translates to:
  /// **'Name: John Doe'**
  String get docIllustrationName;

  /// No description provided for @docIllustrationNationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality: NL'**
  String get docIllustrationNationality;

  /// No description provided for @docIllustrationDob.
  ///
  /// In en, this message translates to:
  /// **'DOB: 01-01-1990'**
  String get docIllustrationDob;

  /// No description provided for @docIllustrationDrivingLicence.
  ///
  /// In en, this message translates to:
  /// **'DRIVING LICENCE'**
  String get docIllustrationDrivingLicence;

  /// No description provided for @faceActionBlink.
  ///
  /// In en, this message translates to:
  /// **'Blink your eyes'**
  String get faceActionBlink;

  /// No description provided for @faceActionTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn your head left'**
  String get faceActionTurnLeft;

  /// No description provided for @faceActionTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn your head right'**
  String get faceActionTurnRight;

  /// No description provided for @faceActionMouthOpen.
  ///
  /// In en, this message translates to:
  /// **'Open your mouth and hold'**
  String get faceActionMouthOpen;

  /// No description provided for @faceActionSmile.
  ///
  /// In en, this message translates to:
  /// **'Smile and hold'**
  String get faceActionSmile;

  /// No description provided for @faceErrorEngineInit.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize Flutter face engine: {error}'**
  String faceErrorEngineInit(String error);

  /// No description provided for @faceErrorNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera available'**
  String get faceErrorNoCamera;

  /// No description provided for @faceErrorOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera: {error}'**
  String faceErrorOpenCamera(String error);

  /// No description provided for @faceErrorFrameProcessing.
  ///
  /// In en, this message translates to:
  /// **'Frame processing error: {error}'**
  String faceErrorFrameProcessing(String error);

  /// No description provided for @faceErrorMissingNfcImage.
  ///
  /// In en, this message translates to:
  /// **'Missing NFC image'**
  String get faceErrorMissingNfcImage;

  /// No description provided for @faceErrorStartLiveness.
  ///
  /// In en, this message translates to:
  /// **'Could not start liveness: {error}'**
  String faceErrorStartLiveness(String error);

  /// No description provided for @faceErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get faceErrorUnknown;

  /// No description provided for @faceTimeoutTakeYourTime.
  ///
  /// In en, this message translates to:
  /// **'Take your time - {action}'**
  String faceTimeoutTakeYourTime(String action);

  /// No description provided for @faceTimeoutPerformAction.
  ///
  /// In en, this message translates to:
  /// **'perform the action'**
  String get faceTimeoutPerformAction;

  /// No description provided for @faceStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Face Verification'**
  String get faceStepLabel;

  /// No description provided for @faceBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get faceBack;

  /// No description provided for @faceSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up face verification'**
  String get faceSettingUp;

  /// No description provided for @faceTakesAMoment.
  ///
  /// In en, this message translates to:
  /// **'This only takes a moment'**
  String get faceTakesAMoment;

  /// No description provided for @faceLoadingOpeningCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening camera'**
  String get faceLoadingOpeningCamera;

  /// No description provided for @faceLoadingModels.
  ///
  /// In en, this message translates to:
  /// **'Loading face models'**
  String get faceLoadingModels;

  /// No description provided for @faceAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done…'**
  String get faceAlmostDone;

  /// No description provided for @faceHoldStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still'**
  String get faceHoldStill;

  /// No description provided for @faceOpeningCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening camera...'**
  String get faceOpeningCamera;

  /// No description provided for @faceHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get faceHowItWorks;

  /// No description provided for @faceStepCenterFace.
  ///
  /// In en, this message translates to:
  /// **'Center your face inside the oval'**
  String get faceStepCenterFace;

  /// No description provided for @faceStepFollowPrompts.
  ///
  /// In en, this message translates to:
  /// **'Follow the on-screen prompts'**
  String get faceStepFollowPrompts;

  /// No description provided for @faceStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get faceStart;

  /// No description provided for @facePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get facePreparing;

  /// No description provided for @faceTipNoFace.
  ///
  /// In en, this message translates to:
  /// **'Position your face in the oval'**
  String get faceTipNoFace;

  /// No description provided for @faceTipCenterFace.
  ///
  /// In en, this message translates to:
  /// **'Move your face into the oval'**
  String get faceTipCenterFace;

  /// No description provided for @faceTipTooFar.
  ///
  /// In en, this message translates to:
  /// **'Move a bit closer to the camera'**
  String get faceTipTooFar;

  /// No description provided for @faceTipTooClose.
  ///
  /// In en, this message translates to:
  /// **'Move a bit further from the camera'**
  String get faceTipTooClose;

  /// No description provided for @faceTipLookStraight.
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera'**
  String get faceTipLookStraight;

  /// No description provided for @faceTipOpenEyes.
  ///
  /// In en, this message translates to:
  /// **'Keep your eyes open'**
  String get faceTipOpenEyes;

  /// No description provided for @faceTipCloseMouth.
  ///
  /// In en, this message translates to:
  /// **'Close your mouth'**
  String get faceTipCloseMouth;

  /// No description provided for @faceTipRelaxFace.
  ///
  /// In en, this message translates to:
  /// **'Relax your expression'**
  String get faceTipRelaxFace;

  /// No description provided for @faceTipHoldStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still…'**
  String get faceTipHoldStill;

  /// No description provided for @faceTipGetReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready…'**
  String get faceTipGetReady;

  /// No description provided for @faceExtraBadge.
  ///
  /// In en, this message translates to:
  /// **'extra'**
  String get faceExtraBadge;

  /// No description provided for @faceVerifyingIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verifying identity...'**
  String get faceVerifyingIdentity;

  /// No description provided for @faceGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get faceGoBack;

  /// No description provided for @faceTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get faceTryAgain;

  /// No description provided for @faceIdentityVerified.
  ///
  /// In en, this message translates to:
  /// **'Identity Verified'**
  String get faceIdentityVerified;

  /// No description provided for @faceVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get faceVerificationFailed;

  /// No description provided for @faceScoreMatch.
  ///
  /// In en, this message translates to:
  /// **'Match (≥{threshold}%)'**
  String faceScoreMatch(String threshold);

  /// No description provided for @faceScoreAntiSpoof.
  ///
  /// In en, this message translates to:
  /// **'Anti-spoof'**
  String get faceScoreAntiSpoof;

  /// No description provided for @faceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get faceNotAvailable;

  /// No description provided for @faceScoreRppg.
  ///
  /// In en, this message translates to:
  /// **'rPPG ({count} samples)'**
  String faceScoreRppg(int count);

  /// No description provided for @faceBpm.
  ///
  /// In en, this message translates to:
  /// **'{bpm} bpm'**
  String faceBpm(String bpm);

  /// No description provided for @faceScoreLivenessActions.
  ///
  /// In en, this message translates to:
  /// **'Liveness actions'**
  String get faceScoreLivenessActions;

  /// No description provided for @facePassed.
  ///
  /// In en, this message translates to:
  /// **'passed'**
  String get facePassed;

  /// No description provided for @faceFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get faceFailed;

  /// No description provided for @faceScoreIdentityConsistent.
  ///
  /// In en, this message translates to:
  /// **'Identity consistent'**
  String get faceScoreIdentityConsistent;

  /// No description provided for @faceChangedMidSession.
  ///
  /// In en, this message translates to:
  /// **'face changed mid-session'**
  String get faceChangedMidSession;

  /// No description provided for @faceDocumentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Document photo'**
  String get faceDocumentPhoto;

  /// No description provided for @faceLiveCapture.
  ///
  /// In en, this message translates to:
  /// **'Live capture'**
  String get faceLiveCapture;

  /// No description provided for @faceContinuing.
  ///
  /// In en, this message translates to:
  /// **'Continuing…'**
  String get faceContinuing;

  /// No description provided for @facePreparingDocumentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Preparing your document photo…'**
  String get facePreparingDocumentPhoto;

  /// No description provided for @faceIrisReadPortraitError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the reference portrait for the Iris SDK.'**
  String get faceIrisReadPortraitError;

  /// No description provided for @faceOpeningIrisCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening the Iris camera…'**
  String get faceOpeningIrisCamera;

  /// No description provided for @faceIrisUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Iris SDK is not available on this device.'**
  String get faceIrisUnavailable;

  /// No description provided for @faceIrisNoActivity.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera. Please try again.'**
  String get faceIrisNoActivity;

  /// No description provided for @faceIrisAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A verification is already in progress.'**
  String get faceIrisAlreadyRunning;

  /// No description provided for @faceIrisFailedCode.
  ///
  /// In en, this message translates to:
  /// **'Verification failed ({code}).'**
  String faceIrisFailedCode(String code);

  /// No description provided for @faceIrisFailedError.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String faceIrisFailedError(String error);

  /// No description provided for @faceIrisIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify with the Iris SDK'**
  String get faceIrisIntroTitle;

  /// No description provided for @faceIrisIntroBody.
  ///
  /// In en, this message translates to:
  /// **'The Iris SDK opens its own full-screen camera to check that a live person is present, then compares that face against the portrait stored on your document.'**
  String get faceIrisIntroBody;

  /// No description provided for @faceIrisWhatToExpect.
  ///
  /// In en, this message translates to:
  /// **'What to expect'**
  String get faceIrisWhatToExpect;

  /// No description provided for @faceIrisStep1.
  ///
  /// In en, this message translates to:
  /// **'A camera screen from the Iris SDK will open'**
  String get faceIrisStep1;

  /// No description provided for @faceIrisStep2.
  ///
  /// In en, this message translates to:
  /// **'Look directly at the camera and follow any prompts'**
  String get faceIrisStep2;

  /// No description provided for @faceIrisStep3.
  ///
  /// In en, this message translates to:
  /// **'Hold still until it finishes — this only takes a moment'**
  String get faceIrisStep3;

  /// No description provided for @faceStartVerification.
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get faceStartVerification;

  /// No description provided for @faceSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something Went Wrong'**
  String get faceSomethingWentWrong;

  /// No description provided for @faceIrisMatchedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The live face matched the document photo.'**
  String get faceIrisMatchedSubtitle;

  /// No description provided for @faceIrisFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The live face did not match the document photo. Make sure you\'re well lit and looking at the camera, then try again.'**
  String get faceIrisFailedSubtitle;

  /// No description provided for @faceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get faceCancelled;

  /// No description provided for @faceIrisCancelledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You cancelled the verification. Tap below to try again.'**
  String get faceIrisCancelledSubtitle;

  /// No description provided for @faceRegulaIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Check that it\'s really you'**
  String get faceRegulaIntroTitle;

  /// No description provided for @faceRegulaIntroBody.
  ///
  /// In en, this message translates to:
  /// **'A camera screen opens to check that a live person is present. The verification service then compares your face with the photo on your document\'s chip.'**
  String get faceRegulaIntroBody;

  /// No description provided for @faceRegulaStep1.
  ///
  /// In en, this message translates to:
  /// **'A camera screen will open'**
  String get faceRegulaStep1;

  /// No description provided for @faceRegulaStep2.
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera and follow the prompts'**
  String get faceRegulaStep2;

  /// No description provided for @faceRegulaStep3.
  ///
  /// In en, this message translates to:
  /// **'Hold still until it finishes — this only takes a moment'**
  String get faceRegulaStep3;

  /// No description provided for @faceRegulaOpeningCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening the camera…'**
  String get faceRegulaOpeningCamera;

  /// No description provided for @faceRegulaLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Liveness Confirmed'**
  String get faceRegulaLiveTitle;

  /// No description provided for @faceRegulaLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your face is now compared with the photo on your document.'**
  String get faceRegulaLiveSubtitle;

  /// No description provided for @faceRegulaNotLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm that a live person is present. Make sure you\'re well lit and looking at the camera, then try again.'**
  String get faceRegulaNotLiveSubtitle;

  /// No description provided for @faceRegulaCancelledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You cancelled the verification. Tap below to try again.'**
  String get faceRegulaCancelledSubtitle;

  /// No description provided for @faceRegulaMatching.
  ///
  /// In en, this message translates to:
  /// **'Comparing your face with your document photo…'**
  String get faceRegulaMatching;

  /// No description provided for @faceRegulaMatchedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your face matches the photo on your document ({similarity}% similarity).'**
  String faceRegulaMatchedSubtitle(String similarity);

  /// No description provided for @faceRegulaNoMatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your face didn\'t match the photo on your document. Scan your document again to retry.'**
  String get faceRegulaNoMatchSubtitle;

  /// No description provided for @faceRegulaMatchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your face could not be compared with your document photo right now.'**
  String get faceRegulaMatchUnavailable;

  /// No description provided for @faceRegulaScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan document again'**
  String get faceRegulaScanAgain;

  /// No description provided for @faceRegulaFailedError.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String faceRegulaFailedError(String error);

  /// No description provided for @faceSessionUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the verification service. Retrying...'**
  String get faceSessionUnreachable;

  /// No description provided for @faceSessionChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your verification session...'**
  String get faceSessionChecking;

  /// No description provided for @faceStopVerification.
  ///
  /// In en, this message translates to:
  /// **'Stop verification'**
  String get faceStopVerification;

  /// No description provided for @faceSubmitSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {what} to {relyingParty}...'**
  String faceSubmitSending(String what, String relyingParty);

  /// No description provided for @faceSubmitCouldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send'**
  String get faceSubmitCouldNotSend;

  /// No description provided for @faceSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Sending {what} to {relyingParty} failed:\n\n{error}'**
  String faceSubmitFailed(String what, String relyingParty, String error);

  /// No description provided for @faceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get faceCancel;

  /// No description provided for @faceRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get faceRetry;

  /// No description provided for @proofingConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity proofing request'**
  String get proofingConsentTitle;

  /// No description provided for @proofingConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'is requesting to verify your identity from a document. Scanning your document and completing face verification will send the result below back to them.'**
  String get proofingConsentIntro;

  /// No description provided for @proofingConsentRequesting.
  ///
  /// In en, this message translates to:
  /// **'They are requesting:'**
  String get proofingConsentRequesting;

  /// No description provided for @proofingConsentExpired.
  ///
  /// In en, this message translates to:
  /// **'This request has expired.'**
  String get proofingConsentExpired;

  /// No description provided for @proofingConsentExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'This request expires in {duration}.'**
  String proofingConsentExpiresIn(String duration);

  /// No description provided for @proofingDurationLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'less than a minute'**
  String get proofingDurationLessThanMinute;

  /// No description provided for @proofingDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String proofingDurationMinutes(int count);

  /// No description provided for @proofingDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String proofingDurationHours(int count);

  /// No description provided for @proofingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get proofingContinue;

  /// No description provided for @proofingDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get proofingDecline;

  /// No description provided for @proofingAttributeDocumentIdentity.
  ///
  /// In en, this message translates to:
  /// **'Document identity (name, date of birth, document number, expiry)'**
  String get proofingAttributeDocumentIdentity;

  /// No description provided for @proofingAttributeAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional personal details (personal number, place of birth)'**
  String get proofingAttributeAdditionalDetails;

  /// No description provided for @proofingAttributeFacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Your face photo from the document chip'**
  String get proofingAttributeFacePhoto;

  /// No description provided for @proofingAttributeChipChecks.
  ///
  /// In en, this message translates to:
  /// **'Document authenticity checks'**
  String get proofingAttributeChipChecks;

  /// No description provided for @proofingAttributeBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Face verification result'**
  String get proofingAttributeBiometrics;

  /// No description provided for @proofingAttributeEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything the app reads from your document'**
  String get proofingAttributeEverything;

  /// No description provided for @proofingSessionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity proofing session'**
  String get proofingSessionSectionTitle;

  /// No description provided for @proofingSubmitSectionBody.
  ///
  /// In en, this message translates to:
  /// **'This scan is for a session opened by {relyingParty}. Send the document identity and face verification result back to them.'**
  String proofingSubmitSectionBody(String relyingParty);

  /// No description provided for @proofingSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get proofingSubmitting;

  /// No description provided for @proofingSubmitTo.
  ///
  /// In en, this message translates to:
  /// **'Submit to {relyingParty}'**
  String proofingSubmitTo(String relyingParty);

  /// No description provided for @proofingSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {relyingParty}'**
  String proofingSentTo(String relyingParty);

  /// No description provided for @proofingSentBrowserFace.
  ///
  /// In en, this message translates to:
  /// **'Your document identity was sent to {relyingParty}. Finish face verification in the browser tab where you started this session.'**
  String proofingSentBrowserFace(String relyingParty);

  /// No description provided for @proofingSentEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything this verification needed from this device was sent to {relyingParty}.'**
  String proofingSentEverything(String relyingParty);

  /// No description provided for @proofingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get proofingDone;

  /// No description provided for @proofingAddToWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to Wallet'**
  String get proofingAddToWallet;

  /// No description provided for @proofingSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get proofingSubmittedTitle;

  /// No description provided for @proofingSubmittedDocument.
  ///
  /// In en, this message translates to:
  /// **'Your document identity was sent to {relyingParty}.'**
  String proofingSubmittedDocument(String relyingParty);

  /// No description provided for @proofingSubmittedDocumentAndFace.
  ///
  /// In en, this message translates to:
  /// **'Your document identity and face verification result were sent to {relyingParty}.'**
  String proofingSubmittedDocumentAndFace(String relyingParty);

  /// No description provided for @proofingSubmitFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit Failed'**
  String get proofingSubmitFailedTitle;

  /// No description provided for @proofingSubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit the result to the relying party:'**
  String get proofingSubmitFailedMessage;

  /// No description provided for @proofingDialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get proofingDialogOk;

  /// No description provided for @proofingDialogRetryHint.
  ///
  /// In en, this message translates to:
  /// **'Please try again or make an issue in GitHub of this project.'**
  String get proofingDialogRetryHint;

  /// No description provided for @proofingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get proofingRetry;

  /// No description provided for @proofingScanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan {docType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}}'**
  String proofingScanDocument(String docType);

  /// No description provided for @proofingPositionDocument.
  ///
  /// In en, this message translates to:
  /// **'Position the {docType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}}'**
  String proofingPositionDocument(String docType);

  /// No description provided for @proofingScanMrzInstructions.
  ///
  /// In en, this message translates to:
  /// **'Align the Machine Readable Zone (MRZ) with the frame at the bottom of the screen. Hold steady until scanning completes.'**
  String get proofingScanMrzInstructions;

  /// No description provided for @proofingEnterDetailsManually.
  ///
  /// In en, this message translates to:
  /// **'Enter {docType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} details manually'**
  String proofingEnterDetailsManually(String docType);

  /// No description provided for @proofingContinueInBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue in the browser'**
  String get proofingContinueInBrowserTitle;

  /// No description provided for @proofingContinueInBrowserFace.
  ///
  /// In en, this message translates to:
  /// **'Finish face verification in the browser where you started this session.'**
  String get proofingContinueInBrowserFace;

  /// No description provided for @proofingContinueInBrowserNextStep.
  ///
  /// In en, this message translates to:
  /// **'The next step of this verification continues in the browser where you started it.'**
  String get proofingContinueInBrowserNextStep;

  /// No description provided for @proofingNothingLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to do'**
  String get proofingNothingLeftTitle;

  /// No description provided for @proofingSessionAlreadyComplete.
  ///
  /// In en, this message translates to:
  /// **'This verification session is already complete.'**
  String get proofingSessionAlreadyComplete;

  /// No description provided for @proofingNotFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not finished yet'**
  String get proofingNotFinishedTitle;

  /// No description provided for @proofingNotFinishedMessage.
  ///
  /// In en, this message translates to:
  /// **'{relyingParty} still needs another step before this verification can be submitted.'**
  String proofingNotFinishedMessage(String relyingParty);

  /// No description provided for @proofingFaceIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Face verification incomplete'**
  String get proofingFaceIncompleteTitle;

  /// No description provided for @proofingFaceIncompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'No selfie was captured, so there is nothing to send. Please try again.'**
  String get proofingFaceIncompleteMessage;

  /// No description provided for @proofingWhatVerification.
  ///
  /// In en, this message translates to:
  /// **'your verification'**
  String get proofingWhatVerification;

  /// No description provided for @proofingWhatDocumentDetails.
  ///
  /// In en, this message translates to:
  /// **'your document details'**
  String get proofingWhatDocumentDetails;

  /// No description provided for @proofingWhatDocumentIdentity.
  ///
  /// In en, this message translates to:
  /// **'your document identity'**
  String get proofingWhatDocumentIdentity;

  /// No description provided for @proofingWhatFaceVerification.
  ///
  /// In en, this message translates to:
  /// **'your face verification'**
  String get proofingWhatFaceVerification;

  /// No description provided for @proofingNotAVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'This is not a verification link.'**
  String get proofingNotAVerificationLink;

  /// No description provided for @proofingSessionNoAttributes.
  ///
  /// In en, this message translates to:
  /// **'This session does not specify what to collect'**
  String get proofingSessionNoAttributes;

  /// No description provided for @proofingConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the relying party: {error}'**
  String proofingConnectFailed(String error);

  /// No description provided for @proofingQrScanned.
  ///
  /// In en, this message translates to:
  /// **'QR code scanned: {value}'**
  String proofingQrScanned(String value);

  /// No description provided for @proofingRequestTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'{what} failed: too many attempts, please wait a moment and try again'**
  String proofingRequestTooManyAttempts(String what);

  /// No description provided for @proofingRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'{what} failed: {details}'**
  String proofingRequestFailed(String what, String details);

  /// No description provided for @proofingRequestClaim.
  ///
  /// In en, this message translates to:
  /// **'Taking over the session'**
  String get proofingRequestClaim;

  /// No description provided for @proofingRequestFetch.
  ///
  /// In en, this message translates to:
  /// **'Fetching the session'**
  String get proofingRequestFetch;

  /// No description provided for @proofingRequestWatch.
  ///
  /// In en, this message translates to:
  /// **'Watching the session'**
  String get proofingRequestWatch;

  /// No description provided for @proofingRequestDeviceState.
  ///
  /// In en, this message translates to:
  /// **'Reporting the device state'**
  String get proofingRequestDeviceState;

  /// No description provided for @proofingRequestSubmitResult.
  ///
  /// In en, this message translates to:
  /// **'Submitting the result'**
  String get proofingRequestSubmitResult;

  /// No description provided for @proofingRequestStepStarted.
  ///
  /// In en, this message translates to:
  /// **'Marking step {step} started'**
  String proofingRequestStepStarted(String step);

  /// No description provided for @proofingRequestDocumentStep.
  ///
  /// In en, this message translates to:
  /// **'Submitting the document step'**
  String get proofingRequestDocumentStep;

  /// No description provided for @proofingRequestNfcStep.
  ///
  /// In en, this message translates to:
  /// **'Submitting the nfc step'**
  String get proofingRequestNfcStep;

  /// No description provided for @proofingRequestFaceStep.
  ///
  /// In en, this message translates to:
  /// **'Submitting the face verification step'**
  String get proofingRequestFaceStep;

  /// No description provided for @proofingRequestSubmitVerification.
  ///
  /// In en, this message translates to:
  /// **'Submitting the verification'**
  String get proofingRequestSubmitVerification;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
