// Tests for DefaultPassportIssuer (lib/src/passport_issuer.dart).
//
// LIMITATION: DefaultPassportIssuer calls the top-level `http.post` directly
// and does not accept an injectable http.Client, so its network methods cannot
// be exercised deterministically without real I/O. We therefore cover only the
// constructable / pure parts here (construction and the PassportIssuer
// contract). The HTTP request/response branches remain uncovered by design.
import 'package:test/test.dart';
import 'package:vcmrtd/vcmrtd.dart';

void main() {
  group('DefaultPassportIssuer (pure parts)', () {
    test('constructs and stores the host name', () {
      final issuer = DefaultPassportIssuer(hostName: 'https://issuer.example');
      expect(issuer.hostName, 'https://issuer.example');
    });

    test('implements the PassportIssuer interface', () {
      final issuer = DefaultPassportIssuer(hostName: 'https://issuer.example');
      expect(issuer, isA<PassportIssuer>());
    });
  });
}
