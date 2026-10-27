import 'package:vcmrtd/vcmrtd.dart' show DocumentType, PassportMRZ;

// Text recognition on a still photo splits an MRZ line at its runs of '<'
// and miscounts them, so whole lines rarely parse: only the fields at the
// start of each line are read, and only kept when their check digits hold.

const _lastCentury = 1900;
const _thisCentury = 2000;
const _filler = '<';
const _passportType = 'P';

/// Letters text recognition reads for digits, in a field of digits.
const _digitLookalikes = {'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6'};

/// ICAO 9303 TD1, line 1: type, country, document number and its check digit.
final _td1Top = RegExp(r'^[IAC][A-Z0-9<][A-Z0-9<]{3}([A-Z0-9<]{9})([0-9A-Z])');

/// TD1, line 2: date of birth, sex, date of expiry, each date with its check digit.
final _td1Middle = RegExp(r'^([0-9A-Z]{6})([0-9A-Z])[MFX<]([0-9A-Z]{6})([0-9A-Z])');

/// The first line of a passport (TD3), or of a card (TD2) or visa that
/// starts with the holder's name: type, country, then the name's '<<'.
final _nameTop = RegExp(r'^([PIACV])[A-Z<][A-Z0-9<]{3}([A-Z<]*?)<<');

/// TD1, line 3: the holder's surname, '<<', the given names.
final _td1Name = RegExp(r'^([A-Z]+(?:<[A-Z]+)*)<<[A-Z<]*$');

/// TD3 and TD2, line 2: document number, nationality, date of birth, sex,
/// date of expiry, and what follows: TD3's personal number.
final _numberLine = RegExp(
  r'^([A-Z0-9<]{9})([0-9A-Z])[A-Z0-9<]{3}([0-9A-Z]{6})([0-9A-Z])[MFX<]([0-9A-Z]{6})([0-9A-Z])([A-Z0-9<]*)',
);

/// TD3's personal number field, before its check digit.
const _personalNumberLength = 14;
final _leadingCharacters = RegExp('^[A-Z0-9]{1,$_personalNumberLength}');

/// An EU driving licence's single line, its check digit over all before it.
final _drivingLicence = RegExp(r'^(D[A-Z0-9<][A-Z<]{3}[A-Z0-9])([A-Z0-9<]{10})([A-Z0-9<]{13})([0-9A-Z])$');

const _licenceDataStart = 5;

final _whitespace = RegExp(r'\s+');
final _anyDigit = RegExp(r'[0-9]');

/// What of an MRZ text recognition read off a photo, each field checked.
/// [personalNumber]: a passport's (TD3) optional data, such as the Dutch
/// BSN, which the other side of its page may print. [licenceData]: all of a
/// driving licence's line after its country - where its number ends differs
/// per country ("D1NLD1" and a version, "D<EST" without), so the number
/// printed on the licence is looked for in it. [surname]: its name line's,
/// which has no check digit.
typedef MrzFields = ({
  DocumentType type,
  String? documentNumber,
  DateTime? dateOfBirth,
  DateTime? dateOfExpiry,
  String? personalNumber,
  String? licenceData,
  String? surname,
});

/// The MRZ fields among [lines], null when none of them holds up. [now]
/// decides a date of birth's century.
MrzFields? readMrzFields(Iterable<String> lines, {DateTime? now}) {
  final reading = _MrzReading(now ?? DateTime.now());
  for (final line in lines.map(_normalise)) {
    if (!reading.nameTop(line)) reading.td1Name(line);
    if (reading.numberLine(line) || reading.td1Top(line) || reading.td1Middle(line)) continue;
    reading.licenceLine(line);
  }

  return reading.fields;
}

/// The fields read so far: each line kind fills what it holds, the first
/// reading of a field wins.
class _MrzReading {
  _MrzReading(this.today);

  final DateTime today;
  DocumentType? type;
  String? number;
  DateTime? birth;
  DateTime? expiry;
  String? personal;
  String? licenceData;
  String? surname;
  String? td1Surname;

  bool nameTop(String line) {
    final match = _nameTop.firstMatch(line);
    if (match == null) return false;
    type ??= match[1] == _passportType ? DocumentType.passport : DocumentType.identityCard;
    surname ??= _name(match[2]!);
    return true;
  }

  /// Kept only for a TD1, once its other lines have shown it is one.
  void td1Name(String line) {
    final match = _td1Name.firstMatch(line);
    if (match != null) td1Surname ??= _name(match[1]!);
  }

  bool numberLine(String line) {
    final match = _numberLine.firstMatch(line);
    if (match == null) return false;
    final checkedNumber = _checked(match[1]!, match[2]!);
    final checkedBirth = _checkedDate(match[3]!, match[4]!);
    if (checkedNumber == null || checkedBirth == null) return false;
    number ??= _documentNumber(checkedNumber);
    birth ??= _birthDate(checkedBirth, today);
    expiry ??= _expiryDate(_checkedDate(match[5]!, match[6]!));
    personal ??= _personalNumber(match[7]!);
    return true;
  }

  bool td1Top(String line) {
    final match = _td1Top.firstMatch(line);
    // A name the check digit happens to fit has no digits.
    if (match == null || !_anyDigit.hasMatch(match[1]!)) return false;
    final checkedNumber = _checked(match[1]!, match[2]!);
    if (checkedNumber == null) return false;
    type ??= DocumentType.identityCard;
    number ??= _documentNumber(checkedNumber);
    return true;
  }

  bool td1Middle(String line) {
    final match = _td1Middle.firstMatch(line);
    if (match == null) return false;
    final checkedBirth = _checkedDate(match[1]!, match[2]!);
    final checkedExpiry = _checkedDate(match[3]!, match[4]!);
    if (checkedBirth == null || checkedExpiry == null) return false;
    type ??= DocumentType.identityCard;
    birth ??= _birthDate(checkedBirth, today);
    expiry ??= _expiryDate(checkedExpiry);
    return true;
  }

  void licenceLine(String line) {
    final match = _drivingLicence.firstMatch(line);
    if (match != null && PassportMRZ.calculateCheckDigit(line.substring(0, line.length - 1)) == _digit(match[4]!)) {
      type = DocumentType.drivingLicence;
      licenceData ??= _documentNumber(line.substring(_licenceDataStart, line.length - 1));
    }
  }

  MrzFields? get fields {
    // A document number line without its first line: most are passports.
    final type = this.type ?? (number != null && birth != null ? DocumentType.passport : null);
    if (type == null) return null;
    if (number == null && birth == null && licenceData == null) return null;
    return (
      type: type,
      documentNumber: number,
      dateOfBirth: birth,
      dateOfExpiry: expiry,
      personalNumber: personal,
      licenceData: licenceData,
      surname: surname ?? (type == DocumentType.identityCard ? td1Surname : null),
    );
  }
}

String? _name(String field) {
  final name = field.split('<').where((word) => word.isNotEmpty).join(' ');
  return name.isEmpty ? null : name;
}

/// The personal number in [field], what follows a TD3's date of expiry:
/// checked when all of it and its check digit were read, else what was read
/// of it before its fillers (text recognition splits the line there) -
/// enough to tie a side to the document, too little to tell two apart.
String? _personalNumber(String field) {
  if (field.length > _personalNumberLength) {
    final checked = _checked(field.substring(0, _personalNumberLength), field[_personalNumberLength]);
    if (checked != null) return _documentNumber(checked);
  }
  return _leadingCharacters.firstMatch(field)?[0];
}

String _normalise(String line) => line
    .toUpperCase()
    .replaceAll(_whitespace, '')
    .replaceAll('«', '$_filler$_filler')
    .replaceAll('‹', _filler)
    .replaceAll('|', '');

/// [field], when [check] is its check digit.
String? _checked(String field, String check) => PassportMRZ.calculateCheckDigit(field) == _digit(check) ? field : null;

/// [field] of six digits, when [check] is its check digit.
String? _checkedDate(String field, String check) {
  final digits = field.split('').map((c) => _digitLookalikes[c] ?? c).join();
  if (int.tryParse(digits) == null) return null;
  return _checked(digits, check);
}

int? _digit(String c) => int.tryParse(_digitLookalikes[c] ?? c);

String? _documentNumber(String field) {
  final number = field.replaceAll(_filler, '');
  return number.isEmpty ? null : number;
}

DateTime? _birthDate(String yymmdd, DateTime today) {
  final year = int.parse(yymmdd.substring(0, 2));
  final century = year > today.year % 100 ? _lastCentury : _thisCentury;
  return _date(century + year, yymmdd);
}

DateTime? _expiryDate(String? yymmdd) =>
    yymmdd == null ? null : _date(_thisCentury + int.parse(yymmdd.substring(0, 2)), yymmdd);

/// Null for a day the month doesn't have.
DateTime? _date(int year, String yymmdd) {
  final month = int.parse(yymmdd.substring(2, 4));
  final day = int.parse(yymmdd.substring(4, 6));
  if (month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  return date.day == day ? date : null;
}
