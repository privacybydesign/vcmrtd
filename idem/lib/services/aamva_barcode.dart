import 'package:idem/services/mrz_fields.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

// The PDF417 barcode on the back of North American driving licences and
// identity cards (AAMVA DL/ID card design standard): data elements of a
// three-letter id and a value, one per line.

const _minYear = 1900;
const _maxYear = 2100;

/// The data elements read: licence number, date of birth, date of expiry,
/// surname, and the first name - given names before AAMVA's 2009 version.
const _numberId = 'DAQ';
const _birthId = 'DBB';
const _expiryId = 'DBA';
const _surnameId = 'DCS';
const _firstNameId = 'DAC';
const _oldGivenNamesId = 'DCT';

/// The first element follows the header on its line, after its subfile's type.
final _element = RegExp(
  '(?:^|DL|ID)($_numberId|$_birthId|$_expiryId|$_surnameId|$_firstNameId|$_oldGivenNamesId)(.+)\$',
);

/// The header: issuer, versions and entry count, then the first subfile's type.
final _subfile = RegExp(r'ANSI ?\d{12}(DL|ID)');
final _lineBreak = RegExp(r'[\n\r\x1e]+');

/// The licence number, dates and names in a scanned barcode's [raw] text; null
/// when it isn't an AAMVA one.
MrzFields? readAamvaBarcode(String raw) {
  if (!raw.contains('ANSI ') && !raw.contains('AAMVA')) return null;

  String? number;
  DateTime? birth;
  DateTime? expiry;
  String? surname;
  String? givenNames;
  for (final line in raw.split(_lineBreak)) {
    final element = _element.firstMatch(line.trim());
    if (element == null) continue;
    final value = element[2]!.trim();
    switch (element[1]) {
      case _numberId:
        number ??= value.replaceAll(' ', '');
      case _birthId:
        birth ??= _date(value);
      case _expiryId:
        expiry ??= _date(value);
      case _surnameId:
        surname ??= value;
      case _firstNameId || _oldGivenNamesId:
        givenNames ??= value.replaceAll(',', ' ');
    }
  }

  if (number == null && birth == null) return null;
  final type = _subfile.firstMatch(raw)?[1] == 'ID' ? DocumentType.identityCard : DocumentType.drivingLicence;
  return (
    type: type,
    documentNumber: number,
    dateOfBirth: birth,
    dateOfExpiry: expiry,
    personalNumber: null,
    licenceData: null,
    surname: surname,
    givenNames: givenNames,
  );
}

/// The United States write MMDDCCYY, Canada CCYYMMDD.
DateTime? _date(String value) {
  if (value.length != 8 || int.tryParse(value) == null) return null;
  final yearFirst = int.parse(value.substring(0, 4));
  if (yearFirst >= _minYear && yearFirst <= _maxYear) {
    final date = _valid(yearFirst, int.parse(value.substring(4, 6)), int.parse(value.substring(6, 8)));
    if (date != null) return date;
  }
  return _valid(int.parse(value.substring(4, 8)), int.parse(value.substring(0, 2)), int.parse(value.substring(2, 4)));
}

DateTime? _valid(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  return date.day == day ? date : null;
}
