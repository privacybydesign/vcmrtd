import '../custom/custom_logger_extension.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

/// ICAO 9303 MRZ helper:
/// - Normalizes lines to the MRZ character set: A-Z 0-9 <
/// - Detects TD1 (3×30), TD2 (2×36), TD3 (2×44), Driver's Licence
/// - Post-corrects field types (numeric vs alpha) per document type
class MRZHelper {
  static const _mrzChar = r'[A-Z0-9<]';
  static final _mrzCharRe = RegExp('^$_mrzChar\$');
  static final _allowedLineLen = <int>{30, 36, 44};

  // ==========================================================================
  // NORMALIZATION
  // ==========================================================================

  /// Normalize one OCR line into an MRZ line candidate.
  /// Used by the Tesseract pipeline.
  /// Returns '' if the line length is not a valid MRZ length (30/36/44).
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

  /// Normalize one OCR line into an MRZ line candidate.
  /// Used by the Google ML Kit pipeline (preserves original behaviour).
  /// Returns '' if the line length is not a valid MRZ length (30/36/44).
  static String testTextLine(String text) {
    String res = text.replaceAll(' ', '');
    List<String> list = res.split('');

    if (list.length != 44 && list.length != 30 && list.length != 36) {
      return '';
    }

    for (int i = 0; i < list.length; i++) {
      if (RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i])) {
        list[i] = list[i].toUpperCase();
      }
      if (double.tryParse(list[i]) == null && !(RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i]))) {
        list[i] = '<';
      }
    }
    return list.join('');
  }

  // ==========================================================================
  // SHAPE DETECTION
  // ==========================================================================

  /// Returns the lines if they match a supported MRZ shape, null otherwise.
  static List<String>? getFinalListToParse(List<String> lines) {
    if (lines.isEmpty) return null;
    final l = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (l.isEmpty) return null;

    // Driver's licence: starts with D1, D2, or DL
    final first = l.first;
    if (first.length >= 2) {
      final pfx = first.substring(0, 2);
      if (pfx == 'D1' || pfx == 'D2' || pfx == 'DL') {
        "Driver's License MRZ detected".logInfo();
        return [...l];
      }
    }

    // Passport / visa / ID requires at least 2 lines of equal length
    if (l.length < 2) return null;

    final len = l.first.length;
    if (!l.every((e) => e.length == len)) return null;

    final fChar = l.first[0];
    if (['P', 'V', 'I'].contains(fChar)) {
      if (fChar == 'I') {
        'Identity Card MRZ detected'.logInfo();
      } else {
        'Passport or Visa MRZ detected'.logInfo();
      }
      return [...l];
    }

    // Fallback: exact ICAO shapes without doc-type prefix match
    if (l.length == 3 && len == 30) return [...l]; // TD1
    if (l.length == 2 && len == 36) return [...l]; // TD2
    if (l.length == 2 && len == 44) return [...l]; // TD3

    return null;
  }

  // ==========================================================================
  // FIXER — corrects common OCR letter↔digit misreads
  // ==========================================================================

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

  /// Attempts to fix OCR misreads in [lines] for the given [docType].
  /// Returns corrected lines, or null if the lines cannot be corrected.
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
    if (lines.length != 2 || lines[0].length != 44 || lines[1].length != 44) {
      return null;
    }

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
    final names = _digitsToLetters(l3);

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

    return [fixedL1, fixedL2, names];
  }
}
