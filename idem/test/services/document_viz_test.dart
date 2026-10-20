import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/document_viz.dart';
import 'package:vcmrtd/vcmrtd.dart';

const _cardFront = [
  'KONINKRIJK DER NEDERLANDEN',
  'IDENTITEITSKAART',
  'Naam / Surname',
  'Eriksson',
  'Documentnummer',
  'D23I45890',
  'Geboortedatum / Date of birth',
  '12 AUG/AUG 1974',
  'Geldig tot / Date of expiry',
  '15.04.2012',
];

const _cardBack = [
  'Burgerservicenummer',
  '999999990',
  'I<UTOD231458907<<<<<<<<<<<<<<<',
  '7408122F1204159UTO<<<<<<<<<<<6',
  'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
];

/// As ML Kit read [_cardBack] off a rendered card.
const _cardBackAsRead = [
  'Burgerservicenummer / Personal no.',
  '999999990',
  'Lengte/Height 1,75 m',
  'I<UTOD231458907<<',
  '<<',
  '<<6',
  '7408122F1204159UT0<<',
  'ERIKSSON<<ANNA<MARIA<<< <<<<',
];

/// As ML Kit read [_otherCardBack] off a rendered card.
const _otherCardBackAsRead = [
  'Burgerservicenummer / Personal no.',
  '111222333',
  'I<UTOXR98765434<',
  '8503013F3001019UT0<<',
  'JANSEN<<EVA<<<',
  '<<',
  '<<2',
  '<<<<',
];

const _otherCardBack = [
  'I<UTOXR98765434<<<<<<<<<<<<<<<',
  '8503013F3001019UTO<<<<<<<<<<<2',
  'JANSEN<<EVA<<<<<<<<<<<<<<<<<<<',
];

void main() {
  group('SideText.read', () {
    test('finds the dates a card prints, by month name or number', () {
      final side = SideText.read(_cardFront);

      expect(side.dates, {DateTime(1974, 8, 12), DateTime(2012, 4, 15)});
      expect(side.looksLikeDocument, isTrue);
    });

    test('takes the document number from the MRZ', () {
      final side = SideText.read(_cardBack);

      expect(side.mrz?.documentNumber, 'D23145890');
      expect(side.carries('D23145890'), isTrue);
      expect(side.looksLikeDocument, isTrue);
    });

    test('matches a number read with a letter for a digit', () {
      expect(SideText.read(_cardFront).carries('D23145890'), isTrue);
    });

    test('skips a day the month does not have', () {
      expect(SideText.read(['31.02.1990']).dates, isEmpty);
    });

    test('knows the document by its printed title', () {
      final side = SideText.read(['Rijbewijs', 'Koninkrijk der Nederlanden']);

      expect(side.title, DocumentType.drivingLicence);
      expect(side.looksLikeDocument, isTrue);
    });

    test('knows the document by its MRZ before its title', () {
      expect(SideText.read(['PASPOORT', ..._cardBack]).documentType, DocumentType.identityCard);
    });

    test('is not a document without an MRZ, a title or dates', () {
      expect(SideText.read(['Supermarkt', 'Bonuskaart 1234567']).looksLikeDocument, isFalse);
    });
  });

  group('dates of other countries', () {
    final birth = DateTime(1974, 8, 12);

    for (final (country, line) in [
      ('Germany', 'Geburtsdatum 12.08.1974'),
      ('Germany, a month name', '12. AUG. 1974'),
      ('Spain', '12 AGO 1974'),
      ('Italy, two-digit year', '12 AGO 74'),
      ('Portugal', '12 AGO/AUG 1974'),
      ('Poland', '12 SIE/AUG 1974'),
      ('Hungary, year first', '1974.08.12.'),
      ('Sweden, year first', '1974-08-12'),
      ('United States, month first', '08/12/1974'),
      ('a licence, two-digit year', '3. 12.08.74 AMSTERDAM'),
    ]) {
      test(country, () => expect(SideText.read([line]).vizDates, contains(birth)));
    }

    test('French months with their accents, or without', () {
      expect(SideText.read(['12 FÉVR. 1974']).vizDates, contains(DateTime(1974, 2, 12)));
      expect(SideText.read(['12 FEVR 1974']).vizDates, contains(DateTime(1974, 2, 12)));
      expect(SideText.read(['12 JUIL 1974']).vizDates, contains(DateTime(1974, 7, 12)));
    });

    test('not a time or a height', () {
      expect(SideText.read(['16:41', '1,75 m']).vizDates, isEmpty);
    });
  });

  group('titles of other countries', () {
    for (final (title, type) in [
      ('DOWÓD OSOBISTY', DocumentType.identityCard),
      ('CARTÃO DE CIDADÃO', DocumentType.identityCard),
      ('DOCUMENTO NACIONAL DE IDENTIDAD', DocumentType.identityCard),
      ('RESIDENCE PERMIT', DocumentType.identityCard),
      ('PASAPORTE', DocumentType.passport),
      ('CESTOVNÍ PAS', DocumentType.passport),
      ('FÜHRERSCHEIN', DocumentType.drivingLicence),
      ('PRAWO JAZDY', DocumentType.drivingLicence),
      ('DRIVER LICENSE', DocumentType.drivingLicence),
    ]) {
      test(title, () => expect(SideText.read([title]).title, type));
    }
  });

  group('driving licences without an MRZ', () {
    const euFront = [
      'FÜHRERSCHEIN',
      '1. MUSTERMANN',
      '2. ERIKA',
      '3. 12.08.1974 BERLIN',
      '4a. 19.01.2013 4c. Landratsamt',
      '4b.',
      '18.01.2028',
      '5. B072RRE2I55',
    ];
    const euBack = ['9.', '10.', '11.', 'AM 19.01.2013 18.01.2028', 'A1', 'B 19.01.2013 18.01.2028', 'BE', 'C1', 'CE'];

    test('reads the numbered fields of an EU licence, in any language', () {
      final licence = SideText.read(euFront).licence;

      expect(licence?.number, 'B072RRE2I55');
      expect(licence?.dateOfBirth, DateTime(1974, 8, 12));
      expect(licence?.dateOfExpiry, DateTime(2028, 1, 18));
      expect(licence?.labels, greaterThanOrEqualTo(2));
    });

    test('knows a licence by its numbered fields and its back by its categories', () {
      expect(SideText.read(euFront.skip(1).toList()).documentType, DocumentType.drivingLicence);
      expect(SideText.read(euBack).documentType, DocumentType.drivingLicence);
    });

    test("ties an EU licence's front to the back listing its categories until its expiry", () {
      expect(checkSides(SideText.read(euFront), SideText.read(euBack)).match, SidesMatch.same);
    });

    test("ties a United States licence's front to its back's barcode", () {
      const barcode = '@\n\x1e\rANSI 636014090102DL00410278ZC03190024DLDAQD1234562\nDBB08121974\nDBA08122030\n';
      final check = checkSides(
        SideText.read(['CALIFORNIA', 'DRIVER LICENSE', '4d DLN D1234562', '3 DOB 08/12/1974', '4b EXP 08/12/2030']),
        SideText.read(const [], barcodes: const [barcode]),
      );

      expect(check.match, SidesMatch.same);
      expect(check.backLooksLikeDocument, isTrue);
    });
  });

  // As ML Kit read Wikimedia Commons specimens (fictitious data) on an emulator.
  group('specimens of other countries', () {
    test('Norway: a two-digit year read twice counts as one date, and a slash read as I or 1', () {
      final front = SideText.read([
        'IDENTITY CARD',
        'Date of birnh',
        '23 APR IAPR 56',
        'Document No.',
        'GDCO00001',
        'dohkkenbeaivi/ Date of expiry',
        '11 JUN 1JUN 26',
      ]);
      final back = SideText.read([
        'CANORGDCO000014230456<12345<<<',
        '5604230M2 606118NOR<<<<<<<<<<<7',
        'OESTENBYEN<<AASAMUND<SPECIMEN<',
      ]);

      expect(front.printedDates, 2);
      expect(checkSides(front, back).match, SidesMatch.same);
    });

    test('Greece: dates whose separator text recognition lost', () {
      final front = SideText.read([
        'IDENTITY CARD',
        'Date of Birth',
        '1505 1975',
        '19 122019',
        'OA12345678',
        '19 122029',
      ]);
      final back = SideText.read([
        'IDGRC A123456784<<<<<<<<<<<<<<',
        '7505157 M2912198GRC<<<<<<<<<<<2',
        'ELLINAS<<GEORGIOS<<<<<<<<<<<<<',
      ]);

      expect(checkSides(front, back).match, SidesMatch.same);
    });

    test('Iceland: an MRZ year of birth in the last century but one', () {
      final front = SideText.read(['ICELAND ID CARD', '12 DES/DEC 1912', '01 MARIMAR 2034']);

      expect(front.shows(DateTime(2012, 12, 12)), isTrue);
      expect(front.shows(DateTime(2034, 3, 1)), isTrue);
    });

    test('Liechtenstein: licence fields sharing a line, and a back known by its numbered fields', () {
      final front = SideText.read(['Führerschein', '5. 005642150012', '4a. 01.03.2011 4b. 01.01.2050 4c. FL']);
      final back = SideText.read([
        '9. Kategorie',
        '10. Erteilungsdatum je Kategorie',
        '11, Ablaufdatum je Kategorie',
        '12. Zusatzangaben',
        '01.01.2010 01.01.2050',
      ]);

      expect(front.licence?.dateOfExpiry, DateTime(2050, 1, 1));
      expect(back.documentType, DocumentType.drivingLicence);
      expect(checkSides(front, back).match, SidesMatch.same);
    });

    test("Estonia: a licence's MRZ on its front does not stand for its number", () {
      final front = SideText.read([
        'JUHILUBA',
        '3. 03.07.1993 EE',
        '4a. 03.01.2013',
        '4b.02.01.2023',
        '5. ET999901',
        '4d. 49307039909',
        'D<ESTET999901<49307039909<<<<9',
      ]);
      final back = SideText.read(['9.', 'AM', 'A1', 'B', 'BE', '10.', '03.01.13', '11.', '02.01.23', '12.']);

      expect(checkSides(front, back).match, SidesMatch.same);
    });

    test("the Netherlands: a licence's MRZ on its back holds the number its front prints", () {
      final check = checkSides(
        SideText.read(['RIJBEWIJS', '5. 1234567890']),
        SideText.read(['D1NLD11234567890ABCDEFGHIJKLM5']),
      );

      expect(check.match, SidesMatch.same);
    });

    test("Hungary: a licence's 4(a) and 4(b), year first", () {
      final front = SideText.read(['VEZETÓI ENGEDÉLY', '3. 1976.05.27.', '4(a), 2013.02.05', '4(b).2023.02.05.']);

      expect(front.licence?.dateOfBirth, DateTime(1976, 5, 27));
      expect(front.licence?.dateOfExpiry, DateTime(2023, 2, 5));
    });

    test('France: a title whose spaces text recognition dropped', () {
      expect(SideText.read(['CARTENATIONALE DIDENTITÉ /IDENTITYCARD']).title, DocumentType.identityCard);
    });

    test('no date in a long number', () {
      expect(SideText.read(['2830703460094', '12345678']).printedDates, 0);
    });
  });

  group("a passport's photo page against its own MRZ", () {
    const mrz = ['P<UTOERIKSSON<<ANNA<MARIA<<<<<', 'L898902C36UT07408122F1204159ZE184226B<<<<<10'];

    test('agrees when it prints the same number', () {
      expect(SideText.read(['PASSPORT', 'L898902C3', ...mrz]).printedMatchesMrz, SidesMatch.same);
    });

    test('disagrees when it prints other dates: a page whose printed zone was changed', () {
      final page = SideText.read(['PASSPORT', '01 JAN/JAN 1980', '01 JAN/JAN 2030', ...mrz]);

      expect(page.printedMatchesMrz, SidesMatch.different);
      expect(checkSides(page, SideText.read(['Persoonsgegevens'])).match, SidesMatch.different);
    });

    test('its MRZ lines are not read as its printed text', () {
      expect(SideText.read(mrz).vizNumbers, isEmpty);
    });
  });

  group("a Dutch passport's page, whose back prints the BSN its MRZ holds", () {
    final front = SideText.read([
      'PASPOORT',
      'P<NLDERIKSSON<<ANNA<<<',
      'L898902C36NLD7408122F1204159999999990<<',
      '<<<84',
    ]);

    test('is one document: the back, read turned, shows the BSN', () {
      final back = SideText.read(['Kinderen / Children', '', 'Persoonsnummer', '999999990']);

      expect(checkSides(front, back).match, SidesMatch.same);
    });

    test('the MRZ scan read: the BSN still ties the back', () {
      final back = SideText.read(['', '999999990']);
      final known = (
        documentNumber: 'L898902C3',
        dateOfBirth: DateTime(1974, 8, 12),
        dateOfExpiry: DateTime(2012, 4, 15),
      );

      expect(checkSides(front, back, known: known).match, SidesMatch.same);
    });

    test('another number on the back is no proof of another document', () {
      expect(checkSides(front, SideText.read(['', '123456782'])).match, SidesMatch.unknown);
    });
  });

  group('checkSides', () {
    test('a card front and the MRZ on its back are the same document', () {
      final check = checkSides(SideText.read(_cardFront), SideText.read(_cardBack));

      expect(check.match, SidesMatch.same);
    });

    test('the MRZ scan ties both sides to the document it read', () {
      final check = checkSides(
        SideText.read(_cardFront),
        SideText.read(_cardBack),
        known: (documentNumber: 'D23145890', dateOfBirth: DateTime(1974, 8, 12), dateOfExpiry: DateTime(2012, 4, 15)),
      );

      expect(check.match, SidesMatch.same);
    });

    test("a front whose dates are none of the back's MRZ is a different document", () {
      final check = checkSides(SideText.read(_cardFront), SideText.read(_otherCardBack));

      expect(check.match, SidesMatch.different);
    });

    test('a back whose MRZ names another document than the scan is a different one', () {
      final check = checkSides(
        SideText.read(_cardFront),
        SideText.read(_otherCardBack),
        known: (documentNumber: 'D23145890', dateOfBirth: DateTime(1974, 8, 12), dateOfExpiry: DateTime(2012, 4, 15)),
      );

      expect(check.match, SidesMatch.different);
    });

    test('the MRZ as text recognition reads it ties a card front to its back', () {
      expect(checkSides(SideText.read(_cardFront), SideText.read(_cardBackAsRead)).match, SidesMatch.same);
    });

    test('the MRZ as text recognition reads it tells another card back apart', () {
      expect(checkSides(SideText.read(_cardFront), SideText.read(_otherCardBackAsRead)).match, SidesMatch.different);
    });

    test('a back whose MRZ dates are not those the MRZ scan read is a different document', () {
      final check = checkSides(
        SideText.read(_cardFront),
        SideText.read(['8503013F3001019UTO<<']),
        known: (documentNumber: 'D23145890', dateOfBirth: DateTime(1974, 8, 12), dateOfExpiry: DateTime(2012, 4, 15)),
      );

      expect(check.match, SidesMatch.different);
    });

    test('a side the MRZ scan did not read is a different document', () {
      final check = checkSides(
        SideText.read(_cardFront),
        SideText.read(_cardBack),
        known: (documentNumber: 'XR9876543', dateOfBirth: null, dateOfExpiry: null),
      );

      expect(check.match, SidesMatch.different);
    });

    test('a side its dates tie to the document, without its number', () {
      final check = checkSides(SideText.read(['12 AUG/AUG 1974', '15.04.2012']), SideText.read(_cardBack));

      expect(check.match, SidesMatch.same);
    });

    test('without an MRZ, a number on both sides ties them', () {
      final check = checkSides(SideText.read(['RIJBEWIJS', '5. 4997542210']), SideText.read(['4997542210', 'AM B']));

      expect(check.match, SidesMatch.same);
    });

    test('a side with nothing to tie it is unknown', () {
      final check = checkSides(SideText.read(_cardFront), SideText.read(['Supermarkt']));

      expect(check.match, SidesMatch.unknown);
      expect(check.backLooksLikeDocument, isFalse);
    });

    test('an unread side is unknown', () {
      expect(checkSides(SideText.read(_cardFront), null).match, SidesMatch.unknown);
    });

    test('logs no document data', () {
      final check = checkSides(SideText.read(_cardFront), SideText.read(_cardBack));

      expect('$check', isNot(contains('D23')));
      expect('$check', isNot(contains('1974')));
    });
  });
}
