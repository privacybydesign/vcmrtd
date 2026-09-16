import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/providers/proofing_session_provider.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';

void main() {
  test('proofingSessionClientProvider exposes a ProofingSessionClient', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(proofingSessionClientProvider), isA<ProofingSessionClient>());
  });

  group('ActiveProofingSessionNotifier', () {
    test('starts with no active session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeProofingSessionProvider), isNull);
    });

    test('set pins and clears the active session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = ActiveProofingSession(
        ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok'),
        info: ProofingSessionInfo(
          id: 'sess-1',
          relyingParty: 'Acme Corp',
          requestedAttributes: const [],
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
        openedAt: DateTime.now(),
      );

      container.read(activeProofingSessionProvider.notifier).set(session);
      expect(container.read(activeProofingSessionProvider), session);

      container.read(activeProofingSessionProvider.notifier).set(null);
      expect(container.read(activeProofingSessionProvider), isNull);
    });
  });
}
