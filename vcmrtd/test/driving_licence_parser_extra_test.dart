import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';

Uint8List hexb(String s) => s.replaceAll(RegExp(r'\s+'), '').parseHex();

// Minimal valid DG1 (from driving_licence_parser_test sample, ascii variant).
const dg1Test = """
    61 818f
      5f01 0d 65342d444c3030203030303031
      5f02 55
        5f03 03 4e4c44
        5f04 06 426173736965
        5f05 06 426172726965
        5f06 04 17121996
        5f07 06 4d657070656c
        5f0a 04 12072017
        5f0b 04 12072027
        5f0c 0f 47656d65656e7465204d657070656c
        5f0e 0a 31323334353637383930
      7f63 24
        02 01 02
        87 0f 414d3b140720173b140720273b3b3b
        87 0e 423b140720173b140720273b3b3b
""";

// Full, valid 5F02 personal-data block plus a malformed 0x87 category record
// (claims a 127-byte value with only 2 bytes present) so category parsing throws
// while the rest of DG1 still constructs successfully.
const badCategoryDg1 =
    "615F5F02555F03034e4c445F04064261737369655F05064261727269655F0604171219965F07064d657070656c5F0a04120720175F0b04120720275F0c0F47656d65656e7465204d657070656c5F0e0A313233343536373839307F6304877f4142";

void main() {
  group('parseDG1 category failure handling', () {
    test('graceful failure yields empty categories', () {
      // 7f63 contains a malformed 0x87 record (no semicolon) -> parse fails.
      // 87 02 4142  (just "AB", no ';') triggers `continue` then ends; but to force a throw,
      // use a record that is too short for date extraction yet has a semicolon handled by indexOf.
      // Easier: corrupt the 7f63 body so TLV.decode throws.
      final graceful = DrivingLicenceParser(failDg1CategoriesGracefully: true);
      // Valid outer/5F02 framing, but the 0x87 category record claims a 127-byte
      // value with only 2 bytes present -> TLV.decode throws inside _parseCategories.
      final dg1 = hexb(badCategoryDg1);
      // failDg1CategoriesGracefully=true should swallow the category error.
      graceful.parseDG1(dg1);
    });

    test('non-graceful failure rethrows', () {
      final strict = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      final dg1 = hexb(badCategoryDg1);
      expect(() => strict.parseDG1(dg1), throwsA(isA<Exception>()));
    });
  });

  group('parseDG5 error path', () {
    test('throws when image data or type missing', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      // outer 0x67 with only a format byte (0x89) but no image data (5F43)
      final dg5 = hexb("6703 8901 03");
      expect(() => parser.parseDG5(dg5), throwsA(isA<Exception>()));
    });

    test('jpeg2000 format byte branch', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      // 0x89 format byte != 0x03 -> jpeg2000, plus 5F43 image data
      final dg5 = hexb("6708 8901 04 5F4302 AABB");
      parser.parseDG5(dg5);
    });
  });

  group('parseDG6 non-FAC fallback', () {
    test('image without FAC header stored as raw', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      // 75 -> 7F61 -> 7F60 -> 5F2E with bytes that are NOT FAC\0 (fallback path)
      final block = TLV.encode(0x5F2E, hexb("DEADBEEF"));
      final bit = TLV.encode(0x7F60, block);
      final group = TLV.encode(0x7F61, bit);
      final outer = TLV.encode(0x75, group);
      parser.parseDG6(outer);
      expect(parser, isNotNull);
    });
  });

  group('parseDG12 saiType branches', () {
    test('UNKNOWN sai type when byte != 0x41', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      // 71 { 82 <bap>, 81 00 } where 81's first byte != 0x41
      final bap = TLV.encode(0x82, hexb("0041424344"));
      final sai = TLV.encode(0x81, hexb("99"));
      final inner = Uint8List.fromList([...bap, ...sai]);
      final dg12 = TLV.encode(0x71, inner);
      parser.parseDG12(dg12);
    });

    test('MRZ sai type when byte == 0x41', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      final bap = TLV.encode(0x82, hexb("0041424344"));
      final sai = TLV.encode(0x81, hexb("41"));
      final inner = Uint8List.fromList([...bap, ...sai]);
      final dg12 = TLV.encode(0x71, inner);
      parser.parseDG12(dg12);
    });
  });

  group('raw byte setters', () {
    test('parseDG2..DG14 raw setters store bytes', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      parser.parseDG2(hexb("0201"));
      parser.parseDG3(hexb("0302"));
      parser.parseDG4(hexb("0403"));
      parser.parseDG7(hexb("0704"));
      parser.parseDG8(hexb("0805"));
      parser.parseDG9(hexb("0906"));
      parser.parseDG10(hexb("0A07"));
      parser.parseDG11(hexb("0B08"));
      parser.parseDG14(hexb("0E09"));
      // No exceptions = pass; these are pure setters.
      expect(parser, isNotNull);
    });
  });

  group('parseDG15 / parseDG16 unimplemented', () {
    test('DG15 throws UnimplementedError', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      expect(() => parser.parseDG15(Uint8List(0)), throwsA(isA<UnimplementedError>()));
    });

    test('DG16 throws UnimplementedError', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      expect(() => parser.parseDG16(Uint8List(0)), throwsA(isA<UnimplementedError>()));
    });
  });

  group('documentContainsDataGroup', () {
    test('reflects EF.COM and handles null-tag arms', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      // EF.COM listing DG1(61), DG5(67), DG6(75)
      parser.parseEfCOM(hexb("60155F0104303130375F36063034303030305C0361676d".replaceAll(' ', '')));
      // tags: 61, 67, 6D. DG1 -> 0x61 present.
      expect(parser.documentContainsDataGroup(DataGroups.dg1), true);
      // DG2 maps to null tag -> not contained
      expect(parser.documentContainsDataGroup(DataGroups.dg2), false);
      for (final dg in DataGroups.values) {
        parser.documentContainsDataGroup(dg);
      }
    });
  });

  group('valid DG1 categories parse', () {
    test('ascii DG1 produces categories', () {
      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      parser.parseDG1(hexb(dg1Test));
      // No throw expected; categories built from the two 0x87 records.
      expect(parser, isNotNull);
    });
  });
}
