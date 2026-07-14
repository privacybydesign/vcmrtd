import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/vcmrtd.dart';

// A minimal TD3 MRZ for holder "ERIKSSON, ANNA MARIA". The MRZ character set
// is basic Latin only (ICAO 9303), so any diacritics are transliterated away
// here — this is exactly the lossy representation `displayName` should avoid
// when DG11 is available.
PassportMRZ _mrz() {
  return PassportMRZ(
    Uint8List.fromList(
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
    ),
  );
}

PassportData _passport({String? nameOfHolder}) {
  return PassportData(
    mrz: _mrz(),
    photoImageData: Uint8List(0),
    photoImageType: ImageType.jpeg,
    photoImageWidth: 0,
    photoImageHeight: 0,
    nameOfHolder: nameOfHolder,
  );
}

void main() {
  group('PassportData.displayName', () {
    test('prefers the DG11 nameOfHolder and preserves diacritics', () {
      // DG11 carries the UTF-8 accented name (e.g. the Serbian Ć from issue #77).
      final passport = _passport(nameOfHolder: 'JOVIĆ ANA');
      expect(passport.displayName, 'JOVIĆ ANA');
    });

    test('falls back to the MRZ name when DG11 nameOfHolder is absent', () {
      final passport = _passport(nameOfHolder: null);
      expect(passport.displayName, '${passport.mrz.firstName} ${passport.mrz.lastName}');
      expect(passport.displayName, 'ANNA MARIA ERIKSSON');
    });

    test('falls back to the MRZ name when DG11 nameOfHolder is blank', () {
      expect(_passport(nameOfHolder: '').displayName, 'ANNA MARIA ERIKSSON');
      expect(_passport(nameOfHolder: '   ').displayName, 'ANNA MARIA ERIKSSON');
    });

    test('trims surrounding whitespace from the DG11 nameOfHolder', () {
      expect(_passport(nameOfHolder: '  JOVIĆ ANA  ').displayName, 'JOVIĆ ANA');
    });
  });
}
