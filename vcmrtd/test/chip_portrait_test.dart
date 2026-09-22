// The chip portrait, as the on-device face verification method needs it: the
// bytes exactly as the document stored them, for both document types.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/vcmrtd.dart';

PassportMRZ _mrz() {
  return PassportMRZ(
    Uint8List.fromList(
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
    ),
  );
}

PassportData _passport({required Uint8List photo, ImageType type = ImageType.jpeg2000}) {
  return PassportData(
    mrz: _mrz(),
    photoImageData: photo,
    photoImageType: type,
    photoImageWidth: 240,
    photoImageHeight: 320,
  );
}

DrivingLicenceData _licence({required Uint8List photo, ImageType? type}) {
  return DrivingLicenceData(
    issuingMemberState: 'NL',
    holderSurname: 'ERIKSSON',
    holderOtherName: 'ANNA',
    dateOfBirth: '19740812',
    placeOfBirth: 'UTOPIA',
    dateOfIssue: '20200101',
    dateOfExpiry: '20300101',
    issuingAuthority: 'RDW',
    documentNumber: '1234567890',
    photoImageData: photo,
    photoImageType: type,
    bapInputString: '',
    saiType: '',
    aaPublicKey: null,
    categories: const [],
  );
}

void main() {
  group('DocumentData.portrait', () {
    final photo = Uint8List.fromList([0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20]);

    test('a passport exposes its DG2 photo with the type the chip declared', () {
      final portrait = _passport(photo: photo).portrait;
      expect(portrait, isNotNull);
      expect(portrait!.bytes, photo);
      expect(portrait.type, ImageType.jpeg2000);
    });

    test('a driving licence exposes its DG6 photo', () {
      final portrait = _licence(photo: photo, type: ImageType.jpeg).portrait;
      expect(portrait!.bytes, photo);
      expect(portrait.type, ImageType.jpeg);
    });

    // Driving licences do not always declare the format. The bytes are still
    // usable — every consumer sniffs them anyway — so an absent type must not
    // cost the portrait.
    test('a driving licence without a declared type still has a portrait', () {
      final portrait = _licence(photo: photo, type: null).portrait;
      expect(portrait!.bytes, photo);
      expect(portrait.type, isNull);
    });

    test('a document with no photo bytes has no portrait', () {
      expect(_passport(photo: Uint8List(0)).portrait, isNull);
      expect(_licence(photo: Uint8List(0), type: ImageType.jpeg).portrait, isNull);
    });

    // The issuer compares its own SHA-256 of the portrait with the wallet's,
    // so anything that re-encoded the bytes on the way out would break the
    // check in a way no unit test of the hash itself would catch.
    test('hands back the very bytes it was given, not a re-encoding', () {
      final passport = _passport(photo: photo);
      expect(identical(passport.portrait!.bytes, passport.photoImageData), isTrue);
    });
  });
}
