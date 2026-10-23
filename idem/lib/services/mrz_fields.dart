import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

// Text recognition on a still photo splits an MRZ line at its runs of '<'
// and miscounts them, so whole lines rarely parse: only the fields at the
// start of each line are read, and only kept when their check digits hold.

const _checkWeights = [7, 3, 1];
const _letterValueOffset = 55;
const _expiryCentury = 2000;

/// Letters text recognition reads for digits, in a field of digits.
const _digitLookalikes = {'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6'};

/// ICAO 9303 TD1, line 1: type, country, document number and its check digit.
final _td1Top = RegExp(r'^[IAC][A-Z0-9<][A-Z0-9<]{3}([A-Z0-9<]{9})([0-9A-Z])');

/// TD1, line 2: date of birth, sex, date of expiry, each date with its check digit.
final _td1Middle = RegExp(r'^([0-9A-Z]{6})([0-9A-Z])[MFX<]([0-9A-Z]{6})([0-9A-Z])');

/// The first line of a passport (TD3), or of a card (TD2) or visa that
/// starts with the holder's name: type, country, then the name's '<<'.
final _nameTop = RegExp(r'^([PIACV])[A-Z<][A-Z0-9<]{3}[A-Z<]*<<');

/// TD3 and TD2, line 2: document number, nationality, date of birth, sex,
/// date of expiry.
final _numberLine = RegExp(
  r'^([A-Z0-9<]{9})([0-9A-Z])[A-Z0-9<]{3}([0-9A-Z]{6})([0-9A-Z])[MFX<]([0-9A-Z]{6})([0-9A-Z])',
);

/// An EU driving licence's single line, its check digit over all before it.
final _drivingLicence = RegExp(r'^(D[A-Z0-9<][A-Z<]{3}[A-Z0-9])([A-Z0-9<]{10})([A-Z0-9<]{13})([0-9A-Z])$');

final _whitespace = RegExp(r'\s+');
final _anyDigit = RegExp(r'[0-9]');

/// What of an MRZ text recognition read off a photo, each field checked. A
/// driving licence's line is only recognised: where its number ends differs
/// per country.
typedef MrzFields = ({DocumentType type, String? documentNumber, DateTime? dateOfBirth, DateTime? dateOfExpiry});

/// The MRZ fields among [lines], null when none of them holds up. [now]
/// decides a date of birth's century.
MrzFields? readMrzFields(Iterable<String> lines, {DateTime? now}) {
  final today = now ?? DateTime.now();
  DocumentType? type;
  String? number;
  DateTime? birth;
  DateTime? expiry;
  for (final line in lines.map(_normalise)) {
    final nameTop = _nameTop.firstMatch(line);
    if (nameTop != null) type ??= nameTop[1] == 'P' ? DocumentType.passport : DocumentType.identityCard;

    final bottom = _numberLine.firstMatch(line);
    final bottomNumber = bottom == null ? null : _checked(bottom[1]!, bottom[2]!);
    final bottomBirth = bottom == null ? null : _checkedDate(bottom[3]!, bottom[4]!);
    if (bottom != null && bottomNumber != null && bottomBirth != null) {
      number ??= _documentNumber(bottomNumber);
      birth ??= _birthDate(bottomBirth, today);
      expiry ??= _expiryDate(_checkedDate(bottom[5]!, bottom[6]!));
      continue;
    }

    final top = _td1Top.firstMatch(line);
    // A name the check digit happens to fit has no digits.
    final topNumber = top == null || !_anyDigit.hasMatch(top[1]!) ? null : _checked(top[1]!, top[2]!);
    if (topNumber != null) {
      type ??= DocumentType.identityCard;
      number ??= _documentNumber(topNumber);
      continue;
    }

    final middle = _td1Middle.firstMatch(line);
    final middleBirth = middle == null ? null : _checkedDate(middle[1]!, middle[2]!);
    final middleExpiry = middle == null ? null : _checkedDate(middle[3]!, middle[4]!);
    if (middleBirth != null && middleExpiry != null) {
      type ??= DocumentType.identityCard;
      birth ??= _birthDate(middleBirth, today);
      expiry ??= _expiryDate(middleExpiry);
      continue;
    }

    final licence = _drivingLicence.firstMatch(line);
    if (licence != null && _checkDigit(line.substring(0, line.length - 1)) == _digit(licence[4]!)) {
      type = DocumentType.drivingLicence;
    }
  }

  // A document number line without its first line: most are passports.
  if (type == null && number != null && birth != null) type = DocumentType.passport;
  if (type == null) return null;
  if (type != DocumentType.drivingLicence && number == null && birth == null) return null;
  return (type: type, documentNumber: number, dateOfBirth: birth, dateOfExpiry: expiry);
}

String _normalise(String line) =>
    line.toUpperCase().replaceAll(_whitespace, '').replaceAll('«', '<<').replaceAll('‹', '<').replaceAll('|', '');

/// [field], when [check] is its check digit.
String? _checked(String field, String check) => _checkDigit(field) == _digit(check) ? field : null;

/// [field] of six digits, when [check] is its check digit.
String? _checkedDate(String field, String check) {
  final digits = field.split('').map((c) => _digitLookalikes[c] ?? c).join();
  if (int.tryParse(digits) == null) return null;
  return _checked(digits, check);
}

int? _digit(String c) => int.tryParse(_digitLookalikes[c] ?? c);

int _checkDigit(String field) {
  var sum = 0;
  for (var i = 0; i < field.length; i++) {
    final c = field.codeUnitAt(i);
    final value = switch (c) {
      >= 0x30 && <= 0x39 => c - 0x30,
      >= 0x41 && <= 0x5A => c - _letterValueOffset,
      _ => 0,
    };
    sum += value * _checkWeights[i % _checkWeights.length];
  }
  return sum % 10;
}

String? _documentNumber(String field) {
  final number = field.replaceAll('<', '');
  return number.isEmpty ? null : number;
}

DateTime? _birthDate(String yymmdd, DateTime today) {
  final year = int.parse(yymmdd.substring(0, 2));
  final century = year > today.year % 100 ? 1900 : 2000;
  return _date(century + year, yymmdd);
}

DateTime? _expiryDate(String? yymmdd) =>
    yymmdd == null ? null : _date(_expiryCentury + int.parse(yymmdd.substring(0, 2)), yymmdd);

/// Null for a day the month doesn't have.
DateTime? _date(int year, String yymmdd) {
  final month = int.parse(yymmdd.substring(2, 4));
  final day = int.parse(yymmdd.substring(4, 6));
  if (month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  return date.day == day ? date : null;
}
