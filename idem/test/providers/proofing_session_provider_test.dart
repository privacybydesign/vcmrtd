import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';

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
      );

      container.read(activeProofingSessionProvider.notifier).set(session);
      expect(container.read(activeProofingSessionProvider), session);

      container.read(activeProofingSessionProvider.notifier).set(null);
      expect(container.read(activeProofingSessionProvider), isNull);
    });
  });

  group('markActiveProofingStepStarted', () {
    ActiveProofingSession session({int resetCount = 0}) => ActiveProofingSession(
      ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok', deviceToken: 'dev'),
      info: ProofingSessionInfo(
        id: 'sess-1',
        relyingParty: 'Acme Corp',
        requestedAttributes: const [],
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        steps: const [stepDocumentCapture, stepNfcRead],
        resetCount: resetCount,
      ),
    );

    /// Runs [body] with every HTTP call answered by [status], and returns
    /// the paths that were called.
    Future<List<String>> reported(Future<void> Function() body, {int status = 200}) async {
      final paths = <String>[];
      await http.runWithClient(
        () async {
          await body();
          await Future<void>.delayed(Duration.zero);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          return http.Response('{}', status);
        }),
      );
      return paths;
    }

    test('reports a step once while the same session is pinned', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeProofingSessionProvider.notifier).set(session());

      final paths = await reported(() async {
        markActiveProofingStepStarted(container, stepDocumentCapture);
        markActiveProofingStepStarted(container, stepDocumentCapture);
        markActiveProofingStepStarted(container, stepNfcRead);
      });

      expect(paths, ['/api/v1/app/tok/steps/document_capture/start', '/api/v1/app/tok/steps/nfc_read/start']);
    });

    test('reports again once the session is pinned anew or reset', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(activeProofingSessionProvider.notifier);

      final paths = await reported(() async {
        notifier.set(session());
        markActiveProofingStepStarted(container, stepDocumentCapture);
        notifier.set(session());
        markActiveProofingStepStarted(container, stepDocumentCapture);
        notifier.updateInfo(session().ref, session(resetCount: 1).info);
        markActiveProofingStepStarted(container, stepDocumentCapture);
      });

      expect(paths, hasLength(3));
    });

    test('skips steps the flow does not have, and runs without a session', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final paths = await reported(() async {
        markActiveProofingStepStarted(container, stepDocumentCapture);
        container.read(activeProofingSessionProvider.notifier).set(session());
        markActiveProofingStepStarted(container, stepDocumentPhoto);
      });

      expect(paths, isEmpty);
    });

    test('a failed report is sent again next time', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeProofingSessionProvider.notifier).set(session());

      final failed = await reported(() async {
        markActiveProofingStepStarted(container, stepNfcRead);
      }, status: 500);
      final retried = await reported(() async {
        markActiveProofingStepStarted(container, stepNfcRead);
      });

      expect(failed, hasLength(1));
      expect(retried, hasLength(1));
    });
  });
}
