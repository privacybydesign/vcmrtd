import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// The licence file used to be called LICENSE.LGPL while holding the text of the
// GPL version 3. These checks keep the name, the contents and the per-package
// copies in agreement. Paths are relative to the vcmrtd package root, which is
// the working directory `flutter test` runs from.
void main() {
  final licences = {
    'repository root': File('../LICENSE'),
    'vcmrtd package': File('LICENSE'),
    'face_verification package': File('../face_verification/LICENSE'),
  };

  group('licence files', () {
    licences.forEach((location, file) {
      test('the $location licence is the GPL version 3', () {
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final text = file.readAsStringSync();
        expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
        expect(text, contains('Version 3, 29 June 2007'));
        expect(text, isNot(contains('GNU LESSER GENERAL PUBLIC LICENSE')));
      });
    });

    test('the three copies are identical', () {
      final texts = licences.values.map((f) => f.readAsStringSync()).toSet();
      expect(texts, hasLength(1));
    });

    test('no file claims LGPL terms in its name', () {
      final named = [
        File('../LICENSE.LGPL'),
        File('LICENSE.LGPL'),
        File('../face_verification/LICENSE.LGPL'),
      ].where((f) => f.existsSync()).map((f) => f.path);
      expect(named, isEmpty);
    });
  });
}
