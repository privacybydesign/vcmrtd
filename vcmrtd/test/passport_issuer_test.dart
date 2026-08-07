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

    test('defaults the allowed IRMA host list to the configured host origin', () {
      final issuer = DefaultPassportIssuer(hostName: 'https://issuer.example');
      expect(issuer.allowedIrmaHosts, {'issuer.example'});
    });

    test('accepts an explicit allowed IRMA host list', () {
      final issuer = DefaultPassportIssuer(
        hostName: 'https://issuer.example',
        allowedIrmaHosts: ['irma.example', 'irma2.example'],
      );
      expect(issuer.allowedIrmaHosts, {'irma.example', 'irma2.example'});
    });
  });

  group('DefaultPassportIssuer.validateSessionUrl', () {
    final issuer = DefaultPassportIssuer(hostName: 'https://issuer.example', allowedIrmaHosts: ['irma.example']);

    test('accepts an https URL on an allowed host', () {
      final uri = issuer.validateSessionUrl('https://irma.example');
      expect(uri.host, 'irma.example');
      expect(uri.scheme, 'https');
    });

    test('accepts an https URL with a path on an allowed host', () {
      final uri = issuer.validateSessionUrl('https://irma.example/irma');
      expect(uri.host, 'irma.example');
    });

    test('rejects a non-https (http) URL even on an allowed host', () {
      expect(() => issuer.validateSessionUrl('http://irma.example'), throwsException);
    });

    test('rejects an https URL on a host outside the allowlist', () {
      expect(() => issuer.validateSessionUrl('https://evil.example'), throwsException);
    });

    test('rejects a relative / hostless URL', () {
      expect(() => issuer.validateSessionUrl('/session'), throwsException);
      expect(() => issuer.validateSessionUrl('not a url'), throwsException);
    });

    test('rejects a non-http scheme such as file', () {
      expect(() => issuer.validateSessionUrl('file:///etc/passwd'), throwsException);
    });

    test('host matching is exact and does not allow suffix look-alikes', () {
      expect(() => issuer.validateSessionUrl('https://irma.example.evil.com'), throwsException);
      expect(() => issuer.validateSessionUrl('https://notirma.example'), throwsException);
    });
  });
}
