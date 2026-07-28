import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// The licence file used to be called LICENSE.LGPL while holding a reflowed copy
// of the GPL version 3. These checks keep the name, the contents and the
// per-package copies in agreement. Paths are relative to the vcmrtd package
// root, which is the working directory `flutter test` runs from.
//
// The digest is of https://www.gnu.org/licenses/gpl-3.0.txt, which is
// byte-identical to /usr/share/common-licenses/GPL-3 on Debian. GPLv3 asks for
// a verbatim copy of the License, so pinning the digest is what says that: it
// rejects the reflowed text the repository used to carry, in which `END OF
// TERMS AND CONDITIONS` was broken across a newline and the copyright sign
// stood in for `(C)`. Pinning all three copies to it also keeps them identical.
const canonicalGplV3Sha256 = '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986';

void main() {
  final licences = {
    'repository root': File('../LICENSE'),
    'vcmrtd package': File('LICENSE'),
    'face_verification package': File('../face_verification/LICENSE'),
  };

  group('licence files', () {
    licences.forEach((location, file) {
      test('the $location licence is the verbatim GPL version 3', () {
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final bytes = file.readAsBytesSync();
        // Checked first so a mismatch names the licence instead of only a digest.
        final firstLine = String.fromCharCodes(bytes).split('\n').firstWhere((line) => line.trim().isNotEmpty).trim();
        expect(firstLine, 'GNU GENERAL PUBLIC LICENSE');

        expect(
          sha256.convert(bytes).toString(),
          canonicalGplV3Sha256,
          reason: '${file.path} is not the verbatim text of https://www.gnu.org/licenses/gpl-3.0.txt',
        );
      });
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
