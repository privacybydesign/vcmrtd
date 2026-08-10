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

  group('DefaultPassportIssuer.parseStartValidationResponse', () {
    test('parses the nonce and session id', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({'session_id': 'sess-1', 'nonce': 'nonce-1'});
      expect(result.nonceAndSessionId.sessionId, 'sess-1');
      expect(result.nonceAndSessionId.nonce, 'nonce-1');
    });

    test('parses the face verification announcement when present', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        'session_id': 'sess-1',
        'nonce': 'nonce-1',
        'face_verification': {'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification?.faceApiUrl, 'https://faceapi.example');
    });

    test('an absent announcement means face verification does not apply', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({'session_id': 'sess-1', 'nonce': 'nonce-1'});
      expect(result.faceVerification, isNull);
    });

    // A malformed announcement is treated as absent: skipping the step is safe
    // because an issuer that requires face verification rejects issuance
    // without a liveness transaction anyway (fail-closed server-side).
    test('a malformed announcement is treated as absent', () {
      for (final malformed in [
        null,
        'https://faceapi.example', // not an object
        <String, dynamic>{}, // no face_api_url
        {'face_api_url': ''}, // empty url
        {'face_api_url': 42}, // not a string
      ]) {
        final result = DefaultPassportIssuer.parseStartValidationResponse({
          'session_id': 'sess-1',
          'nonce': 'nonce-1',
          'face_verification': malformed,
        });
        expect(result.faceVerification, isNull, reason: 'for $malformed');
      }
    });

    // The liveness selfie is uploaded to this server-supplied URL, so it gets
    // the same absolute-https treatment as validateSessionUrl.
    test('an announcement with a url that is not absolute https is treated as absent', () {
      for (final url in [
        'http://faceapi.example', // plaintext
        'javascript:alert(1)',
        'faceapi.example', // not absolute
        'not-a-url-at-all',
        '   ',
        'https://', // no host
        // Uri percent-encodes whitespace into the host, so these survive the
        // scheme/host checks and need rejecting on their own.
        'https://face api.example', // host -> face%20api.example
        'https://faceapi.example ', // host -> faceapi.example%20
      ]) {
        final result = DefaultPassportIssuer.parseStartValidationResponse({
          'session_id': 'sess-1',
          'nonce': 'nonce-1',
          'face_verification': {'face_api_url': url},
        });
        expect(result.faceVerification, isNull, reason: 'for "$url"');
      }
    });

    test('an https url with a path and port is accepted as-is', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        'session_id': 'sess-1',
        'nonce': 'nonce-1',
        'face_verification': {'face_api_url': 'https://faceapi.staging.yivi.app:8443/api'},
      });
      expect(result.faceVerification?.faceApiUrl, 'https://faceapi.staging.yivi.app:8443/api');
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
