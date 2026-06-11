import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/src/types/data.dart';
import 'package:vcmrtd/src/types/active_authentication.dart';
import 'package:vcmrtd/src/lds/df1/df1.dart';

Uint8List hexb(String s) => s.replaceAll(RegExp(r'\s+'), '').parseHex();

void main() {
  group('DataGroups enum', () {
    test('getName covers every value', () {
      expect(DataGroups.dg1.getName(), 'DG1');
      expect(DataGroups.dg16.getName(), 'DG16');
      for (final dg in DataGroups.values) {
        expect(dg.getName(), isNotEmpty);
      }
      expect(DataGroups.values.length, 16);
    });
  });

  group('DocumentType', () {
    test('documentTypeToString', () {
      expect(documentTypeToString(DocumentType.passport), 'passport');
      expect(documentTypeToString(DocumentType.drivingLicence), 'drivers_license');
      expect(documentTypeToString(DocumentType.identityCard), 'id_card');
    });

    test('stringToDocumentType round-trips', () {
      expect(stringToDocumentType('passport'), DocumentType.passport);
      expect(stringToDocumentType('drivers_license'), DocumentType.drivingLicence);
      expect(stringToDocumentType('id_card'), DocumentType.identityCard);
    });

    test('stringToDocumentType throws on unknown', () {
      expect(() => stringToDocumentType('floppy'), throwsA(isA<Exception>()));
    });

    test('displayName', () {
      expect(DocumentType.passport.displayName, 'Passport');
      expect(DocumentType.drivingLicence.displayName, 'Driving Licence');
      expect(DocumentType.identityCard.displayName, 'Identity Card');
    });
  });

  group('Exceptions', () {
    test('DMRTDException toString', () {
      final e = DMRTDException('boom');
      expect(e.message, 'boom');
      expect(e.toString(), 'DMRTDException: boom');
    });

    test('DMRTDException custom name', () {
      final e = DMRTDException('boom');
      e.exceptionName = 'CustomError';
      expect(e.toString(), 'CustomError: boom');
    });

    test('SensitiveException hides sensitive data in toString', () {
      final e = SensitiveException(nonSensitive: 'public', sensitive: 'secret');
      expect(e.toString(), contains('public'));
      expect(e.toString(), contains('OMITTED'));
      expect(e.toString(), isNot(contains('secret')));
    });

    test('SensitiveException logWithSensitiveData includes sensitive', () {
      final e = SensitiveException(nonSensitive: 'public', sensitive: 'secret');
      expect(e.logWithSensitiveData(), contains('secret'));
      expect(e.logWithSensitiveData(), contains('public'));
    });

    test('SensitiveException sensitive optional', () {
      final e = SensitiveException(nonSensitive: 'public');
      expect(e.sensitive, isNull);
      expect(e.logWithSensitiveData(), contains('null'));
    });
  });

  group('active_authentication helpers', () {
    test('NonceAndSessionId holds values', () {
      final n = NonceAndSessionId(nonce: 'abc', sessionId: 'sid');
      expect(n.nonce, 'abc');
      expect(n.sessionId, 'sid');
    });

    test('stringToUint8List decodes 8 bytes from 16 hex chars', () {
      final out = stringToUint8List('0102030405060708');
      expect(out, Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
    });

    test('stringToUint8List throws on wrong length', () {
      expect(() => stringToUint8List('0102'), throwsA(isA<ArgumentError>()));
    });
  });

  group('RawDocumentData JSON round-trip', () {
    test('populated instance survives toJson/fromJson', () {
      final original = RawDocumentData(
        dataGroups: {'DG1': 'aabb', 'DG2': 'ccdd'},
        efSod: '7700',
        sessionId: 'sess-1',
        nonce: Uint8List.fromList([0x0a, 0xff, 0x10]),
        aaSignature: Uint8List.fromList([0x01, 0x02]),
      );
      final json = original.toJson();
      expect(json['data_groups'], {'DG1': 'aabb', 'DG2': 'ccdd'});
      expect(json['ef_sod'], '7700');
      expect(json['session_id'], 'sess-1');
      expect(json['nonce'], '0aff10');
      expect(json['aa_signature'], '0102');

      final restored = RawDocumentData.fromJson(json);
      expect(restored.dataGroups, original.dataGroups);
      expect(restored.efSod, original.efSod);
      expect(restored.sessionId, original.sessionId);
      expect(restored.nonce, original.nonce);
      expect(restored.aaSignature, original.aaSignature);
    });

    test('null optional fields survive', () {
      final original = RawDocumentData(dataGroups: {}, efSod: '');
      final json = original.toJson();
      expect(json['session_id'], isNull);
      expect(json['nonce'], isNull);
      expect(json['aa_signature'], isNull);

      final restored = RawDocumentData.fromJson(json);
      expect(restored.sessionId, isNull);
      expect(restored.nonce, isNull);
      expect(restored.aaSignature, isNull);
    });

    test('Uint8ListConverter standalone', () {
      const conv = Uint8ListConverter();
      expect(conv.toJson(null), isNull);
      expect(conv.fromJson(null), isNull);
      expect(conv.toJson(Uint8List.fromList([0, 255, 16])), '00ff10');
      expect(conv.fromJson('00ff10'), Uint8List.fromList([0, 255, 16]));
    });
  });

  group('VerificationResponse JSON round-trip', () {
    test('toJson/fromJson', () {
      final original = VerificationResponse(isExpired: true, authenticChip: false, authenticContent: true);
      final json = original.toJson();
      expect(json['is_expired'], true);
      expect(json['authentic_chip'], false);
      expect(json['authentic_content'], true);

      final restored = VerificationResponse.fromJson(json);
      expect(restored.isExpired, true);
      expect(restored.authenticChip, false);
      expect(restored.authenticContent, true);
    });
  });

  group('IrmaSessionPointer JSON round-trip', () {
    test('toJson/fromJson', () {
      final original = IrmaSessionPointer(u: 'https://example/u', irmaqr: 'disclosing');
      final json = original.toJson();
      expect(json['u'], 'https://example/u');
      expect(json['irmaqr'], 'disclosing');

      final restored = IrmaSessionPointer.fromJson(json);
      expect(restored.u, original.u);
      expect(restored.irmaqr, original.irmaqr);
    });

    test('fromJson missing required key throws', () {
      expect(() => IrmaSessionPointer.fromJson({'u': 'x'}), throwsA(anything));
    });

    test('toUniversalLink builds yivi link', () {
      final p = IrmaSessionPointer(u: 'https://example/u', irmaqr: 'disclosing');
      final uri = p.toUniversalLink();
      expect(uri.scheme, 'https');
      expect(uri.host, 'open.yivi.app');
      expect(uri.toString(), contains('open.yivi.app'));
    });
  });

  group('data.dart DataRow / DataSet', () {
    test('DataRow length and toList', () {
      final row = DataRow(tag: 0x5F, value: Uint8List.fromList([0xAA, 0xBB]));
      expect(row.tag, 0x5F);
      expect(row.length, 2);
      expect(row.toList(), Uint8List.fromList([0x5F, 0x02, 0xAA, 0xBB]));
    });

    test('DataRow printHex', () {
      final row = DataRow(tag: 0x01, value: Uint8List.fromList([0x0a]));
      final s = row.printHex();
      expect(s, contains('0x01'));
      expect(s, contains('0x0a'));
    });

    test('DataRowException toString', () {
      final e = DataRowException('bad');
      expect(e.toString(), 'DataRowException: bad');
    });

    test('DataSet aggregates rows and clears', () {
      final set = DataSet();
      set.addRawRow(tag: 0x01, value: Uint8List.fromList([0xAA]));
      set.addRow(row: DataRow(tag: 0x02, value: Uint8List.fromList([0xBB, 0xCC])));
      expect(set.rows.length, 2);
      expect(set.toList(), Uint8List.fromList([0x01, 0x01, 0xAA, 0x02, 0x02, 0xBB, 0xCC]));
      set.clear();
      expect(set.rows, isEmpty);
      expect(set.toList(), isEmpty);
    });
  });

  group('AAPublicKey', () {
    test('parses RSA public key', () {
      // Algorithm OID is RSA (2A864886F70D010101)
      final key = AAPublicKey.fromBytes(hexb("301A300D06092A864886F70D0101010500030B0030090202C1D30203010001"));
      expect(key.type, AAPublicKeyType.RSA);
      expect(key.toBytes(), isNotEmpty);
      expect(key.rawSubjectPublicKey(), isNotEmpty);
    });

    test('non-RSA OID is treated as ECC', () {
      // Same structure but a different (non-RSA) algorithm OID 2A8648CE3D0201
      final key = AAPublicKey.fromBytes(hexb("3010300906072A8648CE3D0201030300ABCD"));
      expect(key.type, AAPublicKeyType.ECC);
    });

    test('throws on wrong outer tag', () {
      expect(() => AAPublicKey.fromBytes(hexb("3103020100")), throwsA(isA<Exception>()));
    });
  });

  group('EfCOM', () {
    test('parses version, unicode version and tags', () {
      final ef = EfCOM.fromBytes(hexb("60165F0104303130375F36063034303030305C046175766C"));
      expect(ef.version, "0107");
      expect(ef.unicodeVersion, "040000");
      expect(ef.fid, EfCOM.FID);
      expect(ef.sfi, EfCOM.SFI);
      expect(ef.dgTags.contains(DgTag(0x61)), true);
    });

    test('wrong EF.COM tag throws', () {
      expect(
        () => EfCOM.fromBytes(hexb("61165F0104303130375F36063034303030305C046175766C")),
        throwsA(isA<EfParseError>()),
      );
    });

    test('wrong version object tag throws', () {
      // version tag 5F02 instead of 5F01
      expect(
        () => EfCOM.fromBytes(hexb("60165F0204303130375F36063034303030305C046175766C")),
        throwsA(isA<EfParseError>()),
      );
    });

    test('tag list directly with 5C (no 5F36) is accepted', () {
      // 60 <len> 5F01 04 "0107" 5C 04 6175766C
      final ef = EfCOM.fromBytes(hexb("600D5F0104303130375C046175766C"));
      expect(ef.version, "0107");
      expect(ef.dgTags.contains(DgTag(0x61)), true);
      expect(ef.dgTags.contains(DgTag(0x75)), true);
    });

    test('unexpected second object tag throws', () {
      // second object tag 5F37 (neither 5F36 nor 5C)
      expect(
        () => EfCOM.fromBytes(hexb("60165F0104303130375F37063034303030305C046175766C")),
        throwsA(isA<EfParseError>()),
      );
    });
  });

  group('EfSOD', () {
    test('exposes fid/sfi and tolerates parse', () {
      final sod = EfSOD.fromBytes(hexb("7700"));
      expect(sod.fid, EfSOD.FID);
      expect(sod.sfi, EfSOD.SFI);
      expect(sod.toBytes(), hexb("7700"));
    });
  });

  group('DF1 constants', () {
    test('AIDs and name', () {
      expect(DF1.PassportAID, hexb("A0000002471001"));
      expect(DF1.DriverAID, hexb("A00000045645444C2D3031"));
      expect(DF1.name, "eMRTD Application");
    });
  });

  group('DgTag', () {
    test('equality and hashCode', () {
      expect(DgTag(0x61), DgTag(0x61));
      expect(DgTag(0x61) == DgTag(0x62), false);
      expect(DgTag(0x61).hashCode, DgTag(0x61).hashCode);
      expect(DgTag(0x61).value, 0x61);
    });
  });
}
