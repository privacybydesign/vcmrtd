// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accessHandedOver => 'This verification session has been handed over to another device.';

  @override
  String get accessExpired => 'This verification session has expired. Please start a new verification.';

  @override
  String get accessCancelled => 'This verification session was cancelled. Please start a new verification.';

  @override
  String get accessUnauthorized => 'This device is no longer allowed to continue this verification session.';

  @override
  String get accessComplete => 'This verification session is already complete.';

  @override
  String get accessGone => 'This verification session no longer exists. Please start a new verification.';

  @override
  String get accessAlreadyClaimed =>
      'This verification session is already open on another device. To continue here, scan the handover QR code shown in the browser.';

  @override
  String get accessHandoverInvalid => 'This handover QR code is not valid. Ask for a new one in the browser.';

  @override
  String get accessHandoverExpired => 'This handover QR code has expired. Ask for a new one in the browser.';

  @override
  String get accessHandoverUsed => 'This handover QR code was already used. Ask for a new one in the browser.';

  @override
  String get accessClaimTokenRequired =>
      'This QR code is from an older version of the verification service and can no longer be used. Ask for a new one in the browser.';

  @override
  String get accessBrowserHandover =>
      'This QR code moves the browser part of the verification to another browser. Open it with your phone\'s camera instead, or scan the QR code the browser shows for the IDEM app.';

  @override
  String get sessionOpenFailedTitle => 'Could not open verification';

  @override
  String get sessionCompleteTitle => 'Verification complete';

  @override
  String sessionCompleteMessage(String relyingParty) {
    return 'You\'re done. Your verification was sent to $relyingParty.';
  }

  @override
  String get sessionRestartedTitle => 'Verification restarted';

  @override
  String sessionRestartedMessage(String relyingParty) {
    return '$relyingParty reset this verification, so everything you did so far was discarded. Please start again from the beginning.';
  }

  @override
  String get sessionStoppedTitle => 'Verification stopped';

  @override
  String get idDocumentPassport => 'Passport';

  @override
  String get idDocumentIdentityCard => 'Identity card';

  @override
  String get idDocumentDrivingLicence => 'Driving licence';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get docNewScan => 'New scan';

  @override
  String docConnectedBanner(String relyingParty) {
    return 'Connected — will send results to $relyingParty';
  }

  @override
  String get docPassport => 'Passport';

  @override
  String get docPassportSubtitle => 'Use a machine readable passport';

  @override
  String get docMostCommon => 'Most common';

  @override
  String get docIdentityCard => 'Identity Card';

  @override
  String get docIdentityCardSubtitle => 'Use a machine readable identity card';

  @override
  String get docDrivingLicence => 'Driving Licence';

  @override
  String get docDrivingLicenceSubtitle =>
      'Use a machine readable driving licence. Currently works primarily with Dutch licences.';

  @override
  String get docScanQrTitle => 'Scan QR code';

  @override
  String get docScanQrSubtitle => 'Scan any QR code with the camera';

  @override
  String get docAdvancedSettings => 'Advanced settings';

  @override
  String get docAdvancedSettingsSubtitle => 'Ocr Engine, Face Verification and more';

  @override
  String get docVerifyIdentityTitle => 'Verify your Identity';

  @override
  String get docSelectDocumentTypePrompt => 'Select the type of document you want to use for verification.';

  @override
  String get docSettingsTitle => 'Settings';

  @override
  String get docBack => 'Back';

  @override
  String get docActiveAuthentication => 'Active authentication';

  @override
  String get docActiveAuthenticationSubtitle => 'Perform active authentication when reading the document';

  @override
  String get docFaceEngine => 'Face verification engine';

  @override
  String get docFaceEngineOpenSource => 'Open source';

  @override
  String get docLivenessDetection => 'Liveness detection';

  @override
  String get docLivenessPassive => 'Passive';

  @override
  String get docLivenessActive => 'Active';

  @override
  String get docOcrEngine => 'OCR engine';

  @override
  String get docNfcStepStart => 'Start reading';

  @override
  String get docNfcStepDetails => 'Reading details';

  @override
  String get docNfcStepPhoto => 'Getting photo';

  @override
  String get docNfcStepAlmostDone => 'Almost done';

  @override
  String get docNfcStepStartSubtitle => 'Connecting to the chip';

  @override
  String get docNfcStepDetailsSubtitle => 'Getting personal data';

  @override
  String get docNfcStepPhotoSubtitle => 'Getting the document photo';

  @override
  String get docNfcStepAlmostDoneSubtitle => 'Verifying document security';

  @override
  String get docNfcTipFirst => 'Place your document behind your phone and move it around until it buzzes or beeps.';

  @override
  String get docNfcTipHoldSteady => 'Keep your phone and the document still - this can take a moment.';

  @override
  String get docNfcTipStuck =>
      'Reading was interrupted. Slowly lift your phone off the document and place it back down until it buzzes or beeps again.';

  @override
  String docReadDocument(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'document',
    });
    return 'Read $_temp0';
  }

  @override
  String docIosNfcHoldClose(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving license',
      'other': 'document',
    });
    return 'Hold your phone close to $_temp0';
  }

  @override
  String get docIosNfcCancelled => 'Session cancelled by user';

  @override
  String get docIosNfcCancelling => 'Cancelling...';

  @override
  String get docIosNfcFailed => 'Tag lost, try again.';

  @override
  String get docIosNfcConnecting => 'Connecting...';

  @override
  String docIosNfcReadingFile(String file) {
    return 'Reading $file';
  }

  @override
  String get docIosNfcAuthenticating => 'Authenticating';

  @override
  String docIosNfcReadingData(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving license',
      'other': 'document',
    });
    return 'Reading $_temp0 data';
  }

  @override
  String get docIosNfcSecurityCheck => 'Performing security verification...';

  @override
  String get docIosNfcSuccess => 'Success!';

  @override
  String get docIosNfcReconnecting => 'Connection lost. Slowly lift your phone and place it back down.';

  @override
  String get docNfcGuidanceTitle => 'Read the chip';

  @override
  String docNfcGuidancePlacePhone(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'document',
    });
    return 'Place your phone on the $_temp0';
  }

  @override
  String get docNfcGuidanceTipsTitle => 'Tips for better results:';

  @override
  String docNfcGuidanceTips(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'document',
    });
    return '• Place the $_temp0 behind your phone like in the example\n• Remove phone case if reading fails\n• The process may take 10–30 seconds';
  }

  @override
  String docScanDocument(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'document',
    });
    return 'Scan $_temp0';
  }

  @override
  String get docNfcNotAvailable => 'NFC is not available';

  @override
  String get docPersonalInformation => 'Personal Information';

  @override
  String get docSurname => 'Surname';

  @override
  String get docOtherNames => 'Other Names';

  @override
  String get docDateOfBirth => 'Date of Birth';

  @override
  String get docPlaceOfBirth => 'Place of Birth';

  @override
  String get docDocumentInformation => 'Document Information';

  @override
  String get docDocumentNumber => 'Document Number';

  @override
  String get docIssuingMemberState => 'Issuing Member State';

  @override
  String get docIssuingAuthority => 'Issuing Authority';

  @override
  String get docDateOfIssue => 'Date of Issue';

  @override
  String get docDateOfExpiry => 'Date of Expiry';

  @override
  String get docDrivingLicenceDataTitle => 'Driving Licence Data';

  @override
  String get docUnableToLoadPhoto => 'Unable to load photo';

  @override
  String get docCategories => 'Categories';

  @override
  String get docCategory => 'Category';

  @override
  String get docCategoryDateOfIssue => 'Date of issue';

  @override
  String get docCategoryDateOfExpiry => 'Date of expiry';

  @override
  String get docWalletDocumentNumber => 'Document number';

  @override
  String get docWalletAdded => 'Added';

  @override
  String get docRemoveFromWallet => 'Remove from wallet';

  @override
  String get docFullName => 'Full Name';

  @override
  String get docNationality => 'Nationality';

  @override
  String get docDocument => 'Document';

  @override
  String get docGender => 'Gender';

  @override
  String get docExpiryDate => 'Expiry Date';

  @override
  String get docCountry => 'Country';

  @override
  String get docVersion => 'Version';

  @override
  String get docOptionalData => 'Optional Data';

  @override
  String get docAvailableDataGroups => 'Available Data Groups';

  @override
  String docDataGroupsRead(int count, int total) {
    return 'Data Groups Read: $count/$total';
  }

  @override
  String get docActiveAuthenticationAvailable => 'Active Authentication Available';

  @override
  String get docWebAuthSession => 'Web Authentication Session';

  @override
  String docWebAuthSessionId(String sessionId) {
    return 'Session IID: $sessionId';
  }

  @override
  String docDocumentDataTitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'Identity Card',
      'drivingLicence': 'Driving Licence',
      'other': 'Document',
    });
    return '$_temp0 Data';
  }

  @override
  String get docImageNoData => 'No image data available.';

  @override
  String get docImageJpegError => 'Error displaying JPEG image.';

  @override
  String get docImageConvertingJpeg2000 => 'Converting JPEG2000 image...';

  @override
  String get docImageJpeg2000DisplayError => 'Error displaying converted JPEG2000 image.';

  @override
  String get docImageJpeg2000ConvertFailed => 'Failed to convert JPEG2000 image.';

  @override
  String get docImageUnsupportedType => 'Unknown or unsupported image type.';

  @override
  String get docIllustrationPassport => 'PASSPORT';

  @override
  String get docIllustrationIssuer => 'Kingdom of Example';

  @override
  String get docIllustrationName => 'Name: John Doe';

  @override
  String get docIllustrationNationality => 'Nationality: NL';

  @override
  String get docIllustrationDob => 'DOB: 01-01-1990';

  @override
  String get docIllustrationDrivingLicence => 'DRIVING LICENCE';

  @override
  String get faceActionBlink => 'Blink your eyes';

  @override
  String get faceActionTurnLeft => 'Turn your head left';

  @override
  String get faceActionTurnRight => 'Turn your head right';

  @override
  String get faceActionMouthOpen => 'Open your mouth and hold';

  @override
  String get faceActionSmile => 'Smile and hold';

  @override
  String faceErrorEngineInit(String error) {
    return 'Could not initialize Flutter face engine: $error';
  }

  @override
  String get faceErrorNoCamera => 'No camera available';

  @override
  String faceErrorOpenCamera(String error) {
    return 'Could not open camera: $error';
  }

  @override
  String faceErrorFrameProcessing(String error) {
    return 'Frame processing error: $error';
  }

  @override
  String get faceErrorMissingNfcImage => 'Missing NFC image';

  @override
  String faceErrorStartLiveness(String error) {
    return 'Could not start liveness: $error';
  }

  @override
  String get faceErrorUnknown => 'Unknown error';

  @override
  String faceTimeoutTakeYourTime(String action) {
    return 'Take your time - $action';
  }

  @override
  String get faceTimeoutPerformAction => 'perform the action';

  @override
  String get faceStepLabel => 'Face Verification';

  @override
  String get faceBack => 'Back';

  @override
  String get faceSettingUp => 'Setting up face verification';

  @override
  String get faceTakesAMoment => 'This only takes a moment';

  @override
  String get faceLoadingOpeningCamera => 'Opening camera';

  @override
  String get faceLoadingModels => 'Loading face models';

  @override
  String get faceAlmostDone => 'Almost done…';

  @override
  String get faceHoldStill => 'Hold still';

  @override
  String get faceOpeningCamera => 'Opening camera...';

  @override
  String get faceHowItWorks => 'How it works';

  @override
  String get faceStepCenterFace => 'Center your face inside the oval';

  @override
  String get faceStepFollowPrompts => 'Follow the on-screen prompts';

  @override
  String get faceStart => 'Start';

  @override
  String get facePreparing => 'Preparing…';

  @override
  String get faceTipNoFace => 'Position your face in the oval';

  @override
  String get faceTipCenterFace => 'Move your face into the oval';

  @override
  String get faceTipTooFar => 'Move a bit closer to the camera';

  @override
  String get faceTipTooClose => 'Move a bit further from the camera';

  @override
  String get faceTipLookStraight => 'Look straight at the camera';

  @override
  String get faceTipOpenEyes => 'Keep your eyes open';

  @override
  String get faceTipCloseMouth => 'Close your mouth';

  @override
  String get faceTipRelaxFace => 'Relax your expression';

  @override
  String get faceTipHoldStill => 'Hold still…';

  @override
  String get faceTipGetReady => 'Get ready…';

  @override
  String get faceExtraBadge => 'extra';

  @override
  String get faceVerifyingIdentity => 'Verifying identity...';

  @override
  String get faceGoBack => 'Go Back';

  @override
  String get faceTryAgain => 'Try Again';

  @override
  String get faceIdentityVerified => 'Identity Verified';

  @override
  String get faceVerificationFailed => 'Verification Failed';

  @override
  String faceScoreMatch(String threshold) {
    return 'Match (≥$threshold%)';
  }

  @override
  String get faceScoreAntiSpoof => 'Anti-spoof';

  @override
  String get faceNotAvailable => 'n/a';

  @override
  String faceScoreRppg(int count) {
    return 'rPPG ($count samples)';
  }

  @override
  String faceBpm(String bpm) {
    return '$bpm bpm';
  }

  @override
  String get faceScoreLivenessActions => 'Liveness actions';

  @override
  String get facePassed => 'passed';

  @override
  String get faceFailed => 'failed';

  @override
  String get faceScoreIdentityConsistent => 'Identity consistent';

  @override
  String get faceChangedMidSession => 'face changed mid-session';

  @override
  String get faceDocumentPhoto => 'Document photo';

  @override
  String get faceLiveCapture => 'Live capture';

  @override
  String get faceContinuing => 'Continuing…';

  @override
  String get facePreparingDocumentPhoto => 'Preparing your document photo…';

  @override
  String get faceIrisReadPortraitError => 'Could not read the reference portrait for the Iris SDK.';

  @override
  String get faceOpeningIrisCamera => 'Opening the Iris camera…';

  @override
  String get faceIrisUnavailable => 'The Iris SDK is not available on this device.';

  @override
  String get faceIrisNoActivity => 'Could not open the camera. Please try again.';

  @override
  String get faceIrisAlreadyRunning => 'A verification is already in progress.';

  @override
  String faceIrisFailedCode(String code) {
    return 'Verification failed ($code).';
  }

  @override
  String faceIrisFailedError(String error) {
    return 'Verification failed: $error';
  }

  @override
  String get faceIrisIntroTitle => 'Verify with the Iris SDK';

  @override
  String get faceIrisIntroBody =>
      'The Iris SDK opens its own full-screen camera to check that a live person is present, then compares that face against the portrait stored on your document.';

  @override
  String get faceIrisWhatToExpect => 'What to expect';

  @override
  String get faceIrisStep1 => 'A camera screen from the Iris SDK will open';

  @override
  String get faceIrisStep2 => 'Look directly at the camera and follow any prompts';

  @override
  String get faceIrisStep3 => 'Hold still until it finishes — this only takes a moment';

  @override
  String get faceStartVerification => 'Start Verification';

  @override
  String get faceSomethingWentWrong => 'Something Went Wrong';

  @override
  String get faceIrisMatchedSubtitle => 'The live face matched the document photo.';

  @override
  String get faceIrisFailedSubtitle =>
      'The live face did not match the document photo. Make sure you\'re well lit and looking at the camera, then try again.';

  @override
  String get faceCancelled => 'Cancelled';

  @override
  String get faceIrisCancelledSubtitle => 'You cancelled the verification. Tap below to try again.';

  @override
  String get faceRegulaIntroTitle => 'Check that it\'s really you';

  @override
  String get faceRegulaIntroBody =>
      'A camera screen opens to check that a live person is present. The verification service then compares your face with the photo on your document\'s chip.';

  @override
  String get faceRegulaStep1 => 'A camera screen will open';

  @override
  String get faceRegulaStep2 => 'Look straight at the camera and follow the prompts';

  @override
  String get faceRegulaStep3 => 'Hold still until it finishes — this only takes a moment';

  @override
  String get faceRegulaOpeningCamera => 'Opening the camera…';

  @override
  String get faceRegulaLiveTitle => 'Liveness Confirmed';

  @override
  String get faceRegulaLiveSubtitle => 'Your face is now compared with the photo on your document.';

  @override
  String get faceRegulaNotLiveSubtitle =>
      'We couldn\'t confirm that a live person is present. Make sure you\'re well lit and looking at the camera, then try again.';

  @override
  String get faceRegulaCancelledSubtitle => 'You cancelled the verification. Tap below to try again.';

  @override
  String get faceRegulaMatching => 'Comparing your face with your document photo…';

  @override
  String faceRegulaMatchedSubtitle(String similarity) {
    return 'Your face matches the photo on your document ($similarity% similarity).';
  }

  @override
  String get faceRegulaNoMatchSubtitle =>
      'Your face didn\'t match the photo on your document. Scan your document again to retry.';

  @override
  String get faceRegulaMatchUnavailable => 'Your face could not be compared with your document photo right now.';

  @override
  String get faceRegulaScanAgain => 'Scan document again';

  @override
  String faceRegulaFailedError(String error) {
    return 'Verification failed: $error';
  }

  @override
  String get faceSessionUnreachable => 'Can\'t reach the verification service. Retrying...';

  @override
  String get faceSessionChecking => 'Checking your verification session...';

  @override
  String get faceStopVerification => 'Stop verification';

  @override
  String faceSubmitSending(String what, String relyingParty) {
    return 'Sending $what to $relyingParty...';
  }

  @override
  String get faceSubmitCouldNotSend => 'Could not send';

  @override
  String faceSubmitFailed(String what, String relyingParty, String error) {
    return 'Sending $what to $relyingParty failed:\n\n$error';
  }

  @override
  String get faceCancel => 'Cancel';

  @override
  String get faceRetry => 'Retry';

  @override
  String get proofingConsentTitle => 'Identity proofing request';

  @override
  String get proofingConsentIntro =>
      'is requesting to verify your identity from a document. Scanning your document and completing face verification will send the result below back to them.';

  @override
  String get proofingConsentRequesting => 'They are requesting:';

  @override
  String get proofingConsentExpired => 'This request has expired.';

  @override
  String proofingConsentExpiresIn(String duration) {
    return 'This request expires in $duration.';
  }

  @override
  String get proofingDurationLessThanMinute => 'less than a minute';

  @override
  String proofingDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes', one: '1 minute');
    return '$_temp0';
  }

  @override
  String proofingDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count hours', one: '1 hour');
    return '$_temp0';
  }

  @override
  String get proofingContinue => 'Continue';

  @override
  String get proofingDecline => 'Decline';

  @override
  String get proofingAttributeDocumentIdentity => 'Document identity (name, date of birth, document number, expiry)';

  @override
  String get proofingAttributeAdditionalDetails => 'Additional personal details (personal number, place of birth)';

  @override
  String get proofingAttributeFacePhoto => 'Your face photo from the document chip';

  @override
  String get proofingAttributeChipChecks => 'Document authenticity checks';

  @override
  String get proofingAttributeBiometrics => 'Face verification result';

  @override
  String get proofingAttributeEverything => 'Everything the app reads from your document';

  @override
  String get proofingSessionSectionTitle => 'Identity proofing session';

  @override
  String proofingSubmitSectionBody(String relyingParty) {
    return 'This scan is for a session opened by $relyingParty. Send the document identity and face verification result back to them.';
  }

  @override
  String get proofingSubmitting => 'Submitting...';

  @override
  String proofingSubmitTo(String relyingParty) {
    return 'Submit to $relyingParty';
  }

  @override
  String proofingSentTo(String relyingParty) {
    return 'Sent to $relyingParty';
  }

  @override
  String proofingSentBrowserFace(String relyingParty) {
    return 'Your document identity was sent to $relyingParty. Finish face verification in the browser tab where you started this session.';
  }

  @override
  String proofingSentEverything(String relyingParty) {
    return 'Everything this verification needed from this device was sent to $relyingParty.';
  }

  @override
  String get proofingDone => 'Done';

  @override
  String get proofingAddToWallet => 'Add to Wallet';

  @override
  String get proofingSubmittedTitle => 'Submitted';

  @override
  String proofingSubmittedDocument(String relyingParty) {
    return 'Your document identity was sent to $relyingParty.';
  }

  @override
  String proofingSubmittedDocumentAndFace(String relyingParty) {
    return 'Your document identity and face verification result were sent to $relyingParty.';
  }

  @override
  String get proofingSubmitFailedTitle => 'Submit Failed';

  @override
  String get proofingSubmitFailedMessage => 'Failed to submit the result to the relying party:';

  @override
  String get proofingDialogOk => 'OK';

  @override
  String get proofingDialogRetryHint => 'Please try again or make an issue in GitHub of this project.';

  @override
  String get proofingRetry => 'Retry';

  @override
  String proofingScanDocument(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Scan $_temp0';
  }

  @override
  String proofingPositionDocument(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Position the $_temp0';
  }

  @override
  String get proofingScanMrzInstructions =>
      'Align the Machine Readable Zone (MRZ) with the frame at the bottom of the screen. Hold steady until scanning completes.';

  @override
  String proofingEnterDetailsManually(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Enter $_temp0 details manually';
  }

  @override
  String get proofingContinueInBrowserTitle => 'Continue in the browser';

  @override
  String get proofingContinueInBrowserFace => 'Finish face verification in the browser where you started this session.';

  @override
  String get proofingContinueInBrowserNextStep =>
      'The next step of this verification continues in the browser where you started it.';

  @override
  String get proofingNothingLeftTitle => 'Nothing left to do';

  @override
  String get proofingSessionAlreadyComplete => 'This verification session is already complete.';

  @override
  String get proofingNotFinishedTitle => 'Not finished yet';

  @override
  String proofingNotFinishedMessage(String relyingParty) {
    return '$relyingParty still needs another step before this verification can be submitted.';
  }

  @override
  String get proofingFaceIncompleteTitle => 'Face verification incomplete';

  @override
  String get proofingFaceIncompleteMessage => 'No selfie was captured, so there is nothing to send. Please try again.';

  @override
  String get proofingWhatVerification => 'your verification';

  @override
  String get proofingWhatDocumentDetails => 'your document details';

  @override
  String get proofingWhatDocumentIdentity => 'your document identity';

  @override
  String get proofingWhatFaceVerification => 'your face verification';

  @override
  String get proofingNotAVerificationLink => 'This is not a verification link.';

  @override
  String get proofingSessionNoAttributes => 'This session does not specify what to collect';

  @override
  String proofingConnectFailed(String error) {
    return 'Could not connect to the relying party: $error';
  }

  @override
  String proofingQrScanned(String value) {
    return 'QR code scanned: $value';
  }

  @override
  String proofingRequestTooManyAttempts(String what) {
    return '$what failed: too many attempts, please wait a moment and try again';
  }

  @override
  String proofingRequestFailed(String what, String details) {
    return '$what failed: $details';
  }

  @override
  String get proofingRequestClaim => 'Taking over the session';

  @override
  String get proofingRequestFetch => 'Fetching the session';

  @override
  String get proofingRequestWatch => 'Watching the session';

  @override
  String get proofingRequestDeviceState => 'Reporting the device state';

  @override
  String get proofingRequestSubmitResult => 'Submitting the result';

  @override
  String proofingRequestStepStarted(String step) {
    return 'Marking step $step started';
  }

  @override
  String get proofingRequestDocumentStep => 'Submitting the document step';

  @override
  String get proofingRequestNfcStep => 'Submitting the nfc step';

  @override
  String get proofingRequestFaceStep => 'Submitting the face verification step';

  @override
  String get proofingRequestSubmitVerification => 'Submitting the verification';
}
