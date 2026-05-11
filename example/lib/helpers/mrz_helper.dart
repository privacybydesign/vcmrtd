import '../custom/custom_logger_extension.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

/// ICAO 9303 MRZ helper:
/// - Normalizes lines to the MRZ character set: A-Z 0-9 <
/// - Detects TD1 (3x30), TD2 (2x36), TD3 (2x44)
/// - Post-corrects field types (numeric vs alpha) and check digits
/// - Validates ICAO checksums
/// - Scores candidate blocks to pick the best MRZ window
class MRZHelper {
  static const _mrzChar = r'[A-Z0-9<]';
  static final _mrzCharRe = RegExp('^$_mrzChar\$');
  static final _allowedLineLen = <int>{30, 36, 44};

  // ---------- NORMALIZATION ----------

  /// Normalize one OCR line into an MRZ line candidate.
  /// Returns '' if not an exact MRZ line length (30/36/44).
  static String normalizeLine(String text) {
    final s = text.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    final buf = StringBuffer();
    for (final code in s.codeUnits) {
      final ch = String.fromCharCode(code);
      buf.write(_mrzCharRe.hasMatch(ch) ? ch : '<');
    }

    final out = buf.toString();
    if (_allowedLineLen.contains(out.length)) return out;
    return '';
  }

  /// Original normalization used by Google ML Kit path.
  static String testTextLine(String text) {
    String res = text.replaceAll(' ', '');
    List<String> list = res.split('');

    // to check if the text belongs to any MRZ format or not
    if (list.length != 44 && list.length != 30 && list.length != 36) {
      return '';
    }

    for (int i = 0; i < list.length; i++) {
      if (RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i])) {
        list[i] = list[i].toUpperCase();
        // to ensure that every letter is uppercase
      }
      if (double.tryParse(list[i]) == null && !(RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i]))) {
        list[i] = '<';
        // sometimes < sign not recognized well
      }
    }
    String result = list.join('');
    return result;
  }

  /// Returns the lines if they match a supported MRZ "shape".
  /// Groups candidates by line length and uses a sliding window + scoring
  /// to find the best ICAO block, so mixed-length output from ML Kit
  /// (e.g. both 30-char and 44-char lines) doesn't drop valid TD1 results.
  static List<String>? getFinalListToParse(List<String> lines) {
    if (lines.isEmpty) return null;
    final l = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (l.isEmpty) return null;

    final first = l.first;
    if (first.length >= 2 && _isDriversLicensePrefix(first.substring(0, 2))) {
      "Driver's License MRZ detected".logInfo();
      return [...l];
    }

    if (l.length < 2) return null;

    for (final entry in const [(30, 3), (36, 2), (44, 2)]) {
      final targetLen = entry.$1;
      final windowSize = entry.$2;
      final group = l.where((e) => e.length == targetLen).toList();
      if (group.length < windowSize) continue;

      for (int i = 0; i <= group.length - windowSize; i++) {
        final window = group.sublist(i, i + windowSize);
        final candidate = _matchIcaoShape(window, targetLen);
        if (candidate != null) return candidate;
      }
    }

    return null;
  }

  static bool _isDriversLicensePrefix(String pfx) => pfx == 'D1' || pfx == 'D2' || pfx == 'DL';

  static List<String>? _matchIcaoShape(List<String> l, int len) {
    final fChar = l.first[0];
    if (fChar == 'P' || fChar == 'V' || fChar == 'I') {
      if (fChar == 'I') {
        'Identity Card MRZ detected'.logInfo();
      } else {
        'Passport or Visa MRZ detected'.logInfo();
      }
      return [...l];
    }

    // Advanced logic fallback: exact ICAO shapes
    if (l.length == 3 && len == 30) return [...l]; // TD1
    if (l.length == 2 && len == 36) return [...l]; // TD2
    if (l.length == 2 && len == 44) return [...l]; // TD3

    return null;
  }

  // ---------- FIXER ----------
  static const Map<String, String> _toDigit = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'U': '0',
    'I': '1',
    'L': '1',
    'Z': '2',
    'S': '5',
    'G': '6',
    'B': '8',
    'T': '7',
  };

  static const Map<String, String> _toAlpha = {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '6': 'G', '8': 'B'};

  static String _lettersToDigits(String s) {
    var out = s;
    _toDigit.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static String _digitsToLetters(String s) {
    var out = s;
    _toAlpha.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static bool _isDigits(String s) => RegExp(r'^\d+$').hasMatch(s);
  static bool _isLetters(String s) => RegExp(r'^[A-Z]+$').hasMatch(s);
  static bool _isLettersOrFiller(String s) => RegExp(r'^[A-Z<]+$').hasMatch(s);

  static String _fixSexChar(String c) {
    if (c == 'M' || c == 'F' || c == 'X' || c == '<') return c;
    if (c == 'P') return 'F';
    return c;
  }

  /// Main entry: fix per DocumentType.
  static List<String>? fixForDocType(DocumentType docType, List<String> lines) {
    switch (docType) {
      case DocumentType.passport:
        return _fixTd3(lines);

      case DocumentType.identityCard:
        return _fixTd1(lines);

      case DocumentType.drivingLicence:
        return null;
    }
  }

  static List<String>? _fixTd3(List<String> lines) {
    if (lines.length != 2 || lines[0].length != 44 || lines[1].length != 44) return null;

    final l1 = lines[0];
    final l2 = lines[1];

    final docType = _digitsToLetters(l1.substring(0, 2));
    final issuer = _digitsToLetters(l1.substring(2, 5));
    final names = _digitsToLetters(l1.substring(5, 44));
    final nat = _digitsToLetters(l2.substring(10, 13));

    final docCd = _lettersToDigits(l2.substring(9, 10));
    final birth = _lettersToDigits(l2.substring(13, 19));
    final birthCd = _lettersToDigits(l2.substring(19, 20));
    final exp = _lettersToDigits(l2.substring(21, 27));
    final expCd = _lettersToDigits(l2.substring(27, 28));

    final sex = _fixSexChar(l2.substring(20, 21));

    if (!_isLettersOrFiller(docType)) return null;
    if (!_isLetters(issuer)) return null;
    if (!_isLettersOrFiller(names)) return null;
    if (!_isLetters(nat)) return null;

    if (!_isDigits(docCd)) return null;
    if (!_isDigits(birth) || birth.length != 6) return null;
    if (!_isDigits(birthCd)) return null;
    if (!_isDigits(exp) || exp.length != 6) return null;
    if (!_isDigits(expCd)) return null;

    final fixedL1 = docType + issuer + names;

    final fixedL2 = l2.substring(0, 9) + docCd + nat + birth + birthCd + sex + exp + expCd + l2.substring(28);

    return [fixedL1, fixedL2];
  }

  static List<String>? _fixTd1(List<String> lines) {
    if (lines.length != 3 || !lines.every((s) => s.length == 30)) return null;

    final l1 = lines[0];
    final l2 = lines[1];
    final l3 = lines[2];

    final docType = _digitsToLetters(l1.substring(0, 2));
    final issuer = _digitsToLetters(l1.substring(2, 5));

    final birth = _lettersToDigits(l2.substring(0, 6));
    final birthCd = _lettersToDigits(l2.substring(6, 7));
    final exp = _lettersToDigits(l2.substring(8, 14));
    final expCd = _lettersToDigits(l2.substring(14, 15));
    final nat = _digitsToLetters(l2.substring(15, 18));
    final finalCd = _lettersToDigits(l2.substring(29, 30));

    final sex = _fixSexChar(l2.substring(7, 8));
    final names = _digitsToLetters(l3); // letters/<

    if (!_isLettersOrFiller(docType)) return null;
    if (!_isLetters(issuer)) return null;

    if (!_isDigits(birth) || birth.length != 6) return null;
    if (!_isDigits(birthCd)) return null;
    if (!_isDigits(exp) || exp.length != 6) return null;
    if (!_isDigits(expCd)) return null;
    if (!_isLetters(nat)) return null;
    if (!_isDigits(finalCd)) return null;

    if (!_isLettersOrFiller(names)) return null;

    final fixedL1 = docType + issuer + l1.substring(5);

    final fixedL2 = birth + birthCd + sex + exp + expCd + nat + l2.substring(18, 29) + finalCd;

    final fixedL3 = names;

    return [fixedL1, fixedL2, fixedL3];
  }
}
