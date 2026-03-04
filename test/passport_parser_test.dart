import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';

void main() {
  group('DG11 parsing', () {
    test('valid DG11 parses successfully', () {
      final parser = PassportParser();
      parser.parseDG11(parseTestCase(validDg11));
    });

    test('invalid DG11 tag throws EfParseError', () {
      final parser = PassportParser();
      expect(() => parser.parseDG11(parseTestCase(invalidDg11Tag)), throwsA(isA<EfParseError>()));
    });

    test('invalid DG11 missing tag list throws EfParseError', () {
      final parser = PassportParser();
      expect(() => parser.parseDG11(parseTestCase(invalidDg11MissingTagList)), throwsA(isA<EfParseError>()));
    });

    test('empty bytes throws error', () {
      final parser = PassportParser();
      expect(() => parser.parseDG11(Uint8List(0)), throwsA(anything));
    });
  });

  group('DG12 parsing', () {
    test('invalid DG12 tag throws EfParseError', () {
      final parser = PassportParser();
      expect(() => parser.parseDG12(parseTestCase(invalidDg12Tag)), throwsA(isA<EfParseError>()));
    });
  });
}

String removeWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), '');
}

Uint8List parseTestCase(String test) {
  return removeWhitespace(test).parseHex();
}

// Valid DG11 with nameOfHolder "John"
// 6B = DG11 tag
// 0B = length (11 bytes)
// 5C 02 5F0E = tag list (tag 5C, len 2, contains tag 5F0E)
// 5F0E 04 4A6F686E = name field (tag 5F0E, len 4, "John")
const validDg11 = "6B0B5C025F0E5F0E044A6F686E";

// Invalid DG11 - wrong outer tag (AA instead of 6B)
const invalidDg11Tag = "AA0B5C025F0E5F0E044A6F686E";

// Invalid DG11 - missing tag list (AA instead of 5C)
const invalidDg11MissingTagList = "6B0BAA025F0E5F0E044A6F686E";

// Invalid DG12 - wrong outer tag (BB instead of 6C)
// 6C = DG12 tag, but using BB
const invalidDg12Tag = "BB0A5C025F195F190454455354";
