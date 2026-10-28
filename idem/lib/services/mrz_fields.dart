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
/// starts with the holder's name: type, country, the surname, '<<', the
/// given names.
final _nameTop = RegExp(r'^([PIACV])[A-Z<]([A-Z0-9<]{3})([A-Z<]*?)<<([A-Z<]*)');

/// TD1, line 3: the holder's surname, '<<', the given names.
/// Its first word has two letters at least: no passport's "P<D<<" or "P<UTO".
final _td1Name = RegExp(r'^([A-Z]{2,}(?:<[A-Z]+)*)<<([A-Z<]*)$');

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

/// The countries an MRZ names: ISO 3166-1's, and those ICAO 9303-3 (5)
/// adds - Germany's "D", British nationals', organisations', stateless
/// persons' and refugees', and the specimens' Utopia.
const _countryCodes = {
  'ABW', 'AFG', 'AGO', 'AIA', 'ALA', 'ALB', 'AND', 'ARE', 'ARG', 'ARM', 'ASM', 'ATA', 'ATF', 'ATG', 'AUS', 'AUT',
  'AZE', 'BDI', 'BEL', 'BEN', 'BES', 'BFA', 'BGD', 'BGR', 'BHR', 'BHS', 'BIH', 'BLM', 'BLR', 'BLZ', 'BMU', 'BOL',
  'BRA', 'BRB', 'BRN', 'BTN', 'BVT', 'BWA', 'CAF', 'CAN', 'CCK', 'CHE', 'CHL', 'CHN', 'CIV', 'CMR', 'COD', 'COG',
  'COK', 'COL', 'COM', 'CPV', 'CRI', 'CUB', 'CUW', 'CXR', 'CYM', 'CYP', 'CZE', 'DEU', 'DJI', 'DMA', 'DNK', 'DOM',
  'DZA', 'ECU', 'EGY', 'ERI', 'ESH', 'ESP', 'EST', 'ETH', 'FIN', 'FJI', 'FLK', 'FRA', 'FRO', 'FSM', 'GAB', 'GBR',
  'GEO', 'GGY', 'GHA', 'GIB', 'GIN', 'GLP', 'GMB', 'GNB', 'GNQ', 'GRC', 'GRD', 'GRL', 'GTM', 'GUF', 'GUM', 'GUY',
  'HKG', 'HMD', 'HND', 'HRV', 'HTI', 'HUN', 'IDN', 'IMN', 'IND', 'IOT', 'IRL', 'IRN', 'IRQ', 'ISL', 'ISR', 'ITA',
  'JAM', 'JEY', 'JOR', 'JPN', 'KAZ', 'KEN', 'KGZ', 'KHM', 'KIR', 'KNA', 'KOR', 'KWT', 'LAO', 'LBN', 'LBR', 'LBY',
  'LCA', 'LIE', 'LKA', 'LSO', 'LTU', 'LUX', 'LVA', 'MAC', 'MAF', 'MAR', 'MCO', 'MDA', 'MDG', 'MDV', 'MEX', 'MHL',
  'MKD', 'MLI', 'MLT', 'MMR', 'MNE', 'MNG', 'MNP', 'MOZ', 'MRT', 'MSR', 'MTQ', 'MUS', 'MWI', 'MYS', 'MYT', 'NAM',
  'NCL', 'NER', 'NFK', 'NGA', 'NIC', 'NIU', 'NLD', 'NOR', 'NPL', 'NRU', 'NZL', 'OMN', 'PAK', 'PAN', 'PCN', 'PER',
  'PHL', 'PLW', 'PNG', 'POL', 'PRI', 'PRK', 'PRT', 'PRY', 'PSE', 'PYF', 'QAT', 'REU', 'ROU', 'RUS', 'RWA', 'SAU',
  'SDN', 'SEN', 'SGP', 'SGS', 'SHN', 'SJM', 'SLB', 'SLE', 'SLV', 'SMR', 'SOM', 'SPM', 'SRB', 'SSD', 'STP', 'SUR',
  'SVK', 'SVN', 'SWE', 'SWZ', 'SXM', 'SYC', 'SYR', 'TCA', 'TCD', 'TGO', 'THA', 'TJK', 'TKL', 'TKM', 'TLS', 'TON',
  'TTO', 'TUN', 'TUR', 'TUV', 'TWN', 'TZA', 'UGA', 'UKR', 'UMI', 'URY', 'USA', 'UZB', 'VAT', 'VCT', 'VEN', 'VGB',
  'VIR', 'VNM', 'VUT', 'WLF', 'WSM', 'YEM', 'ZAF', 'ZMB', 'ZWE',
  // ICAO 9303-3, 5 A to H
  'D<<', 'GBD', 'GBN', 'GBO', 'GBP', 'GBS', 'RKS', 'EUE', 'UNO', 'UNA', 'UNK', 'XBA', 'XIM', 'XCC', 'XCE', 'XCO',
  'XEC', 'XPO', 'XES', 'XMP', 'XOM', 'XDC', 'XXA', 'XXB', 'XXC', 'XXX', 'ANT', 'NTZ', 'UTO', 'IAO',
};

final _whitespace = RegExp(r'\s+');
final _anyDigit = RegExp(r'[0-9]');

/// What of an MRZ text recognition read off a photo, each field checked.
/// [personalNumber]: a passport's (TD3) optional data, such as the Dutch
/// BSN, which the other side of its page may print. [licenceData]: all of a
/// driving licence's line after its country - where its number ends differs
/// per country ("D1NLD1" and a version, "D<EST" without), so the number
/// printed on the licence is looked for in it. [surname] and [givenNames]:
/// its name line's, which has no check digit.
typedef MrzFields = ({
  DocumentType type,
  String? documentNumber,
  DateTime? dateOfBirth,
  DateTime? dateOfExpiry,
  String? personalNumber,
  String? licenceData,
  String? surname,
  String? givenNames,
});

/// The MRZ fields among [lines], null when none of them holds up. [now]
/// decides a date of birth's century.
MrzFields? readMrzFields(Iterable<String> lines, {DateTime? now}) {
  final reading = _MrzReading(now ?? DateTime.now());
  for (final line in lines.map(_normalise)) {
    reading.nameTop(line);
    reading.td1Name(line);
    if (reading.numberLine(line) || reading.readTd1Top(line) || reading.readTd1Middle(line)) continue;
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
  bool td1Top = false;
  bool td1Middle = false;
  bool nameTopMayBeTd1Name = false;
  String? number;
  DateTime? birth;
  DateTime? expiry;
  String? personal;
  String? licenceData;
  String? surname;
  String? givenNames;
  String? td1Surname;
  String? td1GivenNames;

  void nameTop(String line) {
    final match = _nameTop.firstMatch(line);
    if (match == null) return;
    type ??= match[1] == _passportType ? DocumentType.passport : DocumentType.identityCard;
    surname ??= _name(match[3]!);
    givenNames ??= _name(match[4]!);
    // No first line names a country that isn't one: "PAUL<<ANNA" is a TD1's
    // name line, "POCHNZHANG<<SAN" a Chinese passport's first line.
    nameTopMayBeTd1Name |= _td1Name.hasMatch(line) && !_countryCodes.contains(match[2]);
  }

  /// Kept only for a TD1, once its other lines have shown it is one.
  void td1Name(String line) {
    final match = _td1Name.firstMatch(line);
    if (match == null) return;
    td1Surname ??= _name(match[1]!);
    td1GivenNames ??= _name(match[2]!);
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

  bool readTd1Top(String line) {
    final match = _td1Top.firstMatch(line);
    // A name the check digit happens to fit has no digits.
    if (match == null || !_anyDigit.hasMatch(match[1]!)) return false;
    final checkedNumber = _checked(match[1]!, match[2]!);
    if (checkedNumber == null) return false;
    type ??= DocumentType.identityCard;
    td1Top = true;
    number ??= _documentNumber(checkedNumber);
    return true;
  }

  bool readTd1Middle(String line) {
    final match = _td1Middle.firstMatch(line);
    if (match == null) return false;
    final checkedBirth = _checkedDate(match[1]!, match[2]!);
    final checkedExpiry = _checkedDate(match[3]!, match[4]!);
    if (checkedBirth == null || checkedExpiry == null) return false;
    type ??= DocumentType.identityCard;
    td1Middle = true;
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

  /// A TD1's name line can look like a first line ("PAUL<<ANNA"), and a
  /// passport's number line split by text recognition like a TD1's middle
  /// line: a TD1 by its first line, or its middle line and a name line.
  bool get td1 => td1Top || (td1Middle && nameTopMayBeTd1Name);

  MrzFields? get fields {
    final type = switch (this.type) {
      DocumentType.drivingLicence => DocumentType.drivingLicence,
      _ when td1 => DocumentType.identityCard,
      final type? => type,
      // A document number line without its first line: most are passports.
      null => number != null && birth != null ? DocumentType.passport : null,
    };
    if (type == null) return null;
    if (number == null && birth == null && licenceData == null) return null;
    return (
      type: type,
      documentNumber: number,
      dateOfBirth: birth,
      dateOfExpiry: expiry,
      personalNumber: personal,
      licenceData: licenceData,
      surname: td1 ? td1Surname : surname ?? (type == DocumentType.identityCard ? td1Surname : null),
      givenNames: td1 ? td1GivenNames : givenNames ?? (type == DocumentType.identityCard ? td1GivenNames : null),
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
