import 'package:flutter_test/flutter_test.dart';
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
        final input = [
          'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
          'L898902C36UTO7408122F1204159ZE184226B<<<<<10'
        ];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize visa MRZ (V)', () {
        // TD3 format: 2 lines, 44 characters each
        final input = [
          'V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
          'L898902C36UTO7408122F1204159ZE184226B<<<<<10'
        ];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });

      test('should recognize identity card MRZ (I)', () {
        // TD1 format: 3 lines, 30 characters each
        final input = [
          'I<UTOD231458907<<<<<<<<<<<<',
          '7408122F1204159UTO<<<<<<<<6',
          'ERIKSSON<<ANNA<MARIA<<<<<<<'
        ];
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
          'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<',  // 44 chars
          'L898902C<3UTO6908061F9406236ZE184226B<<<'    // 43 chars (different!)
        ];
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNull);
      });

      test('should accept multiple lines with same length', () {
        // TD3 format: 2 lines, both 44 characters
        final input = [
          'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
          'L898902C36UTO7408122F1204159ZE184226B<<<<<10'
        ];
        expect(input[0].length, equals(44), reason: 'Line 1 should be 44 chars');
        expect(input[1].length, equals(44), reason: 'Line 2 should be 44 chars');
        final result = MRZHelper.getFinalListToParse(input);
        expect(result, isNotNull);
        expect(result, equals(input));
      });
    });

  });
}
