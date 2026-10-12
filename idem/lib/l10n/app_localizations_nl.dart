// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get accessHandedOver => 'Deze verificatiesessie is overgedragen aan een ander apparaat.';

  @override
  String get accessExpired => 'Deze verificatiesessie is verlopen. Start een nieuwe verificatie.';

  @override
  String get accessCancelled => 'Deze verificatiesessie is geannuleerd. Start een nieuwe verificatie.';

  @override
  String get accessUnauthorized => 'Dit apparaat mag deze verificatiesessie niet meer voortzetten.';

  @override
  String get accessComplete => 'Deze verificatiesessie is al afgerond.';

  @override
  String get accessGone => 'Deze verificatiesessie bestaat niet meer. Start een nieuwe verificatie.';

  @override
  String get accessAlreadyClaimed =>
      'Deze verificatiesessie is al geopend op een ander apparaat. Scan de overdrachts-QR-code in de browser om hier verder te gaan.';

  @override
  String get accessHandoverInvalid => 'Deze overdrachts-QR-code is niet geldig. Vraag in de browser om een nieuwe.';

  @override
  String get accessHandoverExpired => 'Deze overdrachts-QR-code is verlopen. Vraag in de browser om een nieuwe.';

  @override
  String get accessHandoverUsed => 'Deze overdrachts-QR-code is al gebruikt. Vraag in de browser om een nieuwe.';

  @override
  String get accessClaimTokenRequired =>
      'Deze QR-code komt van een oudere versie van de verificatiedienst en kan niet meer worden gebruikt. Vraag in de browser om een nieuwe.';

  @override
  String get accessBrowserHandover =>
      'Met deze QR-code verplaats je het browserdeel van de verificatie naar een andere browser. Open hem met de camera van je telefoon, of scan de QR-code die de browser voor de IDEM-app toont.';

  @override
  String get accessUntrustedServer =>
      'Deze QR-code komt niet van een verificatiedienst waarmee deze app werkt, dus hij is niet geopend.';

  @override
  String get sessionOpenFailedTitle => 'Verificatie openen mislukt';

  @override
  String get sessionCompleteTitle => 'Verificatie afgerond';

  @override
  String sessionCompleteMessage(String relyingParty) {
    return 'Je bent klaar. Je verificatie is verstuurd naar $relyingParty.';
  }

  @override
  String get sessionRestartedTitle => 'Verificatie opnieuw gestart';

  @override
  String sessionRestartedMessage(String relyingParty) {
    return '$relyingParty heeft deze verificatie opnieuw gestart, dus alles wat je tot nu toe had gedaan is gewist. Begin opnieuw vanaf het begin.';
  }

  @override
  String get sessionStoppedTitle => 'Verificatie gestopt';

  @override
  String get idDocumentPassport => 'Paspoort';

  @override
  String get idDocumentIdentityCard => 'Identiteitskaart';

  @override
  String get idDocumentDrivingLicence => 'Rijbewijs';

  @override
  String get docScanQrTitle => 'QR-code scannen';

  @override
  String get docSettingsTitle => 'Instellingen';

  @override
  String get docBack => 'Terug';

  @override
  String get docFaceEngineOpenSource => 'Open source';

  @override
  String get docNfcStepStart => 'Lezen starten';

  @override
  String get docNfcTipFirst => 'Houd je document achter je telefoon en beweeg het rond tot je telefoon trilt of piept.';

  @override
  String get docNfcTipHoldSteady => 'Houd je telefoon en het document stil - dit kan even duren.';

  @override
  String get docNfcTipStuck =>
      'Het lezen is onderbroken. Til je telefoon langzaam van het document en leg hem terug tot hij weer trilt of piept.';

  @override
  String docIosNfcHoldClose(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Houd je telefoon tegen $_temp0';
  }

  @override
  String get docIosNfcCancelled => 'Sessie geannuleerd door gebruiker';

  @override
  String get docIosNfcCancelling => 'Annuleren...';

  @override
  String get docIosNfcFailed => 'Verbinding met de chip verloren, probeer het opnieuw.';

  @override
  String get docIosNfcConnecting => 'Verbinden...';

  @override
  String docIosNfcReadingFile(String file) {
    return '$file lezen';
  }

  @override
  String get docIosNfcAuthenticating => 'Authenticeren';

  @override
  String docIosNfcReadingData(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Gegevens van $_temp0 lezen';
  }

  @override
  String get docIosNfcSecurityCheck => 'Beveiligingscontrole uitvoeren...';

  @override
  String get docIosNfcSuccess => 'Gelukt!';

  @override
  String get docIosNfcReconnecting => 'Verbinding verloren. Til je telefoon langzaam op en leg hem weer terug.';

  @override
  String get docCategories => 'Categorieën';

  @override
  String get docNationality => 'Nationaliteit';

  @override
  String get docWebAuthSession => 'Webauthenticatiesessie';

  @override
  String docWebAuthSessionId(String sessionId) {
    return 'Sessie-ID: $sessionId';
  }

  @override
  String get docImageNoData => 'Geen afbeeldingsgegevens beschikbaar.';

  @override
  String get docImageJpegError => 'JPEG-afbeelding kan niet worden weergegeven.';

  @override
  String get docImageConvertingJpeg2000 => 'JPEG2000-afbeelding omzetten...';

  @override
  String get docImageJpeg2000DisplayError => 'Omgezette JPEG2000-afbeelding kan niet worden weergegeven.';

  @override
  String get docImageJpeg2000ConvertFailed => 'JPEG2000-afbeelding omzetten is mislukt.';

  @override
  String get docImageUnsupportedType => 'Onbekend of niet-ondersteund afbeeldingstype.';

  @override
  String get docPhotoStepLabel => 'Documentfoto';

  @override
  String get docPhotoFrontTitle => 'Maak een foto van de voorkant';

  @override
  String get docPhotoFrontInstructionsPassport =>
      'Leg de pagina met je foto en persoonsgegevens binnen het kader. Gebruik een vlakke ondergrond en goed licht, en vermijd schittering.';

  @override
  String get docPhotoFrontInstructionsCard =>
      'Leg de voorkant van je document, de kant met je foto, binnen het kader. Gebruik een vlakke ondergrond en goed licht, en vermijd schittering.';

  @override
  String get docPhotoBackTitle => 'Maak nu een foto van de achterkant';

  @override
  String get docPhotoBackInstructions => 'Draai je document om en leg de achterkant binnen het kader.';

  @override
  String get docPhotoSideFront => 'Voorkant';

  @override
  String get docPhotoSideBack => 'Achterkant';

  @override
  String docPhotoSideProgress(String side, int current, int total) {
    return '$side · $current van $total';
  }

  @override
  String get docPhotoNoBack => 'Mijn document heeft geen achterkant';

  @override
  String get docPhotoTake => 'Foto maken';

  @override
  String get docPhotoHintGlare => 'Reflectie op het document. Kantel het een beetje.';

  @override
  String get docPhotoHintTooDark => 'Te donker. Ga naar een plek met meer licht.';

  @override
  String get docPhotoHintBlurry => 'Nog niet scherp. Houd je telefoon stil.';

  @override
  String get docPhotoReviewTitle => 'Controleer de foto';

  @override
  String get docPhotoReviewMessage =>
      'Zijn alle gegevens scherp en leesbaar, zonder schittering en zonder dat er iets voor zit?';

  @override
  String get docPhotoReviewScannedMessage =>
      'Van deze kant is een foto gemaakt toen de MRZ gelezen werd. Zijn alle gegevens scherp en leesbaar, zonder schittering en zonder dat er iets voor zit?';

  @override
  String get docPhotoRetake => 'Opnieuw';

  @override
  String get docPhotoUse => 'Foto gebruiken';

  @override
  String get docPhotoErrorNoCamera => 'Geen camera beschikbaar';

  @override
  String docPhotoErrorCamera(String error) {
    return 'Kan de camera niet gebruiken: $error';
  }

  @override
  String get faceActionBlink => 'Knipper met je ogen';

  @override
  String get faceActionTurnLeft => 'Draai je hoofd naar links';

  @override
  String get faceActionTurnRight => 'Draai je hoofd naar rechts';

  @override
  String get faceActionMouthOpen => 'Open je mond en houd dat even vast';

  @override
  String get faceActionSmile => 'Glimlach en houd dat even vast';

  @override
  String faceErrorEngineInit(String error) {
    return 'Kan de gezichtsherkenning niet starten: $error';
  }

  @override
  String get faceErrorNoCamera => 'Geen camera beschikbaar';

  @override
  String faceErrorOpenCamera(String error) {
    return 'Kan de camera niet openen: $error';
  }

  @override
  String faceErrorFrameProcessing(String error) {
    return 'Fout bij het verwerken van het camerabeeld: $error';
  }

  @override
  String get faceErrorMissingNfcImage => 'NFC-foto ontbreekt';

  @override
  String faceErrorStartLiveness(String error) {
    return 'Kan de echtheidscontrole niet starten: $error';
  }

  @override
  String get faceErrorUnknown => 'Onbekende fout';

  @override
  String faceTimeoutTakeYourTime(String action) {
    return 'Neem je tijd - $action';
  }

  @override
  String get faceTimeoutPerformAction => 'voer de actie uit';

  @override
  String get faceBack => 'Terug';

  @override
  String get faceHoldStill => 'Niet bewegen';

  @override
  String get faceOpeningCamera => 'Camera openen...';

  @override
  String get faceTipNoFace => 'Plaats je gezicht in het ovaal';

  @override
  String get faceTipCenterFace => 'Beweeg je gezicht in het ovaal';

  @override
  String get faceTipTooFar => 'Kom iets dichter bij de camera';

  @override
  String get faceTipTooClose => 'Ga iets verder van de camera af';

  @override
  String get faceTipLookStraight => 'Kijk recht in de camera';

  @override
  String get faceTipOpenEyes => 'Houd je ogen open';

  @override
  String get faceTipCloseMouth => 'Sluit je mond';

  @override
  String get faceTipRelaxFace => 'Ontspan je gezicht';

  @override
  String get faceTipHoldStill => 'Niet bewegen…';

  @override
  String get faceTipGetReady => 'Maak je klaar…';

  @override
  String get faceTryAgain => 'Opnieuw proberen';

  @override
  String get faceVerificationFailed => 'Verificatie mislukt';

  @override
  String get faceDocumentPhoto => 'Documentfoto';

  @override
  String get faceLiveCapture => 'Live-opname';

  @override
  String get faceContinuing => 'We gaan verder…';

  @override
  String get facePreparingDocumentPhoto => 'Je documentfoto wordt voorbereid…';

  @override
  String get faceIrisReadPortraitError => 'Kan de pasfoto voor de Iris SDK niet lezen.';

  @override
  String get faceOpeningIrisCamera => 'De Iris-camera wordt geopend…';

  @override
  String get faceIrisUnavailable => 'De Iris SDK is niet beschikbaar op dit apparaat.';

  @override
  String get faceIrisNoActivity => 'Kan de camera niet openen. Probeer het opnieuw.';

  @override
  String get faceIrisAlreadyRunning => 'Er loopt al een verificatie.';

  @override
  String faceIrisFailedCode(String code) {
    return 'Verificatie mislukt ($code).';
  }

  @override
  String faceIrisFailedError(String error) {
    return 'Verificatie mislukt: $error';
  }

  @override
  String get faceIrisIntroBody =>
      'De Iris SDK opent een eigen camerascherm om te controleren dat er echt iemand voor de camera zit, en vergelijkt dat gezicht daarna met de pasfoto op je document.';

  @override
  String get faceIrisStep2 => 'Kijk recht in de camera en volg de instructies';

  @override
  String get faceSelfieIntroTitle => 'Maak even een selfie';

  @override
  String get faceTipEvenLight => 'Zoek een plek met gelijkmatig licht';

  @override
  String get faceTipRemoveAccessories => 'Zet je zonnebril en pet af';

  @override
  String get faceStartSelfieCheck => 'Selfiecheck starten';

  @override
  String get faceSomethingWentWrong => 'Er ging iets mis';

  @override
  String get faceIrisFailedSubtitle =>
      'Je gezicht komt niet overeen met de documentfoto. Zorg voor goed licht, kijk in de camera en probeer het opnieuw.';

  @override
  String get faceCancelled => 'Geannuleerd';

  @override
  String get faceIrisCancelledSubtitle =>
      'Je hebt de verificatie geannuleerd. Tik hieronder om het opnieuw te proberen.';

  @override
  String get faceRegulaIntroBody =>
      'Er opent een camerascherm dat controleert of er een levend persoon aanwezig is. De verificatiedienst vergelijkt daarna je gezicht met de foto op de chip van je document.';

  @override
  String get faceRegulaStep2 => 'Kijk recht in de camera en volg de aanwijzingen';

  @override
  String get faceRegulaOpeningCamera => 'Camera openen…';

  @override
  String get faceRegulaNotLiveSubtitle =>
      'We konden niet bevestigen dat er een levend persoon aanwezig is. Zorg voor goed licht en kijk in de camera, en probeer het opnieuw.';

  @override
  String get faceRegulaCancelledSubtitle =>
      'Je hebt de verificatie geannuleerd. Tik hieronder om het opnieuw te proberen.';

  @override
  String faceRegulaFailedError(String error) {
    return 'Verificatie mislukt: $error';
  }

  @override
  String get faceSessionUnreachable => 'Kan de verificatiedienst niet bereiken. Opnieuw proberen...';

  @override
  String get faceSessionChecking => 'Je verificatiesessie wordt gecontroleerd...';

  @override
  String get faceStopVerification => 'Verificatie stoppen';

  @override
  String get faceSubmitCouldNotSend => 'Versturen mislukt';

  @override
  String faceSubmitFailed(String what, String relyingParty, String error) {
    return 'Versturen van $what naar $relyingParty is mislukt:\n\n$error';
  }

  @override
  String get faceCancel => 'Annuleren';

  @override
  String get faceRetry => 'Opnieuw proberen';

  @override
  String get proofingConsentExpired => 'Dit verzoek is verlopen.';

  @override
  String proofingConsentExpiresIn(String duration) {
    return 'Dit verzoek verloopt over $duration.';
  }

  @override
  String get proofingDurationLessThanMinute => 'minder dan een minuut';

  @override
  String proofingDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minuten', one: '1 minuut');
    return '$_temp0';
  }

  @override
  String proofingDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count uur', one: '1 uur');
    return '$_temp0';
  }

  @override
  String get proofingContinue => 'Doorgaan';

  @override
  String get proofingDecline => 'Weigeren';

  @override
  String get proofingAttributeDocumentIdentity =>
      'Documentidentiteit (naam, geboortedatum, documentnummer, vervaldatum)';

  @override
  String get proofingAttributeAdditionalDetails => 'Aanvullende persoonsgegevens (persoonsnummer, geboorteplaats)';

  @override
  String get proofingAttributeFacePhoto => 'Je pasfoto uit de chip van het document';

  @override
  String get proofingAttributeChipChecks => 'Controles op de echtheid van het document';

  @override
  String get proofingAttributeBiometrics => 'Resultaat van de gezichtsverificatie';

  @override
  String get proofingAttributeEverything => 'Alles wat de app uit je document leest';

  @override
  String proofingSentTo(String relyingParty) {
    return 'Verstuurd naar $relyingParty';
  }

  @override
  String proofingSentBrowserFace(String relyingParty) {
    return 'Je documentidentiteit is naar $relyingParty gestuurd. Rond de gezichtsverificatie af in het browsertabblad waar je deze sessie bent begonnen.';
  }

  @override
  String proofingSentEverything(String relyingParty) {
    return 'Alles wat deze verificatie van dit apparaat nodig had, is naar $relyingParty gestuurd.';
  }

  @override
  String get proofingDone => 'Klaar';

  @override
  String get proofingVerifiedTitle => 'Document uitgelezen';

  @override
  String proofingShareBody(String relyingParty) {
    return 'Je documentgegevens zijn naar $relyingParty gestuurd. Rond af om de verificatie te voltooien.';
  }

  @override
  String proofingShareWith(String relyingParty) {
    return 'Afronden met $relyingParty';
  }

  @override
  String get proofingSharing => 'Afronden…';

  @override
  String proofingStepSending(String relyingParty) {
    return 'Versturen naar $relyingParty…';
  }

  @override
  String get proofingDialogOk => 'OK';

  @override
  String proofingScanDocument(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoort scannen',
      'identityCard': 'Identiteitskaart scannen',
      'drivingLicence': 'Rijbewijs scannen',
      'other': 'Document scannen',
    });
    return '$_temp0';
  }

  @override
  String get proofingContinueInBrowserTitle => 'Verder in de browser';

  @override
  String get proofingContinueInBrowserFace =>
      'Rond de gezichtsverificatie af in de browser waar je deze sessie bent begonnen.';

  @override
  String get proofingContinueInBrowserNextStep =>
      'De volgende stap van deze verificatie gaat verder in de browser waar je bent begonnen.';

  @override
  String get proofingNothingLeftTitle => 'Niets meer te doen';

  @override
  String get proofingSessionAlreadyComplete => 'Deze verificatiesessie is al afgerond.';

  @override
  String get proofingNotFinishedTitle => 'Nog niet klaar';

  @override
  String proofingNotFinishedMessage(String relyingParty) {
    return '$relyingParty heeft nog een stap nodig voordat deze verificatie verstuurd kan worden.';
  }

  @override
  String get proofingFaceIncompleteTitle => 'Gezichtsverificatie niet afgerond';

  @override
  String get proofingFaceIncompleteMessage =>
      'Er is geen selfie gemaakt, dus er is niets om te versturen. Probeer het opnieuw.';

  @override
  String get proofingWhatVerification => 'je verificatie';

  @override
  String get proofingWhatDocumentDetails => 'je documentgegevens';

  @override
  String get proofingWhatDocumentIdentity => 'je documentidentiteit';

  @override
  String get proofingWhatDocumentPhoto => 'je documentfoto';

  @override
  String get proofingWhatFaceVerification => 'je gezichtsverificatie';

  @override
  String get proofingNotAVerificationLink => 'Dit is geen verificatielink.';

  @override
  String get proofingSessionNoAttributes => 'Deze sessie geeft niet aan welke gegevens nodig zijn';

  @override
  String proofingConnectFailed(String error) {
    return 'Kan geen verbinding maken met de aanvragende partij: $error';
  }

  @override
  String proofingQrScanned(String value) {
    return 'QR-code gescand: $value';
  }

  @override
  String proofingRequestTooManyAttempts(String what) {
    return '$what mislukt: te veel pogingen, wacht even en probeer het opnieuw';
  }

  @override
  String get proofingRequestTimedOut =>
      'De server reageerde niet op tijd - controleer je internetverbinding en probeer het opnieuw';

  @override
  String proofingRequestFailed(String what, String details) {
    return '$what mislukt: $details';
  }

  @override
  String get proofingRequestClaim => 'Sessie overnemen';

  @override
  String get proofingRequestFetch => 'Sessie ophalen';

  @override
  String get proofingRequestWatch => 'Sessie volgen';

  @override
  String get proofingRequestDeviceState => 'Apparaatstatus doorgeven';

  @override
  String proofingRequestStepStarted(String step) {
    return 'Stap $step als gestart markeren';
  }

  @override
  String get proofingRequestDocumentStep => 'Documentstap versturen';

  @override
  String get proofingRequestNfcStep => 'NFC-stap versturen';

  @override
  String get proofingRequestDocumentPhotoStep => 'Documentfotostap versturen';

  @override
  String get proofingRequestFaceStep => 'Gezichtsverificatiestap versturen';

  @override
  String get proofingRequestSubmitVerification => 'Verificatie versturen';

  @override
  String guidedStepOf(int step, int total) {
    return 'Stap $step van $total';
  }

  @override
  String get guidedSaveForNextTime => 'Bewaren voor de volgende keer';

  @override
  String get guidedSaveForNextTimeSubtitle =>
      'Bewaar dit document op deze telefoon tot de app sluit, zodat je het niet opnieuw hoeft te scannen.';

  @override
  String get settingsYourDocuments => 'Je documenten';

  @override
  String get settingsSavedDocuments => 'Bewaarde documenten';

  @override
  String settingsSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count op deze telefoon',
      zero: 'Geen op deze telefoon',
    );
    return '$_temp0';
  }

  @override
  String get settingsChipReading => 'Chip lezen';

  @override
  String get settingsChipCheck => 'Chipcontrole';

  @override
  String get settingsChipCheckSubtitle => 'Laat de chip bewijzen dat hij geen kopie is (actieve authenticatie)';

  @override
  String get settingsSelfieCheck => 'Selfiecheck';

  @override
  String get settingsFaceEngine => 'Gezichtsherkenning';

  @override
  String get settingsFaceEngineOnDevice => 'Open source, op deze telefoon';

  @override
  String get settingsLivenessCheck => 'Echtheidscontrole';

  @override
  String get settingsLivenessPassive => 'Passief: blijf gewoon stil';

  @override
  String get settingsLivenessActive => 'Actief: volg de aanwijzingen';

  @override
  String get settingsDocumentScanning => 'Documenten scannen';

  @override
  String get settingsTextRecognition => 'Tekstherkenning';

  @override
  String settingsVersion(String version) {
    return 'Versie $version';
  }

  @override
  String savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documenten op deze telefoon',
      one: '1 document op deze telefoon',
      zero: 'Geen documenten op deze telefoon',
    );
    return '$_temp0';
  }

  @override
  String get savedEmptyBody =>
      'Nadat je een document hebt gedeeld, kun je het hier bewaren tot de app sluit, zodat je het niet opnieuw hoeft te scannen.';

  @override
  String get savedBody =>
      'Als je een QR-code scant, kun je een van deze kiezen in plaats van je ID opnieuw te scannen. Ze worden alleen gedeeld als je akkoord gaat, en verwijderd als de app sluit.';

  @override
  String savedValidUntil(String date) {
    return 'Geldig tot $date';
  }

  @override
  String get savedAddedToday => 'vandaag toegevoegd';

  @override
  String savedAddedOn(String date) {
    return 'toegevoegd op $date';
  }

  @override
  String get savedRemove => 'Verwijderen van deze telefoon';

  @override
  String get chooseTitle => 'Document kiezen';

  @override
  String get chooseHeading => 'Welk document wil je gebruiken?';

  @override
  String chooseIntroEmpty(String relyingParty) {
    return '$relyingParty vraagt je om je identiteit te verifiëren. Voeg het document toe dat je wilt gebruiken.';
  }

  @override
  String chooseIntroSaved(String relyingParty) {
    return '$relyingParty vraagt je om je identiteit te verifiëren. Gebruik een bewaard document of voeg een nieuw document toe.';
  }

  @override
  String get chooseSavedOnPhone => 'Bewaard op deze telefoon';

  @override
  String get chooseSelfieHint => 'Je maakt even een selfie om te bevestigen dat het document van jou is.';

  @override
  String get chooseAddDocument => 'Document toevoegen';

  @override
  String get chooseAddNewDocument => 'Of voeg een nieuw document toe';

  @override
  String chooseContinueWith(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Doorgaan met $_temp0';
  }

  @override
  String chooseValidUntil(String date) {
    return 'geldig tot $date';
  }

  @override
  String get homeEyebrow => 'IDENTITEITSVERIFICATIE';

  @override
  String get homeTitle => 'Verifieer je identiteit met een QR-code';

  @override
  String get homeBody => 'Als een dienst wil weten wie je bent, toont die een QR-code. Scan hem hier om te beginnen.';

  @override
  String homeConnectedBody(String relyingParty) {
    return 'Je hebt een verzoek van $relyingParty geaccepteerd. Ga verder waar je gebleven was.';
  }

  @override
  String homeContinueWith(String relyingParty) {
    return 'Verder met $relyingParty';
  }

  @override
  String get homeHowItWorks => 'Zo werkt het';

  @override
  String get homeStepScan => 'Scan de QR-code die de website of app toont.';

  @override
  String get homeStepDocument => 'Gebruik een document dat op deze telefoon bewaard is, of scan je ID.';

  @override
  String get homeStepSelfie => 'Maak even een selfie en deel daarna alleen wat er gevraagd is.';

  @override
  String get consentTitle => 'Verzoek';

  @override
  String consentHeading(String party) {
    return '$party wil je identiteit verifiëren';
  }

  @override
  String consentRequestedBy(String org) {
    return 'Aangevraagd door $org';
  }

  @override
  String get consentTheyWillReceive => 'Zij ontvangen';

  @override
  String get qrScanClose => 'Sluiten';

  @override
  String get qrScanPointCamera => 'Richt je camera op de QR-code';

  @override
  String get qrScanWhereToFind => 'Je vindt hem op de website of in de app die je vroeg om te verifiëren.';

  @override
  String get qrScanNothingShared => 'Er wordt niets gedeeld totdat je op het volgende scherm akkoord gaat.';

  @override
  String get selfieIntroBody =>
      'We vergelijken je gezicht met de foto op de chip van je document. Dat duurt een paar seconden.';

  @override
  String get selfieTipOnDevice => 'Verwerkt op je telefoon. Er wordt geen video opgeslagen.';

  @override
  String get selfieGettingReady => 'Even voorbereiden…';

  @override
  String get selfieStarting => 'Starten…';

  @override
  String get selfieCameraGettingReady => 'Camera wordt klaargezet…';

  @override
  String selfieHoldStillCountdown(int seconds) {
    return 'Niet bewegen · ${seconds}s';
  }

  @override
  String get selfieStoppedTitle => 'Selfiecheck gestopt';

  @override
  String get selfieTryAgain => 'Opnieuw proberen';

  @override
  String get selfieGoBack => 'Terug';

  @override
  String get selfieNoMatchTitle => 'Je gezicht kwam niet overeen';

  @override
  String get selfieNoMatchMessage => 'Zorg dat je gezicht goed verlicht is en het ovaal vult, en probeer het opnieuw.';

  @override
  String get selfieCheckingTitle => 'Je selfie wordt gecontroleerd';

  @override
  String get selfieSettingUpTitle => 'Selfiecheck wordt voorbereid';

  @override
  String get selfieComparing => 'We vergelijken je gezicht met de foto op de chip van je document.';

  @override
  String get selfieLoadingModels => 'Gezichtsmodellen laden…';

  @override
  String get selfieOpeningCamera => 'Camera openen…';

  @override
  String get dataViewDocumentRead => 'Document gelezen';

  @override
  String get dataViewDrivingLicenceRead => 'Rijbewijs gelezen';

  @override
  String dataViewChipRead(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'We hebben de chip van je $_temp0 gelezen.';
  }

  @override
  String get dataViewNotAvailable => 'Niet beschikbaar';

  @override
  String dataViewSubtitle(String documentType, String country) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Paspoort',
      'identityCard': 'Identiteitskaart',
      'drivingLicence': 'Rijbewijs',
      'other': 'Document',
    });
    return '$_temp0 · $country';
  }

  @override
  String get dataViewDateOfBirth => 'Geboortedatum';

  @override
  String get dataViewPlaceOfBirth => 'Geboorteplaats';

  @override
  String get dataViewDocumentNumber => 'Documentnummer';

  @override
  String get dataViewIssuedBy => 'Afgegeven door';

  @override
  String get dataViewValidUntil => 'Geldig tot';

  @override
  String dataViewCategoryUntil(String date) {
    return 'tot $date';
  }

  @override
  String nfcHoldPhoneOn(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Houd je telefoon op $_temp0';
  }

  @override
  String nfcGuidanceIntro(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'je paspoort',
      'identityCard': 'je identiteitskaart',
      'drivingLicence': 'je rijbewijs',
      'other': 'je document',
    });
    return 'In $_temp0 zit een chip die bewijst dat het document echt is. Die lezen we uit met NFC.';
  }

  @override
  String nfcGuidanceStepLay(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Sluit het paspoort en leg het op een vlakke, niet-metalen ondergrond.',
      'identityCard': 'Leg de identiteitskaart op een vlakke, niet-metalen ondergrond.',
      'drivingLicence': 'Leg het rijbewijs op een vlakke, niet-metalen ondergrond.',
      'other': 'Leg het document op een vlakke, niet-metalen ondergrond.',
    });
    return '$_temp0';
  }

  @override
  String nfcGuidanceStepPlace(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {'passport': 'de kaft', 'other': 'de kaart'});
    return 'Leg de bovenkant van je telefoon plat op $_temp0.';
  }

  @override
  String get nfcGuidanceStepKeepStill =>
      'Houd alles stil tot het vinkje groen wordt. Haal een dik telefoonhoesje eraf als het lezen niet lukt.';

  @override
  String get nfcTurnedOff => 'NFC staat uit. Zet het aan in de instellingen van je telefoon om verder te gaan.';

  @override
  String get nfcCancelReading => 'Lezen annuleren';

  @override
  String get nfcReadingConnectionLost => 'Verbinding verbroken';

  @override
  String get nfcReadingStoppedTitle => 'Lezen gestopt';

  @override
  String get nfcReadingStoppedSubtitle => 'Begin opnieuw wanneer je er klaar voor bent.';

  @override
  String get nfcReadingFailedTitle => 'Lezen mislukt';

  @override
  String nfcReadingFailedSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Controleer of $_temp0 plat onder je telefoon ligt en probeer het opnieuw.';
  }

  @override
  String get nfcReadingSuccessTitle => 'Chip gelezen';

  @override
  String nfcReadingSuccessSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'je paspoort',
      'identityCard': 'je identiteitskaart',
      'drivingLicence': 'je rijbewijs',
      'other': 'je document',
    });
    return 'De chip van $_temp0 is uitgelezen.';
  }

  @override
  String get nfcReadingInProgressTitle => 'Beweeg je telefoon niet';

  @override
  String nfcReadingInProgressSubtitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Houd hem op $_temp0 tot het lezen klaar is.';
  }

  @override
  String get nfcRingNotRead => 'Niet gelezen';

  @override
  String get nfcRingComplete => 'Klaar';

  @override
  String get nfcRingReading => 'Chip lezen';

  @override
  String get nfcTryAgain => 'Opnieuw proberen';

  @override
  String get nfcChecklistSecureDone => 'Beveiligde verbinding opgezet';

  @override
  String get nfcChecklistSecureActive => 'Beveiligde verbinding opzetten';

  @override
  String get nfcChecklistDetailsDone => 'Persoonsgegevens gelezen';

  @override
  String get nfcChecklistDetailsActive => 'Persoonsgegevens lezen';

  @override
  String nfcChecklistPhotoDone(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Pasfoto van $_temp0 gelezen';
  }

  @override
  String nfcChecklistPhotoActive(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Pasfoto van $_temp0 lezen';
  }

  @override
  String get nfcChecklistGenuineDone => 'Chip veilig uitgelezen';

  @override
  String get nfcChecklistGenuineActive => 'Chip veilig uitlezen';

  @override
  String get scanClose => 'Sluiten';

  @override
  String scanSheetTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Leg de fotopagina in het kader',
      'identityCard': 'Leg de achterkant van je identiteitskaart in het kader',
      'drivingLicence': 'Leg de achterkant van je rijbewijs in het kader',
      'other': 'Leg je document in het kader',
    });
    return '$_temp0';
  }

  @override
  String scanSheetTip(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport':
          'Zorg dat de twee regels tekst onderaan scherp zijn en niet bedekt worden door je vingers of schittering.',
      'identityCard':
          'Zorg dat de drie regels tekst onderaan scherp zijn en niet bedekt worden door je vingers of schittering.',
      'drivingLicence':
          'Zorg dat de regel tekst onderaan scherp is en niet bedekt wordt door je vingers of schittering.',
      'other': 'Zorg dat de tekst onderaan scherp is en niet bedekt wordt door je vingers of schittering.',
    });
    return '$_temp0';
  }

  @override
  String get scanHideTips => 'Tips verbergen';

  @override
  String get scanShowTips => 'Tips en handmatig invoeren tonen';

  @override
  String get scanEnterDetailsManually => 'Gegevens handmatig invoeren';

  @override
  String get manualBack => 'Terug';

  @override
  String get manualTopBarTitle => 'Gegevens invoeren';

  @override
  String get manualContinue => 'Doorgaan';

  @override
  String get manualLicenceTitle => 'Typ de code van je rijbewijs over';

  @override
  String manualLicenceIntro(int length) {
    return 'Het is de enkele regel van $length tekens op de achterkant. Daarmee wordt de chip ontgrendeld.';
  }

  @override
  String manualDocumentTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Vul de gegevens van je $_temp0 in';
  }

  @override
  String manualDocumentIntro(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {'passport': 'de fotopagina', 'other': 'de voorkant van de kaart'});
    return 'Neem ze over van $_temp0. Ze ontgrendelen de chip, dus ze moeten precies kloppen.';
  }

  @override
  String get manualLicenceParseError =>
      'Die code kon niet worden gelezen. Controleer hem met je rijbewijs en probeer het opnieuw.';

  @override
  String manualDocumentNumber(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoortnummer',
      'identityCard': 'Identiteitskaartnummer',
      'drivingLicence': 'Rijbewijsnummer',
      'other': 'Documentnummer',
    });
    return '$_temp0';
  }

  @override
  String get manualDocumentNumberHint => 'bijv. AB1234567';

  @override
  String get manualDateOfBirth => 'Geboortedatum';

  @override
  String get manualExpiryDate => 'Vervaldatum';

  @override
  String get manualWhereToFind => 'Waar vind je ze';

  @override
  String manualWhereToFindBody(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport':
          'Het paspoortnummer staat rechtsboven op de fotopagina. De datums staan vermeld als geboortedatum en vervaldatum.',
      'other': 'Het documentnummer en beide datums staan op de kaart, naast je foto.',
    });
    return '$_temp0';
  }

  @override
  String get manualLicenceCode => 'Rijbewijscode';

  @override
  String get manualLicenceCodePrefix => 'Begint met D1, D2 of DL';

  @override
  String get manualDateNotSet => 'Niet ingesteld';

  @override
  String get manualDateSelect => 'Kiezen';
}
