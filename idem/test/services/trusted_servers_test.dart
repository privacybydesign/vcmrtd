import 'dart:convert';
import 'dart:io' show HttpStatus;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_coordinator.dart';
import 'package:idem/services/trusted_servers.dart';

void main() {
  group('TrustedServers', () {
    final servers = TrustedServers.parse(
      'https://wallet.example, http://192.168.1.20:8080,not a url',
      whenEmpty: EmptyListPolicy.trustAll,
    );

    test('trusts exactly the listed origins', () {
      expect(servers.isTrusted('https://wallet.example'), isTrue);
      expect(servers.isTrusted('https://WALLET.example/'), isTrue);
      expect(servers.isTrusted('http://192.168.1.20:8080'), isTrue);
    });

    test('refuses a look-alike, another port or scheme, and anything unparsable', () {
      expect(servers.isTrusted('https://wallet.example.evil.test'), isFalse);
      expect(servers.isTrusted('https://evil.test'), isFalse);
      expect(servers.isTrusted('https://wallet.example:8443'), isFalse);
      expect(servers.isTrusted('http://wallet.example'), isFalse);
      expect(servers.isTrusted('http://192.168.1.20'), isFalse);
      expect(servers.isTrusted('vcmrtd://wallet.example'), isFalse);
      expect(servers.isTrusted(''), isFalse);
    });

    test('without a list, a debug build trusts every server and a release build none', () {
      expect(TrustedServers.parse('', whenEmpty: EmptyListPolicy.trustAll).isTrusted('https://anything.test'), isTrue);
      expect(
        TrustedServers.parse('', whenEmpty: EmptyListPolicy.trustNone).isTrusted('https://anything.test'),
        isFalse,
      );
      expect(
        TrustedServers.parse(' , ', whenEmpty: EmptyListPolicy.trustNone).isTrusted('https://anything.test'),
        isFalse,
      );
    });
  });

  test('a link to an untrusted server is refused without contacting it', () async {
    var requests = 0;
    await http.runWithClient(
      () async {
        final coordinator = ProofingSessionCoordinator(
          client: const ProofingSessionClient(),
          trustedServers: TrustedServers.parse('https://wallet.example', whenEmpty: EmptyListPolicy.trustNone),
        );
        final link = ProofingSessionLink.parse('vcmrtd://verify?handover=h-1&api=https://evil.test')!;
        await expectLater(
          coordinator.connect(link),
          throwsA(
            isA<ProofingSessionAccessException>().having(
              (e) => e.reason,
              'reason',
              ProofingAccessDenial.untrustedServer,
            ),
          ),
        );
      },
      () => MockClient((request) async {
        requests++;
        return http.Response(json.encode({}), HttpStatus.ok);
      }),
    );
    expect(requests, 0);
  });
}
