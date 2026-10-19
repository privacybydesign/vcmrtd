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
  /// **'Perform active authentication when reading the document. A verification session follows its own flow.'**
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

  /// No description provided for @docPhotoStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Document photo'**
  String get docPhotoStepLabel;

  /// No description provided for @docPhotoFrontTitle.
  ///
  /// In en, this message translates to:
  /// **'Photograph the front'**
  String get docPhotoFrontTitle;

  /// No description provided for @docPhotoFrontInstructionsPassport.
  ///
  /// In en, this message translates to:
  /// **'Place the page with your photo and personal details inside the frame. Use a flat surface and good light, and avoid glare.'**
  String get docPhotoFrontInstructionsPassport;

  /// No description provided for @docPhotoFrontInstructionsCard.
  ///
  /// In en, this message translates to:
  /// **'Place the front of your document, the side with your photo, inside the frame. Use a flat surface and good light, and avoid glare.'**
  String get docPhotoFrontInstructionsCard;

  /// No description provided for @docPhotoBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Now photograph the back'**
  String get docPhotoBackTitle;

  /// No description provided for @docPhotoBackInstructions.
  ///
  /// In en, this message translates to:
  /// **'Turn your document over and place the back inside the frame.'**
  String get docPhotoBackInstructions;

  /// No description provided for @docPhotoSideFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get docPhotoSideFront;

  /// No description provided for @docPhotoSideBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get docPhotoSideBack;

  /// No description provided for @docPhotoSideProgress.
  ///
  /// In en, this message translates to:
  /// **'{side} · {current} of {total}'**
  String docPhotoSideProgress(String side, int current, int total);

  /// No description provided for @docPhotoNoBack.
  ///
  /// In en, this message translates to:
  /// **'My document has no back'**
  String get docPhotoNoBack;

  /// No description provided for @docPhotoTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get docPhotoTake;

  /// No description provided for @docPhotoReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the photo'**
  String get docPhotoReviewTitle;

  /// No description provided for @docPhotoReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Are all details sharp and readable, without glare or anything covering them?'**
  String get docPhotoReviewMessage;

  /// No description provided for @docPhotoReviewScannedMessage.
  ///
  /// In en, this message translates to:
  /// **'This side was photographed while the MRZ was read. Are all details sharp and readable, without glare or anything covering them?'**
  String get docPhotoReviewScannedMessage;

  /// No description provided for @docPhotoRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get docPhotoRetake;

  /// No description provided for @docPhotoUse.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get docPhotoUse;

  /// No description provided for @docPhotoErrorNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera available'**
  String get docPhotoErrorNoCamera;

  /// No description provided for @docPhotoErrorCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not use the camera: {error}'**
  String docPhotoErrorCamera(String error);

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

  /// No description provided for @faceSelfieIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Take a quick selfie'**
  String get faceSelfieIntroTitle;

  /// No description provided for @faceTipEvenLight.
  ///
  /// In en, this message translates to:
  /// **'Find a spot with even light'**
  String get faceTipEvenLight;

  /// No description provided for @faceTipRemoveAccessories.
  ///
  /// In en, this message translates to:
  /// **'Take off sunglasses and hats'**
  String get faceTipRemoveAccessories;

  /// No description provided for @faceStartSelfieCheck.
  ///
  /// In en, this message translates to:
  /// **'Start selfie check'**
  String get faceStartSelfieCheck;

  /// No description provided for @faceSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something Went Wrong'**
  String get faceSomethingWentWrong;

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

  /// No description provided for @proofingVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get proofingVerifiedTitle;

  /// No description provided for @proofingShareBody.
  ///
  /// In en, this message translates to:
  /// **'Share the result with {relyingParty} to finish.'**
  String proofingShareBody(String relyingParty);

  /// No description provided for @proofingShareWith.
  ///
  /// In en, this message translates to:
  /// **'Share with {relyingParty}'**
  String proofingShareWith(String relyingParty);

  /// No description provided for @proofingSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get proofingSharing;

  /// No description provided for @proofingAddToWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to Wallet'**
  String get proofingAddToWallet;

  /// No description provided for @proofingDialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get proofingDialogOk;

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

  /// No description provided for @proofingScanMrzPhotoInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place the whole side with the Machine Readable Zone (MRZ) inside the frame, on a flat surface in good light. Hold steady: once the MRZ is read, this side is photographed too.'**
  String get proofingScanMrzPhotoInstructions;

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

  /// No description provided for @proofingWhatDocumentPhoto.
  ///
  /// In en, this message translates to:
  /// **'your document photo'**
  String get proofingWhatDocumentPhoto;

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

  /// No description provided for @proofingRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond in time - check your internet connection and try again'**
  String get proofingRequestTimedOut;

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

  /// No description provided for @proofingRequestDocumentPhotoStep.
  ///
  /// In en, this message translates to:
  /// **'Submitting the document photo step'**
  String get proofingRequestDocumentPhotoStep;

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

  /// No description provided for @guidedStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String guidedStepOf(int step, int total);

  /// No description provided for @guidedSaveForNextTime.
  ///
  /// In en, this message translates to:
  /// **'Save for next time'**
  String get guidedSaveForNextTime;

  /// No description provided for @guidedSaveForNextTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep this document on this phone so you don’t have to scan it again.'**
  String get guidedSaveForNextTimeSubtitle;

  /// No description provided for @guidedPoweredByIdem.
  ///
  /// In en, this message translates to:
  /// **'Powered by Idem'**
  String get guidedPoweredByIdem;

  /// No description provided for @settingsYourDocuments.
  ///
  /// In en, this message translates to:
  /// **'Your documents'**
  String get settingsYourDocuments;

  /// No description provided for @settingsSavedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Saved documents'**
  String get settingsSavedDocuments;

  /// No description provided for @settingsSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None on this phone} other{{count} on this phone}}'**
  String settingsSavedCount(int count);

  /// No description provided for @settingsChipReading.
  ///
  /// In en, this message translates to:
  /// **'Chip reading'**
  String get settingsChipReading;

  /// No description provided for @settingsChipCheck.
  ///
  /// In en, this message translates to:
  /// **'Chip check'**
  String get settingsChipCheck;

  /// No description provided for @settingsChipCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask the chip to prove it isn’t a copy (active authentication)'**
  String get settingsChipCheckSubtitle;

  /// No description provided for @settingsSelfieCheck.
  ///
  /// In en, this message translates to:
  /// **'Selfie check'**
  String get settingsSelfieCheck;

  /// No description provided for @settingsFaceEngine.
  ///
  /// In en, this message translates to:
  /// **'Face engine'**
  String get settingsFaceEngine;

  /// No description provided for @settingsFaceEngineOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Open source, on this phone'**
  String get settingsFaceEngineOnDevice;

  /// No description provided for @settingsLivenessCheck.
  ///
  /// In en, this message translates to:
  /// **'Liveness check'**
  String get settingsLivenessCheck;

  /// No description provided for @settingsLivenessPassive.
  ///
  /// In en, this message translates to:
  /// **'Passive: just hold still'**
  String get settingsLivenessPassive;

  /// No description provided for @settingsLivenessActive.
  ///
  /// In en, this message translates to:
  /// **'Active: follow the prompts'**
  String get settingsLivenessActive;

  /// No description provided for @settingsDocumentScanning.
  ///
  /// In en, this message translates to:
  /// **'Document scanning'**
  String get settingsDocumentScanning;

  /// No description provided for @settingsTextRecognition.
  ///
  /// In en, this message translates to:
  /// **'Text recognition'**
  String get settingsTextRecognition;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @savedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No documents on this phone} =1{1 document on this phone} other{{count} documents on this phone}}'**
  String savedCount(int count);

  /// No description provided for @savedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'After you share a document, you can save it here so you don’t have to scan it again.'**
  String get savedEmptyBody;

  /// No description provided for @savedBody.
  ///
  /// In en, this message translates to:
  /// **'When you scan a QR code, you can pick one of these instead of scanning your ID again. They are only shared when you agree.'**
  String get savedBody;

  /// No description provided for @savedValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String savedValidUntil(String date);

  /// No description provided for @savedAddedToday.
  ///
  /// In en, this message translates to:
  /// **'added today'**
  String get savedAddedToday;

  /// No description provided for @savedAddedOn.
  ///
  /// In en, this message translates to:
  /// **'added {date}'**
  String savedAddedOn(String date);

  /// No description provided for @savedRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from this phone'**
  String get savedRemove;

  /// No description provided for @chooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose document'**
  String get chooseTitle;

  /// No description provided for @chooseHeading.
  ///
  /// In en, this message translates to:
  /// **'Which document do you want to use?'**
  String get chooseHeading;

  /// No description provided for @chooseIntroEmpty.
  ///
  /// In en, this message translates to:
  /// **'{relyingParty} asked to verify your identity. Add the document you want to use.'**
  String chooseIntroEmpty(String relyingParty);

  /// No description provided for @chooseIntroSaved.
  ///
  /// In en, this message translates to:
  /// **'{relyingParty} asked to verify your identity. Use a saved document or add a new one.'**
  String chooseIntroSaved(String relyingParty);

  /// No description provided for @chooseSavedOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get chooseSavedOnPhone;

  /// No description provided for @chooseSelfieHint.
  ///
  /// In en, this message translates to:
  /// **'You’ll take a quick selfie to confirm the document is yours.'**
  String get chooseSelfieHint;

  /// No description provided for @chooseAddDocument.
  ///
  /// In en, this message translates to:
  /// **'Add a document'**
  String get chooseAddDocument;

  /// No description provided for @chooseAddNewDocument.
  ///
  /// In en, this message translates to:
  /// **'Or add a new document'**
  String get chooseAddNewDocument;

  /// No description provided for @chooseContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with {documentType, select, passport{passport} identityCard{identity card} drivingLicence{driving licence} other{document}}'**
  String chooseContinueWith(String documentType);

  /// No description provided for @chooseValidUntil.
  ///
  /// In en, this message translates to:
  /// **'valid until {date}'**
  String chooseValidUntil(String date);

  /// No description provided for @homeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'IDENTITY VERIFICATION'**
  String get homeEyebrow;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with a QR code'**
  String get homeTitle;

  /// No description provided for @homeBody.
  ///
  /// In en, this message translates to:
  /// **'When a service asks you to verify who you are, it shows a QR code. Scan it here to start.'**
  String get homeBody;

  /// No description provided for @homeConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'You accepted a request from {relyingParty}. Continue where you left off.'**
  String homeConnectedBody(String relyingParty);

  /// No description provided for @homeContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with {relyingParty}'**
  String homeContinueWith(String relyingParty);

  /// No description provided for @homeHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get homeHowItWorks;

  /// No description provided for @homeStepScan.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown by the website or app.'**
  String get homeStepScan;

  /// No description provided for @homeStepDocument.
  ///
  /// In en, this message translates to:
  /// **'Use a document saved on this phone, or scan your ID.'**
  String get homeStepDocument;

  /// No description provided for @homeStepSelfie.
  ///
  /// In en, this message translates to:
  /// **'Take a quick selfie, then share only what was asked for.'**
  String get homeStepSelfie;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get consentTitle;

  /// No description provided for @consentHeading.
  ///
  /// In en, this message translates to:
  /// **'{party} wants to verify your identity'**
  String consentHeading(String party);

  /// No description provided for @consentTheyWillReceive.
  ///
  /// In en, this message translates to:
  /// **'They will receive'**
  String get consentTheyWillReceive;

  /// No description provided for @qrScanClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get qrScanClose;

  /// No description provided for @qrScanPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the QR code'**
  String get qrScanPointCamera;

  /// No description provided for @qrScanWhereToFind.
  ///
  /// In en, this message translates to:
  /// **'You’ll find it on the website or app that asked you to verify.'**
  String get qrScanWhereToFind;

  /// No description provided for @qrScanNothingShared.
  ///
  /// In en, this message translates to:
  /// **'Nothing is shared until you agree on the next screen.'**
  String get qrScanNothingShared;

  /// No description provided for @selfieIntroBody.
  ///
  /// In en, this message translates to:
  /// **'We compare your face with the photo on your document chip. It takes a few seconds.'**
  String get selfieIntroBody;

  /// No description provided for @selfieTipOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Processed on your phone. No video is stored.'**
  String get selfieTipOnDevice;

  /// No description provided for @selfieGettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get selfieGettingReady;

  /// No description provided for @selfieStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get selfieStarting;

  /// No description provided for @selfieCameraGettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting the camera ready…'**
  String get selfieCameraGettingReady;

  /// No description provided for @selfieHoldStillCountdown.
  ///
  /// In en, this message translates to:
  /// **'Hold still · {seconds}s'**
  String selfieHoldStillCountdown(int seconds);

  /// No description provided for @selfieStoppedTitle.
  ///
  /// In en, this message translates to:
  /// **'Selfie check stopped'**
  String get selfieStoppedTitle;

  /// No description provided for @selfieTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get selfieTryAgain;

  /// No description provided for @selfieGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get selfieGoBack;

  /// No description provided for @selfieNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t match your face'**
  String get selfieNoMatchTitle;

  /// No description provided for @selfieNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Make sure your face is well lit and fills the oval, then try again.'**
  String get selfieNoMatchMessage;

  /// No description provided for @selfieCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking your selfie'**
  String get selfieCheckingTitle;

  /// No description provided for @selfieSettingUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting up the selfie check'**
  String get selfieSettingUpTitle;

  /// No description provided for @selfieComparing.
  ///
  /// In en, this message translates to:
  /// **'Comparing your face with the photo on your document chip.'**
  String get selfieComparing;

  /// No description provided for @selfieLoadingModels.
  ///
  /// In en, this message translates to:
  /// **'Loading face models…'**
  String get selfieLoadingModels;

  /// No description provided for @selfieOpeningCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening camera…'**
  String get selfieOpeningCamera;

  /// No description provided for @dataViewDocumentRead.
  ///
  /// In en, this message translates to:
  /// **'Document read'**
  String get dataViewDocumentRead;

  /// No description provided for @dataViewDrivingLicenceRead.
  ///
  /// In en, this message translates to:
  /// **'Driving licence read'**
  String get dataViewDrivingLicenceRead;

  /// No description provided for @dataViewChipRead.
  ///
  /// In en, this message translates to:
  /// **'We read your {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} chip.'**
  String dataViewChipRead(String documentType);

  /// No description provided for @dataViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{documentType, select, passport{Passport} identityCard{ID card} drivingLicence{Driving licence} other{Document}} · {country}'**
  String dataViewSubtitle(String documentType, String country);

  /// No description provided for @dataViewAddToWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to wallet'**
  String get dataViewAddToWallet;

  /// No description provided for @dataViewDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dataViewDateOfBirth;

  /// No description provided for @dataViewPlaceOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Place of birth'**
  String get dataViewPlaceOfBirth;

  /// No description provided for @dataViewDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get dataViewDocumentNumber;

  /// No description provided for @dataViewIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get dataViewIssuedBy;

  /// No description provided for @dataViewValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get dataViewValidUntil;

  /// No description provided for @dataViewCategoryUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String dataViewCategoryUntil(String date);

  /// No description provided for @nfcHoldPhoneOn.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone on the {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}}'**
  String nfcHoldPhoneOn(String documentType);

  /// No description provided for @nfcGuidanceIntro.
  ///
  /// In en, this message translates to:
  /// **'Your {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} has a chip that proves it is genuine. We read it with NFC.'**
  String nfcGuidanceIntro(String documentType);

  /// No description provided for @nfcGuidanceStepLay.
  ///
  /// In en, this message translates to:
  /// **'{documentType, select, passport{Close the passport and lay it on a flat, non-metal surface.} identityCard{Lay the ID card on a flat, non-metal surface.} drivingLicence{Lay the driving licence on a flat, non-metal surface.} other{Lay the document on a flat, non-metal surface.}}'**
  String nfcGuidanceStepLay(String documentType);

  /// No description provided for @nfcGuidanceStepPlace.
  ///
  /// In en, this message translates to:
  /// **'Place the top half of your phone flat on the {documentType, select, passport{cover} other{card}}.'**
  String nfcGuidanceStepPlace(String documentType);

  /// No description provided for @nfcGuidanceStepKeepStill.
  ///
  /// In en, this message translates to:
  /// **'Keep still until the check turns green. Remove a thick phone case if reading fails.'**
  String get nfcGuidanceStepKeepStill;

  /// No description provided for @nfcTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'NFC is turned off. Turn it on in your phone\'s settings to continue.'**
  String get nfcTurnedOff;

  /// No description provided for @nfcCancelReading.
  ///
  /// In en, this message translates to:
  /// **'Cancel reading'**
  String get nfcCancelReading;

  /// No description provided for @nfcReadingConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get nfcReadingConnectionLost;

  /// No description provided for @nfcReadingStoppedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading stopped'**
  String get nfcReadingStoppedTitle;

  /// No description provided for @nfcReadingStoppedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start again when you are ready.'**
  String get nfcReadingStoppedSubtitle;

  /// No description provided for @nfcReadingFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading failed'**
  String get nfcReadingFailedTitle;

  /// No description provided for @nfcReadingFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check that the {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} lies flat under your phone and try again.'**
  String nfcReadingFailedSubtitle(String documentType);

  /// No description provided for @nfcReadingSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Chip read'**
  String get nfcReadingSuccessTitle;

  /// No description provided for @nfcReadingSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} is genuine.'**
  String nfcReadingSuccessSubtitle(String documentType);

  /// No description provided for @nfcReadingInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Don’t move your phone'**
  String get nfcReadingInProgressTitle;

  /// No description provided for @nfcReadingInProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep it on the {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} until reading is complete.'**
  String nfcReadingInProgressSubtitle(String documentType);

  /// No description provided for @nfcRingNotRead.
  ///
  /// In en, this message translates to:
  /// **'Not read'**
  String get nfcRingNotRead;

  /// No description provided for @nfcRingComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get nfcRingComplete;

  /// No description provided for @nfcRingReading.
  ///
  /// In en, this message translates to:
  /// **'Reading chip'**
  String get nfcRingReading;

  /// No description provided for @nfcTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get nfcTryAgain;

  /// No description provided for @nfcChecklistSecureDone.
  ///
  /// In en, this message translates to:
  /// **'Secure connection set up'**
  String get nfcChecklistSecureDone;

  /// No description provided for @nfcChecklistSecureActive.
  ///
  /// In en, this message translates to:
  /// **'Setting up a secure connection'**
  String get nfcChecklistSecureActive;

  /// No description provided for @nfcChecklistDetailsDone.
  ///
  /// In en, this message translates to:
  /// **'Personal details read'**
  String get nfcChecklistDetailsDone;

  /// No description provided for @nfcChecklistDetailsActive.
  ///
  /// In en, this message translates to:
  /// **'Reading personal details'**
  String get nfcChecklistDetailsActive;

  /// No description provided for @nfcChecklistPhotoDone.
  ///
  /// In en, this message translates to:
  /// **'{documentType, select, passport{Passport} identityCard{ID card} drivingLicence{Driving licence} other{Document}} photo read'**
  String nfcChecklistPhotoDone(String documentType);

  /// No description provided for @nfcChecklistPhotoActive.
  ///
  /// In en, this message translates to:
  /// **'Reading {documentType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} photo'**
  String nfcChecklistPhotoActive(String documentType);

  /// No description provided for @nfcChecklistGenuineDone.
  ///
  /// In en, this message translates to:
  /// **'Chip is genuine'**
  String get nfcChecklistGenuineDone;

  /// No description provided for @nfcChecklistGenuineActive.
  ///
  /// In en, this message translates to:
  /// **'Checking the chip is genuine'**
  String get nfcChecklistGenuineActive;

  /// No description provided for @scanClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get scanClose;

  /// No description provided for @scanSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Place the photo page in the frame} identityCard{Place the back of your ID card in the frame} drivingLicence{Place the back of your driving licence in the frame} other{Place your document in the frame}}'**
  String scanSheetTitle(String docType);

  /// No description provided for @scanSheetTip.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Make sure the two lines of text at the bottom are sharp and not covered by your fingers or glare.} identityCard{Make sure the three lines of text at the bottom are sharp and not covered by your fingers or glare.} drivingLicence{Make sure the line of text at the bottom is sharp and not covered by your fingers or glare.} other{Make sure the text at the bottom is sharp and not covered by your fingers or glare.}}'**
  String scanSheetTip(String docType);

  /// No description provided for @scanHideTips.
  ///
  /// In en, this message translates to:
  /// **'Hide tips'**
  String get scanHideTips;

  /// No description provided for @scanShowTips.
  ///
  /// In en, this message translates to:
  /// **'Show tips and manual entry'**
  String get scanShowTips;

  /// No description provided for @scanEnterDetailsManually.
  ///
  /// In en, this message translates to:
  /// **'Enter details manually'**
  String get scanEnterDetailsManually;

  /// No description provided for @manualBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get manualBack;

  /// No description provided for @manualTopBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter details'**
  String get manualTopBarTitle;

  /// No description provided for @manualContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get manualContinue;

  /// No description provided for @manualLicenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Type the code from your driving licence'**
  String get manualLicenceTitle;

  /// No description provided for @manualLicenceIntro.
  ///
  /// In en, this message translates to:
  /// **'It’s the single line of {length} characters on the back. It unlocks the chip.'**
  String manualLicenceIntro(int length);

  /// No description provided for @manualDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your {docType, select, passport{passport} identityCard{ID card} drivingLicence{driving licence} other{document}} details'**
  String manualDocumentTitle(String docType);

  /// No description provided for @manualDocumentIntro.
  ///
  /// In en, this message translates to:
  /// **'Copy them from the {docType, select, passport{photo page} other{front of the card}}. They unlock the chip, so they need to match exactly.'**
  String manualDocumentIntro(String docType);

  /// No description provided for @manualLicenceParseError.
  ///
  /// In en, this message translates to:
  /// **'That code could not be read. Check it against your licence and try again.'**
  String get manualLicenceParseError;

  /// No description provided for @manualDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{Passport number} identityCard{Identity card number} drivingLicence{Driving licence number} other{Document number}}'**
  String manualDocumentNumber(String docType);

  /// No description provided for @manualDocumentNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AB1234567'**
  String get manualDocumentNumberHint;

  /// No description provided for @manualDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get manualDateOfBirth;

  /// No description provided for @manualExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get manualExpiryDate;

  /// No description provided for @manualWhereToFind.
  ///
  /// In en, this message translates to:
  /// **'Where to find them'**
  String get manualWhereToFind;

  /// No description provided for @manualWhereToFindBody.
  ///
  /// In en, this message translates to:
  /// **'{docType, select, passport{The passport number is at the top right of the photo page. The dates are listed as date of birth and date of expiry.} other{The document number and both dates are on the card, next to your photo.}}'**
  String manualWhereToFindBody(String docType);

  /// No description provided for @manualLicenceCode.
  ///
  /// In en, this message translates to:
  /// **'Licence code'**
  String get manualLicenceCode;

  /// No description provided for @manualLicenceCodePrefix.
  ///
  /// In en, this message translates to:
  /// **'Starts with D1, D2 or DL'**
  String get manualLicenceCodePrefix;

  /// No description provided for @manualDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get manualDateNotSet;

  /// No description provided for @manualDateSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get manualDateSelect;
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
