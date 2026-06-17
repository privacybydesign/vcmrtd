import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';

String removeWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), '');
}

Uint8List hexb(String test) {
  return removeWhitespace(test).parseHex();
}

Uint8List cat(List<Uint8List> parts) {
  final b = <int>[];
  for (final p in parts) {
    b.addAll(p);
  }
  return Uint8List.fromList(b);
}

Uint8List tlv(int tag, Uint8List value) => TLV.encode(tag, value);

// Valid TD3 MRZ (from ICAO test vector). Wrapped as DG1: 61 <len> 5F1F <len> <mrz>
const validMrz = "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10";

Uint8List buildDG1(String mrz) {
  final mrzBytes = Uint8List.fromList(mrz.codeUnits);
  final inner = TLV.encode(0x5F1F, mrzBytes);
  return TLV.encode(0x61, inner);
}

// A valid DG2 with a minimal FAC record (constructed by hand from the parser layout).
const validDg2 =
    "75427F613F0201017F6039A104800201015F2E3046414300303130000000003000010000002800000000000000000000000000000000000000010002000000000000AABB";

// A valid AAPublicKey DER (SubjectPublicKeyInfo) used inside DG15 (tag 6F).
const validAaPubKeyDer = "301A300D06092A864886F70D0101010500030B0030090202C1D30203010001";

void main() {
  group('parseDG1', () {
    test('valid DG1 parses MRZ', () {
      final parser = PassportParser();
      final dg1 = parser.parseDG1(buildDG1(validMrz));
      expect(dg1, isNotNull);
      expect(dg1!.mrz.lastName, 'ERIKSSON');
      expect(dg1.mrz.documentNumber, 'L898902C3');
    });

    test('wrong outer tag throws EfParseError', () {
      final parser = PassportParser();
      // Replace outer 0x61 with 0x62
      final bad = buildDG1(validMrz);
      bad[0] = 0x62;
      expect(() => parser.parseDG1(bad), throwsA(isA<EfParseError>()));
    });

    test('wrong MRZ tag throws EfParseError', () {
      final parser = PassportParser();
      final mrzBytes = Uint8List.fromList(validMrz.codeUnits);
      // Use tag 0x5F20 instead of 0x5F1F
      final inner = TLV.encode(0x5F20, mrzBytes);
      final bytes = TLV.encode(0x61, inner);
      expect(() => parser.parseDG1(bytes), throwsA(isA<EfParseError>()));
    });
  });

  group('parseDG2', () {
    test('valid DG2 with FAC header parses', () {
      final parser = PassportParser();
      parser.parseDG2(hexb(validDg2));
    });

    test('valid DG2 with alternate biometric tag 7F2E parses', () {
      final parser = PassportParser();
      // Replace the 5F2E block tag with 7F2E. The block sits right after the BHT.
      final bytes = hexb(validDg2);
      final hex = validDg2.toUpperCase();
      final idx = hex.indexOf("5F2E") ~/ 2;
      bytes[idx] = 0x7F;
      bytes[idx + 1] = 0x2E;
      parser.parseDG2(bytes);
    });

    test('wrong DG2 outer tag throws EfParseError', () {
      final parser = PassportParser();
      final bytes = hexb(validDg2);
      bytes[0] = 0x76;
      expect(() => parser.parseDG2(bytes), throwsA(isA<EfParseError>()));
    });

    test('wrong BIGT tag throws EfParseError', () {
      final parser = PassportParser();
      // BIGT tag (7F61) should be wrong. Build with tag 7F62.
      final bigtBad = TLV.encode(0x7F62, hexb("0201017F6005A1038001015F2E0146"));
      final dg2 = TLV.encode(0x75, bigtBad);
      expect(() => parser.parseDG2(dg2), throwsA(isA<EfParseError>()));
    });

    test('wrong count tag throws EfParseError', () {
      final parser = PassportParser();
      // BICT count tag should be 0x02. Use 0x03 instead.
      final bigt = TLV.encode(0x7F61, hexb("030101"));
      final dg2 = TLV.encode(0x75, bigt);
      expect(() => parser.parseDG2(dg2), throwsA(isA<EfParseError>()));
    });

    test('bad FAC header throws EfParseError', () {
      final parser = PassportParser();
      // 48-byte FAC but first 4 bytes are not FAC\0
      final bytes = hexb(validDg2);
      final hex = validDg2.toUpperCase();
      final facStart = (hex.indexOf("46414300") ~/ 2);
      bytes[facStart] = 0x00; // break FAC header
      expect(() => parser.parseDG2(bytes), throwsA(isA<EfParseError>()));
    });

    test('bad version throws EfParseError', () {
      final parser = PassportParser();
      final bytes = hexb(validDg2);
      final hex = validDg2.toUpperCase();
      final verStart = (hex.indexOf("30313000") ~/ 2);
      bytes[verStart] = 0x31; // corrupt version
      expect(() => parser.parseDG2(bytes), throwsA(isA<EfParseError>()));
    });

    test('biometric data block too short throws EfParseError', () {
      final parser = PassportParser();
      // FAC block with only 2 bytes (< 4) under 5F2E
      final block = tlv(0x5F2E, hexb("4641"));
      final bhtAndBlock = cat([tlv(0xA1, hexb("800101")), block]);
      final bit = tlv(0x7F60, bhtAndBlock);
      final bigt = tlv(0x7F61, cat([hexb("020101"), bit]));
      final dg2 = tlv(0x75, bigt);
      expect(() => parser.parseDG2(dg2), throwsA(isA<EfParseError>()));
    });

    test('wrong biometric data block tag throws EfParseError', () {
      final parser = PassportParser();
      // Use tag 5F2F (neither 5F2E nor 7F2E) for the data block
      final block = tlv(
        0x5F2F,
        hexb("46414300303130000000003000010000002800000000000000000000000000000000000000010002000000000000AABB"),
      );
      final bhtAndBlock = cat([tlv(0xA1, hexb("800101")), block]);
      final bit = tlv(0x7F60, bhtAndBlock);
      final bigt = tlv(0x7F61, cat([hexb("020101"), bit]));
      final dg2 = tlv(0x75, bigt);
      expect(() => parser.parseDG2(dg2), throwsA(isA<EfParseError>()));
    });
  });

  group('parseDG11 field branches', () {
    PassportParser parseFields(String tagListHex, String fieldsHex) {
      final parser = PassportParser();
      final content = cat([tlv(0x5C, hexb(tagListHex)), hexb(fieldsHex)]);
      final dg11 = tlv(0x6B, content);
      parser.parseDG11(dg11);
      return parser;
    }

    test('otherNames, personalNumber, telephone, profession, title', () {
      // 5F0F otherName "AB", 5F10 personal number "123", 5F12 phone "9", 5F13 prof "X", 5F14 title "Y"
      final parser = parseFields("5F0F5F105F125F135F14", "5F0F024142 5F1003313233 5F120139 5F130158 5F140159");
      expect(parser, isNotNull);
    });

    test('fullDateOfBirth as 4-byte BCD', () {
      final parser = parseFields("5F2B", "5F2B0419901231");
      expect(parser, isNotNull);
    });

    test('fullDateOfBirth as ascii (8 bytes)', () {
      // "19901231" as ascii bytes
      final parser = parseFields("5F2B", "5F2B083139393031323331");
      expect(parser, isNotNull);
    });

    test('placeOfBirth, permanentAddress', () {
      final parser = parseFields("5F115F42", "5F11024142 5F4203434445");
      expect(parser, isNotNull);
    });

    test('personalSummary, proofOfCitizenship, otherValidTDNumbers, custodyInformation', () {
      // 5F15 "HI", 5F16 raw AABB, 5F17 "CDE", 5F18 "J"
      final parser = parseFields("5F155F165F175F18", "5F1502 4849 5F1602 AABB 5F1703 434445 5F1801 4A");
      expect(parser, isNotNull);
    });

    test('full date of birth ascii via createDocument round-trips', () {
      final parser = PassportParser();
      // build full passport so createDocument works
      parser.parseDG1(buildDG1(validMrz));
      parser.parseDG2(hexb(validDg2));
      final content = cat([tlv(0x5C, hexb("5F0E5F2B5F11")), hexb("5F0E044A6F686E 5F2B083139393031323331 5F11024142")]);
      parser.parseDG11(tlv(0x6B, content));
      final doc = parser.createDocument();
      expect(doc.nameOfHolder, 'John');
      expect(doc.fullDateOfBirth, DateTime(1990, 12, 31));
      expect(doc.placeOfBirth, ['AB']);
    });

    test('full date of birth BCD via createDocument', () {
      final parser = PassportParser();
      parser.parseDG1(buildDG1(validMrz));
      parser.parseDG2(hexb(validDg2));
      final content = cat([tlv(0x5C, hexb("5F2B")), hexb("5F2B0419901231")]);
      parser.parseDG11(tlv(0x6B, content));
      final doc = parser.createDocument();
      expect(doc.fullDateOfBirth, DateTime(1990, 12, 31));
    });
  });

  group('parseDG12', () {
    test('issuingAuthority + dateOfIssue ascii', () {
      final parser = PassportParser();
      // 5F19 len 3 "ABC", 5F26 len 8 "20200101"
      final fixed = cat([tlv(0x5C, hexb("5F195F26")), hexb("5F1903414243"), hexb("5F26083230323030313031")]);
      parser.parseDG12(tlv(0x6C, fixed));
      expect(parser, isNotNull);
    });

    test('dateOfIssue 4-byte BCD', () {
      final parser = PassportParser();
      final content = cat([tlv(0x5C, hexb("5F26")), hexb("5F260420200101")]);
      parser.parseDG12(tlv(0x6C, content));
      expect(parser, isNotNull);
    });

    test('DG12 via createDocument with both fields', () {
      final parser = PassportParser();
      parser.parseDG1(buildDG1(validMrz));
      parser.parseDG2(hexb(validDg2));
      final content = cat([tlv(0x5C, hexb("5F195F26")), hexb("5F1903414243"), hexb("5F260420200101")]);
      parser.parseDG12(tlv(0x6C, content));
      final doc = parser.createDocument();
      expect(doc.issuingAuthority, 'ABC');
      expect(doc.dateOfIssue, DateTime(2020, 1, 1));
    });
  });

  group('parseDG15', () {
    test('valid AAPublicKey parses', () {
      final parser = PassportParser();
      final dg15 = TLV.encode(0x6F, hexb(validAaPubKeyDer));
      parser.parseDG15(dg15);
    });

    test('wrong DG15 tag throws EfParseError', () {
      final parser = PassportParser();
      final bytes = TLV.encode(0x70, hexb(validAaPubKeyDer));
      expect(() => parser.parseDG15(bytes), throwsA(isA<EfParseError>()));
    });

    test('invalid AAPublicKey content throws EfParseError', () {
      final parser = PassportParser();
      // Inner is not a valid SubjectPublicKeyInfo (wrong outer tag 31 not 30)
      final bad = TLV.encode(0x6F, hexb("3103020100"));
      expect(() => parser.parseDG15(bad), throwsA(isA<EfParseError>()));
    });

    test('DG15 via createDocument exposes aaPublicKey', () {
      final parser = PassportParser();
      parser.parseDG1(buildDG1(validMrz));
      parser.parseDG2(hexb(validDg2));
      parser.parseDG15(TLV.encode(0x6F, hexb(validAaPubKeyDer)));
      final doc = parser.createDocument();
      expect(doc.aaPublicKey, isNotNull);
    });
  });

  group('raw byte setters and createDocument', () {
    test('parseDG3..DG10, DG13, DG14, DG16 store raw bytes', () {
      final parser = PassportParser();
      parser.parseDG1(buildDG1(validMrz));
      parser.parseDG2(hexb(validDg2));

      final b3 = hexb("0301");
      final b4 = hexb("0402");
      final b5 = hexb("0503");
      final b6 = hexb("0604");
      final b7 = hexb("0705");
      final b8 = hexb("0806");
      final b9 = hexb("0907");
      final b10 = hexb("0A08");
      final b13 = hexb("0D09");
      final b14 = hexb("0E0A");
      final b16 = hexb("100C");

      parser.parseDG3(b3);
      parser.parseDG4(b4);
      parser.parseDG5(b5);
      parser.parseDG6(b6);
      parser.parseDG7(b7);
      parser.parseDG8(b8);
      parser.parseDG9(b9);
      parser.parseDG10(b10);
      parser.parseDG13(b13);
      parser.parseDG14(b14);
      parser.parseDG16(b16);

      final doc = parser.createDocument();
      expect(doc.dg3RawBytes, b3);
      expect(doc.dg4RawBytes, b4);
      expect(doc.dg5RawBytes, b5);
      expect(doc.dg6RawBytes, b6);
      expect(doc.dg7RawBytes, b7);
      expect(doc.dg8RawBytes, b8);
      expect(doc.dg9RawBytes, b9);
      expect(doc.dg10RawBytes, b10);
      expect(doc.dg13RawBytes, b13);
      expect(doc.dg14RawBytes, b14);
      expect(doc.dg16RawBytes, b16);

      // DG2 derived fields
      expect(doc.photoImageData, hexb("AABB"));
      expect(doc.photoImageType, ImageType.jpeg);
      expect(doc.photoImageWidth, 1);
      expect(doc.photoImageHeight, 2);
      expect(doc.mrz.lastName, 'ERIKSSON');
    });
  });

  group('documentContainsDataGroup', () {
    test('reflects EF.COM tag list', () {
      final parser = PassportParser();
      // EF.COM listing DG1(61), DG2(75), DG4(76), DG12(6C)
      parser.parseEfCOM(hexb("60165F0104303130375F36063034303030305C046175766C"));
      expect(parser.documentContainsDataGroup(DataGroups.dg1), true);
      expect(parser.documentContainsDataGroup(DataGroups.dg2), true);
      expect(parser.documentContainsDataGroup(DataGroups.dg4), true);
      expect(parser.documentContainsDataGroup(DataGroups.dg12), true);
      expect(parser.documentContainsDataGroup(DataGroups.dg3), false);
      expect(parser.documentContainsDataGroup(DataGroups.dg15), false);
      // exercise the rest of the switch arms
      for (final dg in DataGroups.values) {
        parser.documentContainsDataGroup(dg);
      }
    });
  });
}
