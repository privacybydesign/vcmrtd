import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/mrz_fields.dart';
import 'package:vcmrtd/vcmrtd.dart';

// The lines ML Kit read off rendered documents on an Android emulator.

const _passportNumberLine = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

void main() {
  final now = DateTime(2026, 10, 16);

  test('reads an ID card MRZ that text recognition split at its fillers', () {
    final mrz = readMrzFields([
      'Burgerservicenummer / Personal no.',
      '999999990',
      'I<UTOD231458907<<',
      '<<',
      '<<6',
      '7408122F1204159UT0<<',
      'ERIKSSON<<ANNA<MARIA<<< <<<<',
    ], now: now);

    expect(mrz, (
      type: DocumentType.identityCard,
      documentNumber: 'D23145890',
      dateOfBirth: DateTime(1974, 8, 12),
      dateOfExpiry: DateTime(2012, 4, 15),
      personalNumber: null,
      licenceData: null,
      surname: 'ERIKSSON',
      givenNames: 'ANNA MARIA',
    ));
  });

  test('reads a blurred ID card MRZ with spaces and « in it', () {
    final mrz = readMrzFields([
      'I<UTOD231458907<<.',
      '7408122F1 204159UTO<<<<<<<<««',
      'ERIKSSON<<ANNA<MARIA<<',
    ], now: now);

    expect(mrz?.documentNumber, 'D23145890');
    expect(mrz?.dateOfExpiry, DateTime(2012, 4, 15));
  });

  test('reads a passport MRZ with a 0 for the O of its nationality', () {
    final mrz = readMrzFields([
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<',
      '<<<',
      'L898902C36UT07408122F1204159ZE184226B<<<<<10',
    ], now: now);

    expect(mrz, (
      type: DocumentType.passport,
      documentNumber: 'L898902C3',
      dateOfBirth: DateTime(1974, 8, 12),
      dateOfExpiry: DateTime(2012, 4, 15),
      personalNumber: 'ZE184226B',
      licenceData: null,
      surname: 'ERIKSSON',
      givenNames: 'ANNA MARIA',
    ));
  });

  test("reads a passport's personal number up to its fillers, where text recognition split the line", () {
    final mrz = readMrzFields(['P<NLDERIKSSON<<ANNA<<<', 'L898902C36NLD7408122F1204159999999990<<', '<<<84'], now: now);

    expect(mrz?.personalNumber, '999999990');
  });

  test('a passport without a personal number has none', () {
    final mrz = readMrzFields(['P<UTOERIKSSON<<ANNA<<<', 'L898902C36UTO7408122F1204159<<<<<<<<<<<<<<04'], now: now);

    expect(mrz?.personalNumber, isNull);
  });

  test('reads a driving licence MRZ line', () {
    final mrz = readMrzFields(['D1NLD11234567890ABCDEFGHIJKLM5'], now: now);

    expect(mrz?.type, DocumentType.drivingLicence);
    expect(mrz?.licenceData, '11234567890ABCDEFGHIJKLM');
  });

  test("reads an Estonian licence's MRZ line, which has no version before its number", () {
    final mrz = readMrzFields(['D<ESTET999901<49307039909<<<<9'], now: now);

    expect(mrz?.type, DocumentType.drivingLicence);
    expect(mrz?.licenceData, 'ET99990149307039909');
  });

  test('reads a TD2 card MRZ: its name line is no document number', () {
    final mrz = readMrzFields([
      'I<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<',
      'AB12345671UTO7408122F3001019<<<<<<<4',
    ], now: now);

    expect(mrz, (
      type: DocumentType.identityCard,
      documentNumber: 'AB1234567',
      dateOfBirth: DateTime(1974, 8, 12),
      dateOfExpiry: DateTime(2030, 1, 1),
      personalNumber: null,
      licenceData: null,
      surname: 'ERIKSSON',
      givenNames: 'ANNA MARIA',
    ));
  });

  test("reads a surname of more words, and a passport's from a country with fillers in its code", () {
    expect(
      readMrzFields(['I<UTOD231458907<<', '7408122F1204159UTO<<', 'DE<BRUIJN<<WILLEKE'], now: now)?.surname,
      'DE BRUIJN',
    );
    expect(
      readMrzFields(['P<D<<MUSTERMANN<<ERIKA', 'L898902C36D<<7408122F1204159<<<<<<<<<<<<<<04'], now: now)?.surname,
      'MUSTERMANN',
    );
  });

  test('reads the given names after the surname, on a passport and a card', () {
    expect(readMrzFields(['P<UTOERIKSSON<<ANNA<MARIA<<<<<', _passportNumberLine], now: now)?.givenNames, 'ANNA MARIA');
    expect(
      readMrzFields([
        'I<UTOD231458907<<',
        '7408122F1204159UTO<<',
        'DE<BRUIJN<<WILLEKE<LISELOTTE<<',
      ], now: now)?.givenNames,
      'WILLEKE LISELOTTE',
    );
  });

  test("a card's name line is no passport's first line, whatever the surname starts with", () {
    for (final lines in [
      ['I<UTOD231458907<<<<<<<<<<<<<<<', '7408122F1204159UTO<<<<<<<<<<<6', 'PAUL<<ANNA<MARIA<<<<<<<<<<<<<<'],
      ['PAUL<<ANNA<MARIA<<<<<<<<<<<<<<', '7408122F1204159UTO<<<<<<<<<<<6'],
    ]) {
      final mrz = readMrzFields(lines, now: now)!;

      expect((mrz.type, mrz.surname, mrz.givenNames), (DocumentType.identityCard, 'PAUL', 'ANNA MARIA'));
    }
  });

  test("a passport whose number line text recognition split is no card", () {
    final mrz = readMrzFields([
      'P<D<<MUSTERMANN<<ERIKA<<<<<',
      'L898902C36D',
      '<<',
      '7408122F1204159<<<<<<<<<<<<<<04',
    ], now: now)!;

    expect((mrz.type, mrz.surname, mrz.givenNames), (DocumentType.passport, 'MUSTERMANN', 'ERIKA'));
  });

  test("a passport's first line with a second letter to its type is no card's name line", () {
    final mrz = readMrzFields([
      'POCHNZHANG<<SAN<<<<<<<<<<<<<<<<',
      'L898902C3',
      '<<',
      '7408122F1204159<<<<<<<<<<<<<<04',
    ], now: now)!;

    expect((mrz.type, mrz.surname, mrz.givenNames), (DocumentType.passport, 'ZHANG', 'SAN'));
  });

  test('a surname without given names has none', () {
    expect(readMrzFields(['P<UTOERIKSSON<<<<<<<<<', _passportNumberLine], now: now)?.givenNames, isNull);
  });

  test('a name line without the lines of a card has no surname', () {
    expect(readMrzFields(['D1NLD11234567890ABCDEFGHIJKLM5', 'ERIKSSON<<ANNA'], now: now)?.surname, isNull);
  });

  test('a number line without its first line is a passport', () {
    expect(readMrzFields(['L898902C36UTO7408122F1204159ZE184226B<<<<<10'], now: now)?.type, DocumentType.passport);
  });

  test('a date of birth after this year is of the last century', () {
    expect(readMrzFields(['8503013F3001019UTO<<'], now: now)?.dateOfBirth, DateTime(1985, 3, 1));
  });

  test('drops a field whose check digit fails', () {
    expect(readMrzFields(['I<UTOD231458908<<', '7408123F1204159UTO'], now: now), isNull);
  });

  test('finds nothing in a document without an MRZ, its title included', () {
    expect(readMrzFields(['PASPOORT / PASSPORT', 'D23145890', '12 AUG/AUG 1974'], now: now), isNull);
  });
}
