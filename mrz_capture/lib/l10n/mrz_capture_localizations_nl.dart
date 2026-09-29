// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mrz_capture_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class MrzCaptureLocalizationsNl extends MrzCaptureLocalizations {
  MrzCaptureLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get mrzContinueToNfc => 'Door naar het uitlezen via NFC';

  @override
  String mrzEnterDetailsLabel(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoortgegevens',
      'identityCard': 'Gegevens identiteitskaart',
      'drivingLicence': 'Gegevens rijbewijs',
      'other': 'Documentgegevens',
    });
    return '$_temp0 invoeren';
  }

  @override
  String get mrzWhereToFind => 'Waar vind je deze gegevens:';

  @override
  String get mrzHelpPassport =>
      '• Paspoortnummer: meestal rechtsboven op de pagina met je foto\n• Geboortedatum: staat er als \"Geboortedatum\" of \"Date of birth\"\n• Vervaldatum: staat er als \"Geldig tot\" of \"Date of expiry\"';

  @override
  String get mrzHelpDrivingLicence =>
      '• De MRZ staat onderaan op de voorkant van je rijbewijs\n• Je kunt hem ook krijgen door de QR-code op de achterkant van je rijbewijs te scannen\n• Het is één regel van precies 30 tekens\n• Hij begint met \"D1\", \"D2\" of \"D3\"';

  @override
  String mrzDocNumberTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoortnummer',
      'identityCard': 'Documentnummer',
      'drivingLicence': 'Rijbewijsnummer',
      'other': 'Documentnummer',
    });
    return '$_temp0';
  }

  @override
  String mrzDocNumberHint(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoortnummer',
      'identityCard': 'documentnummer',
      'drivingLicence': 'rijbewijsnummer',
      'other': 'documentnummer',
    });
    return 'Vul je $_temp0 in';
  }

  @override
  String get mrzDocNumberExample => 'bijv. AB1234567';

  @override
  String mrzDocNumberRequired(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoortnummer',
      'identityCard': 'Documentnummer',
      'drivingLicence': 'Rijbewijsnummer',
      'other': 'Documentnummer',
    });
    return '$_temp0 is verplicht';
  }

  @override
  String mrzDocNumberTooShort(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Paspoortnummer',
      'identityCard': 'Documentnummer',
      'drivingLicence': 'Rijbewijsnummer',
      'other': 'Documentnummer',
    });
    return '$_temp0 moet minstens 6 tekens lang zijn';
  }

  @override
  String get mrzDobTitle => 'Geboortedatum';

  @override
  String get mrzDobHint => 'Kies je geboortedatum';

  @override
  String get mrzTapToSelectDate => 'Tik om een datum te kiezen';

  @override
  String get mrzDobRequired => 'Geboortedatum is verplicht';

  @override
  String get mrzDobInFuture => 'Geboortedatum kan niet in de toekomst liggen';

  @override
  String get mrzExpiryTitle => 'Vervaldatum';

  @override
  String mrzExpiryHint(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Kies de vervaldatum van je $_temp0';
  }

  @override
  String get mrzExpiryRequired => 'Vervaldatum is verplicht';

  @override
  String mrzDocumentExpired(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Je $_temp0 is verlopen';
  }

  @override
  String get mrzExpiryBeforeDob => 'Vervaldatum kan niet vóór de geboortedatum liggen';

  @override
  String get mrzStringTitle => 'MRZ-regel';

  @override
  String get mrzStringHint => 'Vul de MRZ-regel van je rijbewijs in';

  @override
  String get mrzStringRequired => 'MRZ-regel is verplicht';

  @override
  String get mrzStringLength => 'De MRZ moet precies 30 tekens lang zijn';

  @override
  String get mrzStringPrefix => 'De MRZ moet beginnen met D1, D2 of DL';

  @override
  String get mrzCharacterCount => 'Aantal tekens:';

  @override
  String mrzParseFailed(String error) {
    return 'De MRZ kon niet worden gelezen: $error';
  }

  @override
  String mrzHeaderTitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'Vul je paspoortgegevens in',
      'identityCard': 'Vul de gegevens van je identiteitskaart in',
      'drivingLicence': 'Vul je rijbewijsgegevens in',
      'other': 'Vul je documentgegevens in',
    });
    return '$_temp0';
  }

  @override
  String get mrzHeaderTitleMrz => 'Vul de MRZ-regel in';

  @override
  String mrzHeaderSubtitle(String docType) {
    String _temp0 = intl.Intl.selectLogic(docType, {
      'passport': 'paspoort',
      'identityCard': 'identiteitskaart',
      'drivingLicence': 'rijbewijs',
      'other': 'document',
    });
    return 'Vul de gegevens precies zo in als ze op je $_temp0 staan';
  }

  @override
  String get mrzHeaderSubtitleMrz => 'Typ de machineleesbare zone (MRZ) precies zoals die op het document staat';
}
