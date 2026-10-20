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
  String get accessUntrustedServer =>
      'This QR code isn\'t from a verification service this app works with, so it wasn\'t opened.';

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
  String get docScanQrTitle => 'Scan QR code';

  @override
  String get docSettingsTitle => 'Settings';

  @override
  String get docBack => 'Back';

  @override
  String get docFaceEngineOpenSource => 'Open source';

  @override
  String get docNfcStepStart => 'Start reading';

  @override
  String get docNfcTipFirst => 'Place your document behind your phone and move it around until it buzzes or beeps.';

  @override
  String get docNfcTipHoldSteady => 'Keep your phone and the document still - this can take a moment.';

  @override
  String get docNfcTipStuck =>
      'Reading was interrupted. Slowly lift your phone off the document and place it back down until it buzzes or beeps again.';

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
  String get docCategories => 'Categories';

  @override
  String get docNationality => 'Nationality';

  @override
  String get docWebAuthSession => 'Web Authentication Session';

  @override
  String docWebAuthSessionId(String sessionId) {
    return 'Session IID: $sessionId';
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
  String get docPhotoStepLabel => 'Document photo';

  @override
  String get docPhotoFrontTitle => 'Photograph the front';

  @override
  String get docPhotoFrontInstructionsPassport =>
      'Place the page with your photo and personal details inside the frame. Use a flat surface and good light, and avoid glare.';

  @override
  String get docPhotoFrontInstructionsCard =>
      'Place the front of your document, the side with your photo, inside the frame. Use a flat surface and good light, and avoid glare.';

  @override
  String get docPhotoBackTitle => 'Now photograph the back';

  @override
  String get docPhotoBackInstructions => 'Turn your document over and place the back inside the frame.';

  @override
  String get docPhotoBackInstructionsPassport => 'Now place the back of the page with your photo inside the frame.';

  @override
  String get docPhotoSideFront => 'Front';

  @override
  String get docPhotoSideBack => 'Back';

  @override
  String docPhotoSideProgress(String side, int current, int total) {
    return '$side · $current of $total';
  }

  @override
  String get docPhotoTake => 'Take photo';

  @override
  String get docPhotoHintNoDocument => 'Place the whole document inside the frame, on a plain surface.';

  @override
  String get docPhotoHintNoPortrait => 'Place the side with your photo inside the frame.';

  @override
  String get docPhotoHintNoMrz => 'Place the side with the machine-readable lines (<<<) inside the frame.';

  @override
  String get docPhotoHintGlare => 'Reflection on the document. Tilt it slightly.';

  @override
  String get docPhotoHintTilted => 'Hold your phone straight above the document.';

  @override
  String get docPhotoHintUnreadable => 'The text on the document isn\'t readable yet. Hold it still, in good light.';

  @override
  String get docPhotoHintTooDark => 'Too dark. Move to a place with more light.';

  @override
  String get docPhotoHintBlurry => 'Not sharp yet. Hold your phone still.';

  @override
  String get docPhotoReviewTitle => 'Check the photo';

  @override
  String get docPhotoReviewMessage => 'Are all details sharp and readable, without glare or anything covering them?';

  @override
  String get docPhotoReviewScannedMessage =>
      'This side was photographed while the MRZ was read. Are all details sharp and readable, without glare or anything covering them?';

  @override
  String get docPhotoRetake => 'Retake';

  @override
  String get docPhotoUse => 'Use photo';

  @override
  String get docPhotoPreparing => 'Preparing the photo…';

  @override
  String get docPhotoErrorNoCamera => 'No camera available';

  @override
  String docPhotoErrorCamera(String error) {
    return 'Could not use the camera: $error';
  }

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
  String get faceBack => 'Back';

  @override
  String get faceHoldStill => 'Hold still';

  @override
  String get faceOpeningCamera => 'Opening camera...';

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
  String get faceTryAgain => 'Try Again';

  @override
  String get faceVerificationFailed => 'Verification Failed';

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
  String get faceIrisIntroBody =>
      'The Iris SDK opens its own full-screen camera to check that a live person is present, then compares that face against the portrait stored on your document.';

  @override
  String get faceIrisStep2 => 'Look directly at the camera and follow any prompts';

  @override
  String get faceSelfieIntroTitle => 'Take a quick selfie';

  @override
  String get faceTipEvenLight => 'Find a spot with even light';

  @override
  String get faceTipRemoveAccessories => 'Take off sunglasses and hats';

  @override
  String get faceStartSelfieCheck => 'Start selfie check';

  @override
  String get faceSomethingWentWrong => 'Something Went Wrong';

  @override
  String get faceIrisFailedSubtitle =>
      'The live face did not match the document photo. Make sure you\'re well lit and looking at the camera, then try again.';

  @override
  String get faceCancelled => 'Cancelled';

  @override
  String get faceIrisCancelledSubtitle => 'You cancelled the verification. Tap below to try again.';

  @override
  String get faceRegulaIntroBody =>
      'A camera screen opens to check that a live person is present. The verification service then compares your face with the photo on your document\'s chip.';

  @override
  String get faceRegulaStep2 => 'Look straight at the camera and follow the prompts';

  @override
  String get faceRegulaOpeningCamera => 'Opening the camera…';

  @override
  String get faceRegulaNotLiveSubtitle =>
      'We couldn\'t confirm that a live person is present. Make sure you\'re well lit and looking at the camera, then try again.';

  @override
  String get faceRegulaCancelledSubtitle => 'You cancelled the verification. Tap below to try again.';

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
  String get proofingVerifiedTitle => 'Document read';

  @override
  String proofingShareBody(String relyingParty) {
    return 'Your document details were sent to $relyingParty. Finish to complete the verification.';
  }

  @override
  String proofingShareWith(String relyingParty) {
    return 'Finish with $relyingParty';
  }

  @override
  String get proofingSharing => 'Finishing…';

  @override
  String proofingStepSending(String relyingParty) {
    return 'Sending to $relyingParty…';
  }

  @override
  String get proofingDialogOk => 'OK';

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
  String get proofingWhatDocumentPhoto => 'your document photo';

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
  String get proofingRequestTimedOut =>
      'The server did not respond in time - check your internet connection and try again';

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
  String proofingRequestStepStarted(String step) {
    return 'Marking step $step started';
  }

  @override
  String get proofingRequestDocumentStep => 'Submitting the document step';

  @override
  String get proofingRequestNfcStep => 'Submitting the nfc step';

  @override
  String get proofingRequestDocumentPhotoStep => 'Submitting the document photo step';

  @override
  String get proofingRequestFaceStep => 'Submitting the face verification step';

  @override
  String get proofingRequestSubmitVerification => 'Submitting the verification';

  @override
  String guidedStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get guidedSaveForNextTime => 'Save for next time';

  @override
  String get guidedSaveForNextTimeSubtitle =>
      'Keep this document on this phone until the app is closed, so you don’t have to scan it again.';

  @override
  String get settingsYourDocuments => 'Your documents';

  @override
  String get settingsSavedDocuments => 'Saved documents';

  @override
  String settingsSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count on this phone',
      zero: 'None on this phone',
    );
    return '$_temp0';
  }

  @override
  String get settingsChipReading => 'Chip reading';

  @override
  String get settingsChipCheck => 'Chip check';

  @override
  String get settingsChipCheckSubtitle => 'Ask the chip to prove it isn’t a copy (active authentication)';

  @override
  String get settingsSelfieCheck => 'Selfie check';

  @override
  String get settingsFaceEngine => 'Face engine';

  @override
  String get settingsFaceEngineOnDevice => 'Open source, on this phone';

  @override
  String get settingsLivenessCheck => 'Liveness check';

  @override
  String get settingsLivenessPassive => 'Passive: just hold still';

  @override
  String get settingsLivenessActive => 'Active: follow the prompts';

  @override
  String get settingsDocumentScanning => 'Document scanning';

  @override
  String get settingsTextRecognition => 'Text recognition';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents on this phone',
      one: '1 document on this phone',
      zero: 'No documents on this phone',
    );
    return '$_temp0';
  }

  @override
  String get savedEmptyBody =>
      'After you share a document, you can save it here until the app is closed, so you don’t have to scan it again.';

  @override
  String get savedBody =>
      'When you scan a QR code, you can pick one of these instead of scanning your ID again. They are only shared when you agree, and are removed when the app is closed.';

  @override
  String savedValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get savedAddedToday => 'added today';

  @override
  String savedAddedOn(String date) {
    return 'added $date';
  }

  @override
  String get savedRemove => 'Remove from this phone';

  @override
  String get chooseTitle => 'Choose document';

  @override
  String get chooseHeading => 'Which document do you want to use?';

  @override
  String chooseIntroEmpty(String relyingParty) {
    return '$relyingParty asked to verify your identity. Add the document you want to use.';
  }

  @override
  String chooseIntroSaved(String relyingParty) {
    return '$relyingParty asked to verify your identity. Use a saved document or add a new one.';
  }

  @override
  String get chooseSavedOnPhone => 'Saved on this phone';

  @override
  String get chooseSelfieHint => 'You’ll take a quick selfie to confirm the document is yours.';

  @override
  String get chooseAddDocument => 'Add a document';

  @override
  String get chooseAddNewDocument => 'Or add a new document';

  @override
  String chooseContinueWith(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'identity card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Continue with $_temp0';
  }

  @override
  String chooseValidUntil(String date) {
    return 'valid until $date';
  }

  @override
  String get homeEyebrow => 'IDENTITY VERIFICATION';

  @override
  String get homeTitle => 'Verify your identity with a QR code';

  @override
  String get homeBody => 'When a service asks you to verify who you are, it shows a QR code. Scan it here to start.';

  @override
  String homeConnectedBody(String relyingParty) {
    return 'You accepted a request from $relyingParty. Continue where you left off.';
  }

  @override
  String homeContinueWith(String relyingParty) {
    return 'Continue with $relyingParty';
  }

  @override
  String get homeHowItWorks => 'How it works';

  @override
  String get homeStepScan => 'Scan the QR code shown by the website or app.';

  @override
  String get homeStepDocument => 'Use a document saved on this phone, or scan your ID.';

  @override
  String get homeStepSelfie => 'Take a quick selfie, then share only what was asked for.';

  @override
  String get consentTitle => 'Request';

  @override
  String consentHeading(String party) {
    return '$party wants to verify your identity';
  }

  @override
  String consentRequestedBy(String org) {
    return 'Requested by $org';
  }

  @override
  String get consentTheyWillReceive => 'They will receive';

  @override
  String get qrScanClose => 'Close';

  @override
  String get qrScanPointCamera => 'Point your camera at the QR code';

  @override
  String get qrScanWhereToFind => 'You’ll find it on the website or app that asked you to verify.';

  @override
  String get qrScanNothingShared => 'Nothing is shared until you agree on the next screen.';

  @override
  String get selfieIntroBody => 'We compare your face with the photo on your document chip. It takes a few seconds.';

  @override
  String get selfieTipOnDevice => 'Processed on your phone. No video is stored.';

  @override
  String get selfieGettingReady => 'Getting ready…';

  @override
  String get selfieStarting => 'Starting…';

  @override
  String get selfieCameraGettingReady => 'Getting the camera ready…';

  @override
  String selfieHoldStillCountdown(int seconds) {
    return 'Hold still · ${seconds}s';
  }

  @override
  String get selfieStoppedTitle => 'Selfie check stopped';

  @override
  String get selfieTryAgain => 'Try again';

  @override
  String get selfieGoBack => 'Go back';

  @override
  String get selfieNoMatchTitle => 'We couldn’t match your face';

  @override
  String get selfieNoMatchMessage => 'Make sure your face is well lit and fills the oval, then try again.';

  @override
  String get selfieCheckingTitle => 'Checking your selfie';

  @override
  String get selfieSettingUpTitle => 'Setting up the selfie check';

  @override
  String get selfieComparing => 'Comparing your face with the photo on your document chip.';

  @override
  String get selfieLoadingModels => 'Loading face models…';

  @override
  String get selfieOpeningCamera => 'Opening camera…';

  @override
  String get dataViewDocumentRead => 'Document read';

  @override
  String get dataViewDrivingLicenceRead => 'Driving licence read';

  @override
  String dataViewChipRead(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'We read your $_temp0 chip.';
  }

  @override
  String get dataViewNotAvailable => 'Not available';

  @override
  String dataViewSubtitle(String documentType, String country) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'ID card',
      'drivingLicence': 'Driving licence',
      'other': 'Document',
    });
    return '$_temp0 · $country';
  }

  @override
  String get dataViewDateOfBirth => 'Date of birth';

  @override
  String get dataViewPlaceOfBirth => 'Place of birth';

  @override
  String get dataViewDocumentNumber => 'Document number';

  @override
  String get dataViewIssuedBy => 'Issued by';

  @override
  String get dataViewValidUntil => 'Valid until';

  @override
  String dataViewCategoryUntil(String date) {
    return 'until $date';
  }

  @override
  String nfcHoldPhoneOn(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Hold your phone on the $_temp0';
  }

  @override
  String nfcGuidanceIntro(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Your $_temp0 has a chip that proves it is genuine. We read it with NFC.';
  }

  @override
  String nfcGuidanceStepLay(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Close the passport and lay it on a flat, non-metal surface.',
      'identityCard': 'Lay the ID card on a flat, non-metal surface.',
      'drivingLicence': 'Lay the driving licence on a flat, non-metal surface.',
      'other': 'Lay the document on a flat, non-metal surface.',
    });
    return '$_temp0';
  }

  @override
  String nfcGuidanceStepPlace(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {'passport': 'cover', 'other': 'card'});
    return 'Place the top half of your phone flat on the $_temp0.';
  }

  @override
  String get nfcGuidanceStepKeepStill =>
      'Keep still until the check turns green. Remove a thick phone case if reading fails.';

  @override
  String get nfcTurnedOff => 'NFC is turned off. Turn it on in your phone\'s settings to continue.';

  @override
  String get nfcCancelReading => 'Cancel reading';

  @override
  String get nfcReadingConnectionLost => 'Connection lost';

  @override
  String get nfcReadingStoppedTitle => 'Reading stopped';

  @override
  String get nfcReadingStoppedSubtitle => 'Start again when you are ready.';

  @override
  String get nfcReadingFailedTitle => 'Reading failed';

  @override
  String nfcReadingFailedSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Check that the $_temp0 lies flat under your phone and try again.';
  }

  @override
  String get nfcReadingSuccessTitle => 'Chip read';

  @override
  String nfcReadingSuccessSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Your $_temp0 chip was read.';
  }

  @override
  String get nfcReadingInProgressTitle => 'Don’t move your phone';

  @override
  String nfcReadingInProgressSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Keep it on the $_temp0 until reading is complete.';
  }

  @override
  String get nfcRingNotRead => 'Not read';

  @override
  String get nfcRingComplete => 'Complete';

  @override
  String get nfcRingReading => 'Reading chip';

  @override
  String get nfcTryAgain => 'Try again';

  @override
  String get nfcChecklistSecureDone => 'Secure connection set up';

  @override
  String get nfcChecklistSecureActive => 'Setting up a secure connection';

  @override
  String get nfcChecklistDetailsDone => 'Personal details read';

  @override
  String get nfcChecklistDetailsActive => 'Reading personal details';

  @override
  String nfcChecklistPhotoDone(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Passport',
      'identityCard': 'ID card',
      'drivingLicence': 'Driving licence',
      'other': 'Document',
    });
    return '$_temp0 photo read';
  }

  @override
  String nfcChecklistPhotoActive(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Reading $_temp0 photo';
  }

  @override
  String get nfcChecklistGenuineDone => 'Chip read securely';

  @override
  String get nfcChecklistGenuineActive => 'Reading the chip securely';

  @override
  String get scanClose => 'Close';

  @override
  String scanSheetTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Place the photo page in the frame',
      'identityCard': 'Place the back of your ID card in the frame',
      'drivingLicence': 'Place the back of your driving licence in the frame',
      'other': 'Place your document in the frame',
    });
    return '$_temp0';
  }

  @override
  String scanSheetTip(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Make sure the two lines of text at the bottom are sharp and not covered by your fingers or glare.',
      'identityCard':
          'Make sure the three lines of text at the bottom are sharp and not covered by your fingers or glare.',
      'drivingLicence': 'Make sure the line of text at the bottom is sharp and not covered by your fingers or glare.',
      'other': 'Make sure the text at the bottom is sharp and not covered by your fingers or glare.',
    });
    return '$_temp0';
  }

  @override
  String get scanHideTips => 'Hide tips';

  @override
  String get scanShowTips => 'Show tips and manual entry';

  @override
  String get scanEnterDetailsManually => 'Enter details manually';

  @override
  String get manualBack => 'Back';

  @override
  String get manualTopBarTitle => 'Enter details';

  @override
  String get manualContinue => 'Continue';

  @override
  String get manualLicenceTitle => 'Type the code from your driving licence';

  @override
  String manualLicenceIntro(int length) {
    return 'It’s the single line of $length characters on the back. It unlocks the chip.';
  }

  @override
  String manualDocumentTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'passport',
      'identityCard': 'ID card',
      'drivingLicence': 'driving licence',
      'other': 'document',
    });
    return 'Enter your $_temp0 details';
  }

  @override
  String manualDocumentIntro(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {'passport': 'photo page', 'other': 'front of the card'});
    return 'Copy them from the $_temp0. They unlock the chip, so they need to match exactly.';
  }

  @override
  String get manualLicenceParseError => 'That code could not be read. Check it against your licence and try again.';

  @override
  String manualDocumentNumber(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Passport number',
      'identityCard': 'Identity card number',
      'drivingLicence': 'Driving licence number',
      'other': 'Document number',
    });
    return '$_temp0';
  }

  @override
  String get manualDocumentNumberHint => 'e.g. AB1234567';

  @override
  String get manualDateOfBirth => 'Date of birth';

  @override
  String get manualExpiryDate => 'Expiry date';

  @override
  String get manualWhereToFind => 'Where to find them';

  @override
  String manualWhereToFindBody(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport':
          'The passport number is at the top right of the photo page. The dates are listed as date of birth and date of expiry.',
      'other': 'The document number and both dates are on the card, next to your photo.',
    });
    return '$_temp0';
  }

  @override
  String get manualLicenceCode => 'Licence code';

  @override
  String get manualLicenceCodePrefix => 'Starts with D1, D2 or DL';

  @override
  String get manualDateNotSet => 'Not set';

  @override
  String get manualDateSelect => 'Select';
}
