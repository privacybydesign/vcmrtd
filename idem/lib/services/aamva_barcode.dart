import 'package:idem/services/mrz_fields.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

// The PDF417 barcode on the back of North American driving licences and
// identity cards (AAMVA DL/ID card design standard): data elements of a
// three-letter id and a value, one per line.

const _minYear = 1900;
const _maxYear = 2100;

/// The first element follows the header on its line, after its subfile's type.
final _element = RegExp(r'(?:^|DL|ID)(DAQ|DBB|DBA)(.+)$');

/// The header: issuer, versions and entry count, then the first subfile's type.
final _subfile = RegExp(r'ANSI ?\d{12}(DL|ID)');
final _lineBreak = RegExp(r'[\n\r\x1e]+');

/// The licence number and dates in a scanned barcode's [raw] text; null
/// when it isn't an AAMVA one.
MrzFields? readAamvaBarcode(String raw) {
  if (!raw.contains('ANSI ') && !raw.contains('AAMVA')) return null;

  String? number;
  DateTime? birth;
  DateTime? expiry;
  for (final line in raw.split(_lineBreak)) {
    final element = _element.firstMatch(line.trim());
    if (element == null) continue;
    final value = element[2]!.trim();
    switch (element[1]) {
      case 'DAQ':
        number ??= value.replaceAll(' ', '');
      case 'DBB':
        birth ??= _date(value);
      case 'DBA':
        expiry ??= _date(value);
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
