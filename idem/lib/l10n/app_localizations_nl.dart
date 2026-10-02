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
  String get commonTryAgain => 'Opnieuw proberen';

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get docNewScan => 'Nieuwe scan';

  @override
  String docConnectedBanner(String relyingParty) {
    return 'Verbonden — resultaten gaan naar $relyingParty';
  }

  @override
  String get docPassport => 'Paspoort';

  @override
  String get docPassportSubtitle => 'Gebruik een machineleesbaar paspoort';

  @override
  String get docMostCommon => 'Meest gebruikt';

  @override
  String get docIdentityCard => 'Identiteitskaart';

  @override
  String get docIdentityCardSubtitle => 'Gebruik een machineleesbare identiteitskaart';

  @override
  String get docDrivingLicence => 'Rijbewijs';

  @override
  String get docDrivingLicenceSubtitle =>
      'Gebruik een machineleesbaar rijbewijs. Werkt nu vooral met Nederlandse rijbewijzen.';

  @override
  String get docScanQrTitle => 'QR-code scannen';

  @override
  String get docScanQrSubtitle => 'Scan een QR-code met de camera';

  @override
  String get docAdvancedSettings => 'Geavanceerde instellingen';

  @override
  String get docAdvancedSettingsSubtitle => 'OCR-engine, gezichtsverificatie en meer';

  @override
  String get docVerifyIdentityTitle => 'Verifieer je identiteit';

  @override
  String get docSelectDocumentTypePrompt => 'Kies het type document dat je wilt gebruiken voor de verificatie.';

  @override
  String get docSettingsTitle => 'Instellingen';

  @override
  String get docBack => 'Terug';

  @override
  String get docActiveAuthentication => 'Actieve authenticatie';

  @override
  String get docActiveAuthenticationSubtitle =>
      'Voer actieve authenticatie uit bij het lezen van het document. Een verificatiesessie volgt haar eigen flow.';

  @override
  String get docFaceEngine => 'Engine voor gezichtsverificatie';

  @override
  String get docFaceEngineOpenSource => 'Open source';

  @override
  String get docLivenessDetection => 'Liveness-detectie';

  @override
  String get docLivenessPassive => 'Passief';

  @override
  String get docLivenessActive => 'Actief';

  @override
  String get docOcrEngine => 'OCR-engine';

  @override
  String get docNfcStepStart => 'Lezen starten';

  @override
  String get docNfcStepDetails => 'Gegevens lezen';

  @override
  String get docNfcStepPhoto => 'Foto ophalen';

  @override
  String get docNfcStepAlmostDone => 'Bijna klaar';

  @override
  String get docNfcStepStartSubtitle => 'Verbinden met de chip';

  @override
  String get docNfcStepDetailsSubtitle => 'Persoonsgegevens ophalen';

  @override
  String get docNfcStepPhotoSubtitle => 'Pasfoto van het document ophalen';

  @override
  String get docNfcStepAlmostDoneSubtitle => 'Beveiliging van het document controleren';

  @override
  String get docNfcTipFirst => 'Houd je document achter je telefoon en beweeg het rond tot je telefoon trilt of piept.';

  @override
  String get docNfcTipHoldSteady => 'Houd je telefoon en het document stil - dit kan even duren.';

  @override
  String get docNfcTipStuck =>
      'Het lezen is onderbroken. Til je telefoon langzaam van het document en leg hem terug tot hij weer trilt of piept.';

  @override
  String docReadDocument(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Paspoort',
      'identityCard': 'Identiteitskaart',
      'drivingLicence': 'Rijbewijs',
      'other': 'Document',
    });
    return '$_temp0 lezen';
  }

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
  String get docNfcGuidanceTitle => 'Lees de chip';

  @override
  String docNfcGuidancePlacePhone(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return 'Leg je telefoon op $_temp0';
  }

  @override
  String get docNfcGuidanceTipsTitle => 'Tips voor een beter resultaat:';

  @override
  String docNfcGuidanceTips(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'het paspoort',
      'identityCard': 'de identiteitskaart',
      'drivingLicence': 'het rijbewijs',
      'other': 'het document',
    });
    return '• Houd $_temp0 achter je telefoon, zoals in het voorbeeld\n• Haal je telefoonhoesje eraf als het lezen niet lukt\n• Dit kan 10–30 seconden duren';
  }

  @override
  String docScanDocument(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Paspoort',
      'identityCard': 'Identiteitskaart',
      'drivingLicence': 'Rijbewijs',
      'other': 'Document',
    });
    return '$_temp0 scannen';
  }

  @override
  String get docNfcNotAvailable => 'NFC is niet beschikbaar';

  @override
  String get docPersonalInformation => 'Persoonsgegevens';

  @override
  String get docSurname => 'Achternaam';

  @override
  String get docOtherNames => 'Voornamen';

  @override
  String get docDateOfBirth => 'Geboortedatum';

  @override
  String get docPlaceOfBirth => 'Geboorteplaats';

  @override
  String get docDocumentInformation => 'Documentgegevens';

  @override
  String get docDocumentNumber => 'Documentnummer';

  @override
  String get docIssuingMemberState => 'Lidstaat van afgifte';

  @override
  String get docIssuingAuthority => 'Afgegeven door';

  @override
  String get docDateOfIssue => 'Datum van afgifte';

  @override
  String get docDateOfExpiry => 'Vervaldatum';

  @override
  String get docDrivingLicenceDataTitle => 'Rijbewijsgegevens';

  @override
  String get docUnableToLoadPhoto => 'Foto kan niet worden geladen';

  @override
  String get docCategories => 'Categorieën';

  @override
  String get docCategory => 'Categorie';

  @override
  String get docCategoryDateOfIssue => 'Datum van afgifte';

  @override
  String get docCategoryDateOfExpiry => 'Vervaldatum';

  @override
  String get docWalletDocumentNumber => 'Documentnummer';

  @override
  String get docWalletAdded => 'Toegevoegd';

  @override
  String get docRemoveFromWallet => 'Verwijderen uit wallet';

  @override
  String get docFullName => 'Volledige naam';

  @override
  String get docNationality => 'Nationaliteit';

  @override
  String get docDocument => 'Document';

  @override
  String get docGender => 'Geslacht';

  @override
  String get docExpiryDate => 'Vervaldatum';

  @override
  String get docCountry => 'Land';

  @override
  String get docVersion => 'Versie';

  @override
  String get docOptionalData => 'Optionele gegevens';

  @override
  String get docAvailableDataGroups => 'Beschikbare datagroepen';

  @override
  String docDataGroupsRead(int count, int total) {
    return 'Datagroepen gelezen: $count/$total';
  }

  @override
  String get docActiveAuthenticationAvailable => 'Actieve authenticatie beschikbaar';

  @override
  String get docWebAuthSession => 'Webauthenticatiesessie';

  @override
  String docWebAuthSessionId(String sessionId) {
    return 'Sessie-ID: $sessionId';
  }

  @override
  String docDocumentDataTitle(String documentType) {
    String _temp0 = intl.Intl.selectLogic(documentType, {
      'passport': 'Paspoortgegevens',
      'identityCard': 'Gegevens identiteitskaart',
      'drivingLicence': 'Rijbewijsgegevens',
      'other': 'Documentgegevens',
    });
    return '$_temp0';
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
  String get docIllustrationPassport => 'PASPOORT';

  @override
  String get docIllustrationIssuer => 'Koninkrijk Voorbeeld';

  @override
  String get docIllustrationName => 'Naam: Jan Jansen';

  @override
  String get docIllustrationNationality => 'Nationaliteit: NL';

  @override
  String get docIllustrationDob => 'Geb.: 01-01-1990';

  @override
  String get docIllustrationDrivingLicence => 'RIJBEWIJS';

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
  String get faceStepLabel => 'Gezichtsverificatie';

  @override
  String get faceBack => 'Terug';

  @override
  String get faceSettingUp => 'Gezichtsverificatie voorbereiden';

  @override
  String get faceTakesAMoment => 'Dit duurt maar even';

  @override
  String get faceLoadingOpeningCamera => 'Camera openen';

  @override
  String get faceLoadingModels => 'Gezichtsmodellen laden';

  @override
  String get faceAlmostDone => 'Bijna klaar…';

  @override
  String get faceHoldStill => 'Niet bewegen';

  @override
  String get faceOpeningCamera => 'Camera openen...';

  @override
  String get faceHowItWorks => 'Zo werkt het';

  @override
  String get faceStepCenterFace => 'Plaats je gezicht midden in het ovaal';

  @override
  String get faceStepFollowPrompts => 'Volg de instructies op het scherm';

  @override
  String get faceStart => 'Starten';

  @override
  String get facePreparing => 'Voorbereiden…';

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
  String get faceExtraBadge => 'extra';

  @override
  String get faceVerifyingIdentity => 'Identiteit controleren...';

  @override
  String get faceGoBack => 'Terug';

  @override
  String get faceTryAgain => 'Opnieuw proberen';

  @override
  String get faceIdentityVerified => 'Identiteit geverifieerd';

  @override
  String get faceVerificationFailed => 'Verificatie mislukt';

  @override
  String faceScoreMatch(String threshold) {
    return 'Overeenkomst (≥$threshold%)';
  }

  @override
  String get faceScoreAntiSpoof => 'Anti-spoofing';

  @override
  String get faceNotAvailable => 'n.v.t.';

  @override
  String faceScoreRppg(int count) {
    return 'rPPG ($count metingen)';
  }

  @override
  String faceBpm(String bpm) {
    return '$bpm spm';
  }

  @override
  String get faceScoreLivenessActions => 'Echtheidsacties';

  @override
  String get facePassed => 'geslaagd';

  @override
  String get faceFailed => 'mislukt';

  @override
  String get faceScoreIdentityConsistent => 'Identiteit consistent';

  @override
  String get faceChangedMidSession => 'gezicht veranderde tijdens de sessie';

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
  String get faceIrisIntroTitle => 'Verifiëren met de Iris SDK';

  @override
  String get faceIrisIntroBody =>
      'De Iris SDK opent een eigen camerascherm om te controleren dat er echt iemand voor de camera zit, en vergelijkt dat gezicht daarna met de pasfoto op je document.';

  @override
  String get faceIrisWhatToExpect => 'Wat kun je verwachten';

  @override
  String get faceIrisStep1 => 'Er opent een camerascherm van de Iris SDK';

  @override
  String get faceIrisStep2 => 'Kijk recht in de camera en volg de instructies';

  @override
  String get faceIrisStep3 => 'Blijf stil tot het klaar is — dit duurt maar even';

  @override
  String get faceStartVerification => 'Verificatie starten';

  @override
  String get faceSomethingWentWrong => 'Er ging iets mis';

  @override
  String get faceIrisMatchedSubtitle => 'Je gezicht komt overeen met de documentfoto.';

  @override
  String get faceIrisFailedSubtitle =>
      'Je gezicht komt niet overeen met de documentfoto. Zorg voor goed licht, kijk in de camera en probeer het opnieuw.';

  @override
  String get faceCancelled => 'Geannuleerd';

  @override
  String get faceIrisCancelledSubtitle =>
      'Je hebt de verificatie geannuleerd. Tik hieronder om het opnieuw te proberen.';

  @override
  String get faceRegulaIntroTitle => 'Controleer dat jij het echt bent';

  @override
  String get faceRegulaIntroBody =>
      'Er opent een camerascherm dat controleert of er een levend persoon aanwezig is. De verificatiedienst vergelijkt daarna je gezicht met de foto op de chip van je document.';

  @override
  String get faceRegulaStep1 => 'Er opent een camerascherm';

  @override
  String get faceRegulaStep2 => 'Kijk recht in de camera en volg de aanwijzingen';

  @override
  String get faceRegulaStep3 => 'Blijf stil tot het klaar is — dit duurt maar even';

  @override
  String get faceRegulaOpeningCamera => 'Camera openen…';

  @override
  String get faceRegulaLiveTitle => 'Levendheid bevestigd';

  @override
  String get faceRegulaLiveSubtitle => 'Je gezicht wordt nu vergeleken met de foto op je document.';

  @override
  String get faceRegulaNotLiveSubtitle =>
      'We konden niet bevestigen dat er een levend persoon aanwezig is. Zorg voor goed licht en kijk in de camera, en probeer het opnieuw.';

  @override
  String get faceRegulaCancelledSubtitle =>
      'Je hebt de verificatie geannuleerd. Tik hieronder om het opnieuw te proberen.';

  @override
  String get faceRegulaMatching => 'Je gezicht wordt vergeleken met de foto op je document…';

  @override
  String faceRegulaMatchedSubtitle(String similarity) {
    return 'Je gezicht komt overeen met de foto op je document ($similarity% overeenkomst).';
  }

  @override
  String get faceRegulaNoMatchSubtitle =>
      'Je gezicht kwam niet overeen met de foto op je document. Scan je document opnieuw om het nog eens te proberen.';

  @override
  String get faceRegulaMatchUnavailable => 'Je gezicht kon nu niet worden vergeleken met de foto op je document.';

  @override
  String get faceRegulaScanAgain => 'Document opnieuw scannen';

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
  String faceSubmitSending(String what, String relyingParty) {
    return '$what versturen naar $relyingParty...';
  }

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
  String get proofingConsentTitle => 'Verzoek om identiteitsverificatie';

  @override
  String get proofingConsentIntro =>
      'wil je identiteit verifiëren met een identiteitsdocument. Als je je document scant en de gezichtsverificatie afrondt, wordt het resultaat hieronder naar hen teruggestuurd.';

  @override
  String get proofingConsentRequesting => 'Ze vragen om:';

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
  String get proofingAddToWallet => 'Toevoegen aan wallet';

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
  String proofingPositionDocument(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Houd je $_temp0 voor de camera';
  }

  @override
  String get proofingScanMrzInstructions =>
      'Lijn de machineleesbare zone (MRZ) uit met het kader onderaan het scherm. Houd je telefoon stil tot het scannen klaar is.';

  @override
  String get proofingScanMrzPhotoInstructions =>
      'Leg de hele kant met de machineleesbare zone (MRZ) binnen het kader, op een vlakke ondergrond en in goed licht. Houd je telefoon stil: zodra de MRZ gelezen is, wordt van deze kant ook een foto gemaakt.';

  @override
  String proofingEnterDetailsManually(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Gegevens van je $_temp0 handmatig invoeren';
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
}
