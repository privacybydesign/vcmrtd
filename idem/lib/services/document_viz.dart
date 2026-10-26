import 'package:idem/services/aamva_barcode.dart';
import 'package:idem/services/mrz_fields.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

// Measured on one real Dutch ID card and on rendered documents only: compare
// the text read off real documents' sides before letting these decide anything.

const _minNumberLength = 6;
const _maxNumberLength = 12;
const _minSharedDates = 2;
const _minLicenceFieldLabels = 2;
const _minLicenceCategories = 3;
const _minYear = 1900;
const _maxYear = 2100;
const _twoDigitYearCenturies = [1900, 2000];

/// Letters text recognition reads for digits: matching ignores which it read.
const _lookalikes = {'O': '0', 'Q': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8'};

/// Month names as documents in the EU's languages abbreviate them, without
/// their accents; looked up whole, then by their first four and three letters.
const _months = {
  // English, Dutch, German, the Nordic languages
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'MAA': 3, 'MRZ': 3, 'APR': 4, 'MAY': 5, 'MEI': 5, 'MAI': 5, 'MAJ': 5,
  'JUN': 6, 'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'OKT': 10, 'NOV': 11, 'DEC': 12, 'DEZ': 12, 'DES': 12,
  // French
  'JANV': 1, 'FEV': 2, 'FEVR': 2, 'MARS': 3, 'AVR': 4, 'AVRI': 4, 'JUIN': 6, 'JUIL': 7, 'AOU': 8, 'AOUT': 8,
  'SEPT': 9,
  // Spanish, Italian, Portuguese, Romanian
  'ENE': 1, 'GEN': 1, 'IAN': 1, 'ABR': 4, 'MAG': 5, 'GIU': 6, 'IUN': 6, 'LUG': 7, 'IUL': 7, 'AGO': 8,
  'SET': 9, 'OTT': 10, 'OUT': 10, 'NOI': 11, 'DIC': 12,
  // Polish, Czech, Slovak
  'STY': 1, 'LED': 1, 'LUT': 2, 'UNO': 2, 'BRE': 3, 'KWI': 4, 'DUB': 4, 'KVE': 5, 'CZE': 6, 'CVN': 6,
  'LIP': 7, 'CVC': 7, 'SIE': 8, 'SRP': 8, 'WRZ': 9, 'ZAR': 9, 'PAZ': 10, 'RIJ': 10, 'LIS': 11, 'GRU': 12,
  'PRO': 12,
};

/// The titles documents print on them, in the EU's and other common
/// languages, without their accents. ICAO 9303 has every passport and
/// identity card carry one in English, French or Spanish.
const _titles = {
  'IDENTITY CARD': DocumentType.identityCard,
  "CARTE D'IDENTITE": DocumentType.identityCard,
  'CARTE NATIONALE': DocumentType.identityCard,
  'DOCUMENTO DE IDENTIDAD': DocumentType.identityCard,
  'DOCUMENTO NACIONAL DE IDENTIDAD': DocumentType.identityCard,
  "CARTA D'IDENTITA": DocumentType.identityCard,
  'CARTA DI IDENTITA': DocumentType.identityCard,
  'CARTAO DE CIDADAO': DocumentType.identityCard,
  'BILHETE DE IDENTIDADE': DocumentType.identityCard,
  'IDENTITEITSKAART': DocumentType.identityCard,
  'PERSONALAUSWEIS': DocumentType.identityCard,
  'IDENTITATSKARTE': DocumentType.identityCard,
  'IDENTITETSKORT': DocumentType.identityCard,
  'IDENTITEETTIKORTTI': DocumentType.identityCard,
  'HENKILOKORTTI': DocumentType.identityCard,
  'DOWOD OSOBISTY': DocumentType.identityCard,
  'OBCANSKY PRUKAZ': DocumentType.identityCard,
  'OBCIANSKY PREUKAZ': DocumentType.identityCard,
  'SZEMELYAZONOSITO': DocumentType.identityCard,
  'CARTE DE IDENTITATE': DocumentType.identityCard,
  'ASMENS TAPATYBES': DocumentType.identityCard,
  'PERSONAS APLIECIBA': DocumentType.identityCard,
  'ISIKUTUNNISTUS': DocumentType.identityCard,
  'OSEBNA IZKAZNICA': DocumentType.identityCard,
  'OSOBNA ISKAZNICA': DocumentType.identityCard,
  'KARTA TAL-IDENTITA': DocumentType.identityCard,
  'NAFNSKIRTEINI': DocumentType.identityCard,
  'KIMLIK KARTI': DocumentType.identityCard,
  // Residence permits: identity cards in the same format (TD1).
  'RESIDENCE PERMIT': DocumentType.identityCard,
  'TITRE DE SEJOUR': DocumentType.identityCard,
  'VERBLIJFSDOCUMENT': DocumentType.identityCard,
  'AUFENTHALTSTITEL': DocumentType.identityCard,
  'PERMISO DE RESIDENCIA': DocumentType.identityCard,
  'PERMESSO DI SOGGIORNO': DocumentType.identityCard,
  'PASSPORT': DocumentType.passport,
  'PASSEPORT': DocumentType.passport,
  'PASAPORTE': DocumentType.passport,
  'PASSAPORTE': DocumentType.passport,
  'PASSAPORTO': DocumentType.passport,
  'PASPOORT': DocumentType.passport,
  'REISEPASS': DocumentType.passport,
  'PASZPORT': DocumentType.passport,
  'CESTOVNI PAS': DocumentType.passport,
  'CESTOVNY PAS': DocumentType.passport,
  'UTLEVEL': DocumentType.passport,
  'PASAPORT': DocumentType.passport,
  'PASSIPORTTI': DocumentType.passport,
  'DRIVING LICENCE': DocumentType.drivingLicence,
  'DRIVER LICENSE': DocumentType.drivingLicence,
  "DRIVER'S LICENSE": DocumentType.drivingLicence,
  'DRIVERS LICENSE': DocumentType.drivingLicence,
  'PERMIS DE CONDUIRE': DocumentType.drivingLicence,
  'PERMISO DE CONDUCCION': DocumentType.drivingLicence,
  'PATENTE DI GUIDA': DocumentType.drivingLicence,
  'CARTA DE CONDUCAO': DocumentType.drivingLicence,
  'RIJBEWIJS': DocumentType.drivingLicence,
  'FUHRERSCHEIN': DocumentType.drivingLicence,
  'FUEHRERSCHEIN': DocumentType.drivingLicence,
  'PRAWO JAZDY': DocumentType.drivingLicence,
  'RIDICSKY PRUKAZ': DocumentType.drivingLicence,
  'VODICSKY PREUKAZ': DocumentType.drivingLicence,
  'VEZETOI ENGEDELY': DocumentType.drivingLicence,
  'PERMIS DE CONDUCERE': DocumentType.drivingLicence,
  'KORKORT': DocumentType.drivingLicence,
  'KOREKORT': DocumentType.drivingLicence,
  'FORERKORT': DocumentType.drivingLicence,
  'AJOKORTTI': DocumentType.drivingLicence,
  'JUHILUBA': DocumentType.drivingLicence,
  'VADITAJA APLIECIBA': DocumentType.drivingLicence,
  'VAIRUOTOJO PAZYMEJIMAS': DocumentType.drivingLicence,
  'VOZNISKO DOVOLJENJE': DocumentType.drivingLicence,
  'VOZACKA DOZVOLA': DocumentType.drivingLicence,
  'LICENZJA TAS-SEWQAN': DocumentType.drivingLicence,
  'CEADUNAS TIOMANA': DocumentType.drivingLicence,
  'OKUSKIRTEINI': DocumentType.drivingLicence,
  'SURUCU BELGESI': DocumentType.drivingLicence,
};

/// Accented capitals as their plain letters, so a title or month reads the
/// same whether or not text recognition kept its accents.
const _plainLetters = {
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'Ā': 'A',
  'Ă': 'A',
  'Ą': 'A',
  'Ç': 'C',
  'Ć': 'C',
  'Č': 'C',
  'Ď': 'D',
  'Đ': 'D',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Ē': 'E',
  'Ė': 'E',
  'Ę': 'E',
  'Ě': 'E',
  'Ğ': 'G',
  'Ģ': 'G',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ī': 'I',
  'Į': 'I',
  'İ': 'I',
  'Ķ': 'K',
  'Ĺ': 'L',
  'Ļ': 'L',
  'Ľ': 'L',
  'Ł': 'L',
  'Ñ': 'N',
  'Ń': 'N',
  'Ņ': 'N',
  'Ň': 'N',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ø': 'O',
  'Ő': 'O',
  'Ŕ': 'R',
  'Ř': 'R',
  'Ś': 'S',
  'Ş': 'S',
  'Š': 'S',
  'Ș': 'S',
  'Ţ': 'T',
  'Ť': 'T',
  'Ț': 'T',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ū': 'U',
  'Ů': 'U',
  'Ű': 'U',
  'Ų': 'U',
  'Ý': 'Y',
  'Ź': 'Z',
  'Ż': 'Z',
  'Ž': 'Z',
  'Ð': 'D',
  'Þ': 'TH',
  'Æ': 'AE',
  'Œ': 'OE',
  'ẞ': 'SS',
  '’': "'",
  '`': "'",
};

/// "12.08.1974", "12/08/74", or the United States' "08/12/1974" - and as
/// text recognition reads them: "1505 1975", "19,01.2018", "15. 10.91".
final _dayFirstDate = RegExp(r'(?<!\d)(\d{1,2})([.\-/,]? ?)(\d{1,2})([.\-/,]? ?)(\d{4}|\d{2})(?![\d.,:]\d)');

/// "1974-08-12", "1974.08.12.": Hungary, Lithuania, Sweden, much of Asia.
final _yearFirstDate = RegExp(r'(?<!\d)(\d{4})[.\-/,] ?(\d{1,2})[.\-/,] ?(\d{1,2})(?!\d)');

/// "12 AUG/AUG 1974", "12 MARS 74", "12. OKT. 1974", "15 OCTOBER 2020" - and
/// with the slash read as a letter: "23 APR IAPR 56", "01 MARIMAR 2034".
final _namedMonthDate = RegExp(
  r'(?<!\d)(\d{1,2})\.? ?([A-Z]{3,9}\.?(?: ?[/|I1] ?[A-Z]{3,5}\.?)*) ?(\d{4}|\d{2})(?!\d)',
);
final _monthSeparator = RegExp(r'[/| ]');

/// ISO/IEC 18013-1 numbers a driving licence's fields: 3 date of birth, 4a
/// issued, 4b expires, 4c issued by, 4d (United States) and 5 the licence
/// number - EU and North American licences alike, in any language. A
/// United States licence follows the number with a label ("4d DLN").
/// Several fields can share a line ("4a. 01.03.2011 4b. 01.01.2050"), and
/// Hungary writes "4(a)".
final _licenceField = RegExp(r'(?<![A-Z0-9.])(3|5|4\(?[A-D]\)?)(?:[.:,]? +|[.:,](?=\S)|[.:,]?$)');

/// The fields a licence's back numbers (9 to 14), at the start of a line.
final _licenceBackField = RegExp(r'^\(?(9|1[0-4])\)?[.,]?(?!\d)');
const _minLicenceBackFields = 3;

/// The categories a licence's back lists, leaving out the single letters
/// any text has.
const _licenceCategories = {'AM', 'A1', 'A2', 'B1', 'BE', 'C1', 'C1E', 'CE', 'D1', 'D1E', 'DE'};

final _token = RegExp(r'[A-Z0-9]+');
final _digit = RegExp(r'\d');
final _alphanumeric = RegExp(r'^[A-Z0-9]+$');
final _mrzLine = RegExp('[<«]');

/// What the MRZ scan or the chip read says the document is.
typedef KnownDocument = ({String documentNumber, DateTime? dateOfBirth, DateTime? dateOfExpiry});

/// A driving licence's numbered fields (see [_licenceField]).
typedef LicenceFields = ({String? number, DateTime? dateOfBirth, DateTime? dateOfExpiry, int labels});

/// The text read off one photographed side of a document: what of it can
/// tie that side to the document, printed (its visual zone, VIZ) or machine
/// readable (its MRZ, or a North American licence's barcode).
class SideText {
  SideText._({
    required this.vizNumbers,
    required this.vizDates,
    required this.printedDates,
    required this.mrz,
    required MrzFields? barcode,
    required this.title,
    required this.licence,
    required int licenceCategories,
    required int licenceBackFields,
  }) : _barcode = barcode,
       _licenceCategoryCount = licenceCategories,
       _licenceBackFieldCount = licenceBackFields;

  /// [lines] of text, top to bottom, and the [barcodes] scanned off the same photo.
  factory SideText.read(List<String> lines, {List<String> barcodes = const []}) {
    final printed = [
      for (final line in lines)
        if (!_mrzLine.hasMatch(line)) _plain(line),
    ];
    final datesPerLine = [for (final line in printed) _datesIn(line).toList()];
    final undatedLines = [
      for (final (i, line) in printed.indexed)
        if (datesPerLine[i].isEmpty) line,
    ];
    final tokens = printed.expand(_tokensIn);
    final vizNumbers = {for (final token in tokens.where(_looksLikeNumber)) _matchKey(token)};

    final licence = _licenceFieldsIn(printed);
    final licenceNumber = licence?.number;
    if (licenceNumber != null) vizNumbers.add(_matchKey(licenceNumber));
    return SideText._(
      vizNumbers: vizNumbers,
      vizDates: {for (final dates in datesPerLine) ...dates.expand((readings) => readings)},
      printedDates: datesPerLine.fold(0, (count, dates) => count + dates.length),
      mrz: readMrzFields(lines),
      barcode: barcodes.map(readAamvaBarcode).nonNulls.firstOrNull,
      title: printed.map(_titleIn).nonNulls.firstOrNull,
      licence: licence,
      licenceCategories: tokens.where(_licenceCategories.contains).toSet().length,
      licenceBackFields: undatedLines
          .map((line) => _licenceBackField.firstMatch(line.trim())?[1])
          .nonNulls
          .toSet()
          .length,
    );
  }

  /// Document number candidates in the printed text, in [_matchKey] form.
  final Set<String> vizNumbers;

  /// Every reading of the dates printed on this side.
  final Set<DateTime> vizDates;

  /// How many dates are printed on this side, each counted once however many
  /// readings it has.
  final int printedDates;

  /// The MRZ fields on this side whose check digits hold.
  final MrzFields? mrz;

  /// What a North American licence's barcode on this side says.
  final MrzFields? _barcode;

  /// The kind of document the side's printed title names.
  final DocumentType? title;

  /// The numbered fields of a driving licence's front, when there are.
  final LicenceFields? licence;

  /// How many of the categories a licence's back lists this side shows.
  final int _licenceCategoryCount;

  /// How many of a licence back's numbered fields (9 to 14) this side shows.
  final int _licenceBackFieldCount;

  bool get _licenceBack =>
      _licenceCategoryCount >= _minLicenceCategories || _licenceBackFieldCount >= _minLicenceBackFields;

  /// What this side has of the document that a machine reads.
  List<MrzFields> get _machineReadable => [?mrz, ?_barcode];

  Set<String> get _numbers => {
    ...vizNumbers,
    for (final zone in _machineReadable)
      if (zone.documentNumber case final number?) _matchKey(number),
  };

  Set<DateTime> get dates => {
    ...vizDates,
    for (final zone in _machineReadable) ...[?zone.dateOfBirth, ?zone.dateOfExpiry],
  };

  bool get _licenceLayout => (licence?.labels ?? 0) >= _minLicenceFieldLabels || _licenceBack;

  /// The kind of document the side shows it is: by what a machine reads,
  /// else its title, else a licence's numbered fields or categories.
  DocumentType? get documentType =>
      _machineReadable.firstOrNull?.type ?? title ?? (_licenceLayout ? DocumentType.drivingLicence : null);

  /// Whether this side shows what an identity document does: an MRZ or a
  /// licence's barcode, a document title, a licence's layout, or a date of
  /// birth and of expiry.
  bool get looksLikeDocument => documentType != null || printedDates >= _minSharedDates || _machineReadable.isNotEmpty;

  /// Whether this side's printed text agrees with its own MRZ - a passport's
  /// photo page shows both: the same number or dates, or neither date.
  SidesMatch get printedMatchesMrz {
    final mrz = this.mrz;
    if (mrz == null) return SidesMatch.unknown;
    final number = mrz.documentNumber;
    if (number != null && vizNumbers.contains(_matchKey(number))) return SidesMatch.same;
    final birth = mrz.dateOfBirth;
    final expiry = mrz.dateOfExpiry;
    if (birth == null || expiry == null) return SidesMatch.unknown;
    if (_shows(vizDates, birth) && _shows(vizDates, expiry)) return SidesMatch.same;
    if (_contradicts(birth, expiry)) return SidesMatch.different;
    return SidesMatch.unknown;
  }

  bool carries(String documentNumber) => _numbers.contains(_matchKey(documentNumber));

  /// Whether this side prints a number that is part of a licence MRZ's
  /// [licenceData] (see [MrzFields]).
  bool _printsPartOf(String licenceData) {
    final data = _matchKey(licenceData);
    return vizNumbers.any(data.contains);
  }

  bool _carriesDates(DateTime? birth, DateTime? expiry) =>
      birth != null && expiry != null && _shows(dates, birth) && _shows(dates, expiry);

  /// Whether this side prints dates, but neither of these.
  bool _contradicts(DateTime? birth, DateTime? expiry) =>
      birth != null &&
      expiry != null &&
      printedDates >= _minSharedDates &&
      !_shows(vizDates, birth) &&
      !_shows(vizDates, expiry);

  /// Whether [date] is among the printed dates.
  bool shows(DateTime date) => _shows(vizDates, date);

  /// No document data: it's logged.
  @override
  String toString() => [
    'type=${documentType?.name ?? 'none'}',
    'mrz=${mrz == null ? 'no' : _zoneSummary(mrz!)}',
    if (_barcode != null) 'barcode=${_zoneSummary(_barcode)}',
    'title=${title?.name ?? 'no'}',
    if (licence != null) 'licenceFields=${licence!.labels}',
    if (_licenceCategoryCount > 0) 'licenceCategories=$_licenceCategoryCount',
    'numbers=${vizNumbers.length}',
    'dates=$printedDates',
    if (_licenceBackFieldCount > 0) 'licenceBackFields=$_licenceBackFieldCount',
    if (mrz != null) 'printedMatchesMrz=${printedMatchesMrz.name}',
  ].join(' ');
}

String _zoneSummary(MrzFields zone) =>
    '${zone.type.name}${zone.documentNumber == null ? '' : '+number'}${zone.dateOfBirth == null ? '' : '+dates'}';

enum SidesMatch { same, different, unknown }

/// What the text on both sides says: whether each looks like an identity
/// document, and whether they are of the same one.
class VizCheck {
  const VizCheck({required this.match, required this.front, required this.back});

  final SidesMatch match;

  /// Null when the side's text couldn't be read.
  final SideText? front;
  final SideText? back;

  bool get frontLooksLikeDocument => front?.looksLikeDocument ?? false;
  bool get backLooksLikeDocument => back?.looksLikeDocument ?? false;

  /// No document data: it's logged.
  @override
  String toString() =>
      'match=${match.name} frontDocument=$frontLooksLikeDocument backDocument=$backLooksLikeDocument '
      'front=[${front ?? 'unread'}] back=[${back ?? 'unread'}]';
}

/// Whether [front] and [back] are of one document, by its number and its
/// dates of birth and expiry: the MRZ scan's or chip's [known], else what a
/// machine reads off either side (an MRZ, a licence's barcode). Both sides
/// must carry the number, both dates, or the personal number a passport's
/// MRZ holds (the Dutch BSN, which the back of its page prints); different when a machine-readable
/// zone names another number or other dates, or the front prints dates but
/// neither of them. Without any, a licence whose back lists its categories
/// until the front's expiry; else a number or two dates the sides share.
VizCheck checkSides(SideText? front, SideText? back, {KnownDocument? known}) {
  VizCheck result(SidesMatch match) => VizCheck(match: match, front: front, back: back);
  if (front == null || back == null) return result(SidesMatch.unknown);

  final zones = [...front._machineReadable, ...back._machineReadable];
  T? fromZones<T extends Object>(T? Function(MrzFields zone) field) => zones.map(field).nonNulls.firstOrNull;
  final number = known?.documentNumber ?? fromZones((zone) => zone.documentNumber);
  final birth = known?.dateOfBirth ?? fromZones((zone) => zone.dateOfBirth);
  final expiry = known?.dateOfExpiry ?? fromZones((zone) => zone.dateOfExpiry);
  if (number == null && (birth == null || expiry == null)) return result(_matchWithoutReference(front, back));

  final namesAnother = zones.any((zone) => _namesAnother(zone, number, birth, expiry));
  if (namesAnother || front.printedMatchesMrz == SidesMatch.different) return result(SidesMatch.different);

  // Only ever ties: text recognition reads it on one side at most, often only partly.
  final personal = fromZones((zone) => zone.personalNumber);
  final personalNumber = personal != null && _looksLikeNumber(personal) ? personal : null;
  final licenceData = zones.map((zone) => zone.licenceData).nonNulls;
  bool tied(SideText side) =>
      (number != null && side.carries(number)) ||
      (personalNumber != null && side.carries(personalNumber)) ||
      licenceData.any(side._printsPartOf) ||
      side._carriesDates(birth, expiry);
  if (tied(front) && tied(back)) return result(SidesMatch.same);
  // Only the front: a back's dates are often others (issued, categories).
  if (front._contradicts(birth, expiry)) return result(SidesMatch.different);
  return result(SidesMatch.unknown);
}

bool _namesAnother(MrzFields zone, String? number, DateTime? birth, DateTime? expiry) {
  bool differs(DateTime? a, DateTime? b) => a != null && b != null && !_sameDay(a, b);
  final zoneNumber = zone.documentNumber;
  return (number != null && zoneNumber != null && _matchKey(zoneNumber) != _matchKey(number)) ||
      differs(zone.dateOfBirth, birth) ||
      differs(zone.dateOfExpiry, expiry);
}

SidesMatch _matchWithoutReference(SideText front, SideText back) {
  // A licence MRZ on one side, its number printed on the other: the Dutch
  // licence's back and front.
  bool printsOthersLicence(SideText side, SideText other) => [?other.mrz?.licenceData].any(side._printsPartOf);
  if (printsOthersLicence(front, back) || printsOthersLicence(back, front)) return SidesMatch.same;

  final licenceExpiry = front.licence?.dateOfExpiry;
  if (licenceExpiry != null && back._licenceBack && back.shows(licenceExpiry)) return SidesMatch.same;

  final sharesNumber = front.vizNumbers.intersection(back.vizNumbers).isNotEmpty;
  final sharedDates = {for (final date in front.vizDates.where(back.shows)) _eitherOrderKey(date)};
  final sharesDates = sharedDates.length >= _minSharedDates;
  return sharesNumber || sharesDates ? SidesMatch.same : SidesMatch.unknown;
}

/// The same day, whatever its century: an MRZ and many licences give the
/// year in two digits.
bool _sameDay(DateTime a, DateTime b) => _dayKey(a) == _dayKey(b);

int _dayKey(DateTime date) => (date.year % 100) * 10000 + date.month * 100 + date.day;

/// One printed date read day first and month first is still one date.
int _eitherOrderKey(DateTime date) {
  final (low, high) = date.month < date.day ? (date.month, date.day) : (date.day, date.month);
  return (date.year % 100) * 10000 + low * 100 + high;
}

bool _shows(Set<DateTime> dates, DateTime date) => dates.any((shown) => _sameDay(shown, date));

String _plain(String line) => line.toUpperCase().split('').map((c) => _plainLetters[c] ?? c).join();

/// Text recognition drops spaces between words: "CARTENATIONALE DIDENTITE".
final _titleGaps = RegExp(r"[\s'\-]");
final _compactTitles = {for (final MapEntry(:key, :value) in _titles.entries) key.replaceAll(_titleGaps, ''): value};

DocumentType? _titleIn(String line) {
  final compact = line.replaceAll(_titleGaps, '');
  for (final MapEntry(key: title, value: type) in _compactTitles.entries) {
    if (compact.contains(title)) return type;
  }
  return null;
}

LicenceFields? _licenceFieldsIn(List<String> lines) {
  String? number;
  DateTime? birth;
  DateTime? expiry;
  final labels = <String>{};
  for (final (label, value) in _licenceFieldValues(lines)) {
    switch (label) {
      case '3':
        birth ??= _firstDateIn(value);
      case '4B':
        final date = _firstDateIn(value);
        if (date == null) continue;
        expiry ??= date;
      case '4D' || '5':
        final candidate = _licenceNumberIn(value);
        if (candidate == null) continue;
        number ??= candidate;
    }
    if (label.startsWith('4')) labels.add(label);
  }

  if (number == null && birth == null && expiry == null && labels.isEmpty) return null;
  return (number: number, dateOfBirth: birth, dateOfExpiry: expiry, labels: labels.length);
}

/// A field's value runs to the next label on its line or, when it has
/// none there, is the next line.
Iterable<(String label, String value)> _licenceFieldValues(List<String> lines) sync* {
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    final fields = _licenceField.allMatches(line).toList();
    for (var f = 0; f < fields.length; f++) {
      final last = f + 1 == fields.length;
      var value = line.substring(fields[f].end, last ? line.length : fields[f + 1].start).trim();
      if (value.isEmpty && last && i + 1 < lines.length) value = lines[i + 1].trim();
      if (value.isNotEmpty) yield (fields[f][1]!.replaceAll(RegExp(r'[()]'), ''), value);
    }
  }
}

DateTime? _firstDateIn(String value) => _datesIn(value).firstOrNull?.firstOrNull;

String? _licenceNumberIn(String value) =>
    _datesIn(value).isNotEmpty ? null : _tokensIn(value).where(_looksLikeNumber).firstOrNull;

/// The words in [line], and the whole line without its spaces: text
/// recognition can put a space in a number.
List<String> _tokensIn(String line) => [..._token.allMatches(line).map((m) => m[0]!), line.replaceAll(' ', '')];

bool _looksLikeNumber(String token) =>
    token.length >= _minNumberLength &&
    token.length <= _maxNumberLength &&
    _digit.hasMatch(token) &&
    _alphanumeric.hasMatch(token);

String _matchKey(String number) =>
    number.toUpperCase().replaceAll('<', '').split('').map((c) => _lookalikes[c] ?? c).join();

/// The dates printed in [line], each as all its readings: day or month
/// first, either century of a two-digit year. Matching against the
/// document's dates picks the one.
Iterable<List<DateTime>> _datesIn(String line) => [
  ..._yearFirstDatesIn(line),
  ..._dayFirstDatesIn(line),
  ..._namedMonthDatesIn(line),
];

Iterable<List<DateTime>> _yearFirstDatesIn(String line) sync* {
  for (final m in _yearFirstDate.allMatches(line)) {
    final date = _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (date != null) yield [date];
  }
}

Iterable<List<DateTime>> _dayFirstDatesIn(String line) sync* {
  for (final m in _dayFirstDate.allMatches(line)) {
    final (first, firstGap, second, secondGap, year) = (m[1]!, m[2]!, m[3]!, m[4]!, m[5]!);
    // One gap may be lost, between two digits each: "1505 1975", not "12345678".
    if (firstGap.isEmpty && (secondGap.isEmpty || first.length < 2 || second.length < 2)) continue;
    if (secondGap.isEmpty && (second.length < 2 || year.length < 4)) continue;
    final readings = <DateTime>{
      for (final y in _years(year)) ...[
        ?_date(y, int.parse(second), int.parse(first)),
        ?_date(y, int.parse(first), int.parse(second)),
      ],
    };
    if (readings.isNotEmpty) yield readings.toList();
  }
}

Iterable<List<DateTime>> _namedMonthDatesIn(String line) sync* {
  for (final m in _namedMonthDate.allMatches(line)) {
    final month = m[2]!.split(_monthSeparator).map(_month).nonNulls.firstOrNull;
    if (month == null) continue;
    final readings = [for (final y in _years(m[3]!)) ?_date(y, month, int.parse(m[1]!))];
    if (readings.isNotEmpty) yield readings;
  }
}

Iterable<int> _years(String year) =>
    year.length == 4 ? [int.parse(year)] : _twoDigitYearCenturies.map((century) => century + int.parse(year));

int? _month(String name) {
  final word = name.trim().replaceAll('.', '');
  if (word.length < 3) return null;
  return _months[word] ?? (word.length >= 4 ? _months[word.substring(0, 4)] : null) ?? _months[word.substring(0, 3)];
}

/// Null for a day the month doesn't have.
DateTime? _date(int year, int month, int day) {
  if (year < _minYear || year > _maxYear || month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  return date.day == day ? date : null;
}
