import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;
import 'package:vcmrtdapp/helpers/mrz_helper.dart';

void main() {
  group('MRZHelper', () {
    group('getFinalListToParse', () {
      test('should return null for empty list', () {
        final result = MRZHelper.getFinalListToParse([]);
        expect(result, isNull);
      });

      test('should recognize passport MRZ (P)', () {
        // TD3 format: 2 lines, 44 characters each
        final input = ['P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<', 'L898902C36UTO7408122F1204159ZE184226B<<<<<10'];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize visa MRZ (V)', () {
        // TD3 format: 2 lines, 44 characters each
        final input = ['V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<', 'L898902C36UTO7408122F1204159ZE184226B<<<<<10'];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize identity card MRZ (I)', () {
        // TD1 format: 3 lines, 30 characters each (padded with <)
        final input = [
          'I<UTOD231458907<<<<<<<<<<<<<<<',
          '7408122F1204159UTO<<<<<<<<<<<<',
          'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
        ];
        expect(input.every((l) => l.length == 30), isTrue, reason: 'All lines must be 30 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize driving license MRZ (D1)', () {
        final input = ['D1NLD123456789<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize driving license MRZ (D2)', () {
        final input = ['D2NLD123456789<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize driving license MRZ (DL)', () {
        final input = ['DLNLD123456789<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should return null for unsupported document type', () {
        final input = ['X<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<<<'];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNull);
      });

      test('should return null for lines with different lengths', () {
        final input = [
          'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<', // 44 chars
          'L898902C<3UTO6908061F9406236ZE184226B<<<', // 43 chars (different!)
        ];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNull);
      });

      test('should accept multiple lines with same length', () {
        // TD3 format: 2 lines, both 44 characters
        final input = ['P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<', 'L898902C36UTO7408122F1204159ZE184226B<<<<<10'];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize TD2 format (2 lines of 36 characters)', () {
        final input = ['A<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<', 'L898902C36UTO740812F120415ZE1842269<'];
        expect(input.every((l) => l.length == 36), isTrue, reason: 'Both lines must be 36 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should return null for single non-drivers-license line', () {
        final input = ['P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<'];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNull);
      });
    });

    group('normalizeLine', () {
      test('returns unchanged line when already in MRZ charset (44 chars)', () {
        const line = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
        expect(line.length, 44);
        expect(MRZHelper.normalizeLine(line), line);
      });

      test('accepts lines of length 30, 36, and 44', () {
        expect(MRZHelper.normalizeLine('A' * 30), isNotEmpty);
        expect(MRZHelper.normalizeLine('A' * 36), isNotEmpty);
        expect(MRZHelper.normalizeLine('A' * 44), isNotEmpty);
      });

      test('returns empty string for lines not in {30, 36, 44}', () {
        expect(MRZHelper.normalizeLine(''), isEmpty);
        expect(MRZHelper.normalizeLine('A' * 10), isEmpty);
        expect(MRZHelper.normalizeLine('A' * 29), isEmpty);
        expect(MRZHelper.normalizeLine('A' * 31), isEmpty);
        expect(MRZHelper.normalizeLine('A' * 45), isEmpty);
      });

      test('uppercases lowercase letters', () {
        final lower = 'p${'<' * 43}';
        final result = MRZHelper.normalizeLine(lower);
        expect(result.length, 44);
        expect(result[0], 'P');
      });

      test('replaces invalid characters with <', () {
        // Replace dashes with < and verify output is all A-Z0-9<
        final withDashes = 'P-${'A' * 42}';
        final result = MRZHelper.normalizeLine(withDashes);
        expect(result.length, 44);
        expect(result[1], '<');
        expect(RegExp(r'^[A-Z0-9<]+$').hasMatch(result), isTrue);
      });

      test('removes whitespace before checking length', () {
        // A 44-char string with embedded spaces — after removing spaces it is
        // no longer 44 chars → returns empty string
        final withSpaces = 'P ${'A' * 42}';
        // 'P ' + 42 A's = 44 chars; after removing 1 space → 43 chars → ''
        expect(MRZHelper.normalizeLine(withSpaces), isEmpty);
      });
    });

    group('testTextLine', () {
      test('returns normalized 44-char line unchanged', () {
        const line = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
        final result = MRZHelper.testTextLine(line);
        expect(result.length, 44);
        expect(result, line);
      });

      test('returns empty string for wrong lengths', () {
        expect(MRZHelper.testTextLine(''), isEmpty);
        expect(MRZHelper.testTextLine('SHORT'), isEmpty);
        expect(MRZHelper.testTextLine('A' * 43), isEmpty);
        expect(MRZHelper.testTextLine('A' * 45), isEmpty);
      });

      test('uppercases alphabetic characters', () {
        final lower = 'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<';
        expect(lower.length, 44);
        final result = MRZHelper.testTextLine(lower);
        expect(result, 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<');
      });

      test('replaces non-alphanumeric characters with <', () {
        final withDashes = 'P-UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
        expect(withDashes.length, 44);
        final result = MRZHelper.testTextLine(withDashes);
        expect(result[1], '<');
        expect(RegExp(r'^[A-Z0-9<._]+$').hasMatch(result), isTrue);
      });

      test('accepts 30-char TD1 lines', () {
        const line = 'I<UTOD231458907<<<<<<<<<<<<<<<';
        expect(line.length, 30);
        expect(MRZHelper.testTextLine(line), isNotEmpty);
      });
    });

    group('fixForDocType — passport (TD3)', () {
      const td3Line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const td3Line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

      test('returns two 44-char fixed lines for valid input', () {
        final result = MRZHelper.fixForDocType(DocumentType.passport, [td3Line1, td3Line2]);
        expect(result, isNotNull);
        expect(result!.length, 2);
        expect(result[0].length, 44);
        expect(result[1].length, 44);
      });

      test('auto-corrects digit→letter OCR error in docType field', () {
        // '0' in position 2 of l1 → corrected to 'O' via _digitsToLetters
        final l1 = 'P<0TOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
        expect(l1.length, 44);
        final result = MRZHelper.fixForDocType(DocumentType.passport, [l1, td3Line2]);
        expect(result, isNotNull);
        expect(result![0].substring(2, 5), 'OTO');
      });

      test('auto-corrects letter→digit OCR error in birth date field', () {
        // 'B' → '8' in birth date position
        final l2 = 'L898902C36UTO740B122F1204159ZE184226B<<<<<10';
        expect(l2.length, 44);
        final result = MRZHelper.fixForDocType(DocumentType.passport, [td3Line1, l2]);
        expect(result, isNotNull);
        expect(result![1].substring(13, 19), '7408122'.substring(0, 6));
      });

      test('returns null for wrong number of lines', () {
        expect(MRZHelper.fixForDocType(DocumentType.passport, []), isNull);
        expect(MRZHelper.fixForDocType(DocumentType.passport, [td3Line1]), isNull);
        expect(MRZHelper.fixForDocType(DocumentType.passport, [td3Line1, td3Line2, td3Line1]), isNull);
      });

      test('returns null for wrong line lengths', () {
        expect(MRZHelper.fixForDocType(DocumentType.passport, ['P<UTO', 'L89890']), isNull);
      });

      test('returns null when numeric field cannot be corrected to digits', () {
        // '<' in birth date cannot be corrected (not in OCR map)
        final badL2 = 'L898902C36UTO7<08122F1204159ZE184226B<<<<<10';
        expect(badL2.length, 44);
        final result = MRZHelper.fixForDocType(DocumentType.passport, [td3Line1, badL2]);
        expect(result, isNull);
      });
    });

    group('fixForDocType — identity card (TD1)', () {
      const td1L1 = 'I<UTOD231458907<<<<<<<<<<<<<<<';
      const td1L2 = '7408122F1204159UTO<<<<<<<<<<<5';
      const td1L3 = 'ERIKSSON<<ANNA<MARIA<<<<<<<<<<';

      test('returns three 30-char fixed lines for valid input', () {
        expect(td1L1.length, 30);
        expect(td1L2.length, 30);
        expect(td1L3.length, 30);
        final result = MRZHelper.fixForDocType(DocumentType.identityCard, [td1L1, td1L2, td1L3]);
        expect(result, isNotNull);
        expect(result!.length, 3);
        expect(result.every((l) => l.length == 30), isTrue);
      });

      test('auto-corrects letter→digit OCR error in birth date', () {
        // 'B' → '8' at position 2 of l2
        final l2 = '74OB122F1204159UTO<<<<<<<<<<<5';
        expect(l2.length, 30);
        final result = MRZHelper.fixForDocType(DocumentType.identityCard, [td1L1, l2, td1L3]);
        expect(result, isNotNull);
        expect(result![1].substring(0, 6), '740812');
      });

      test('returns null for wrong number of lines', () {
        expect(MRZHelper.fixForDocType(DocumentType.identityCard, []), isNull);
        expect(MRZHelper.fixForDocType(DocumentType.identityCard, [td1L1, td1L2]), isNull);
      });

      test('returns null when lines have wrong length', () {
        final result = MRZHelper.fixForDocType(DocumentType.identityCard, ['I<UTO', '74081', 'ERIKS']);
        expect(result, isNull);
      });

      test('returns null when final composite check digit is not a digit', () {
        // Position 29 must be a digit — '<' cannot be converted
        final l2bad = '7408122F1204159UTO<<<<<<<<<<<<';
        expect(l2bad.length, 30);
        final result = MRZHelper.fixForDocType(DocumentType.identityCard, [td1L1, l2bad, td1L3]);
        expect(result, isNull);
      });
    });

    group('fixForDocType — driving licence', () {
      test('always returns null (not implemented)', () {
        expect(MRZHelper.fixForDocType(DocumentType.drivingLicence, ['D1NLD123456789<<<<<<<<<<<<<<<']), isNull);
      });
    });
  });
}
