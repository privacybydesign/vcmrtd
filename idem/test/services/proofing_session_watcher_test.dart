import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_watcher.dart';

const _ref = ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok-1', deviceToken: 'dev-1');

Map<String, dynamic> _view({
  required String status,
  required int resetCount,
  required String changeKey,
  bool authorized = true,
}) => {
  'id': 'sess-1',
  'relyingParty': 'Acme Corp',
  'requestedAttributes': ['dg1'],
  'expiresAt': '2030-01-01T00:00:00Z',
  'status': status,
  'resetCount': resetCount,
  'changeKey': changeKey,
  'device': {'authorized': authorized, 'role': 'native', 'state': 'active'},
};

ProofingSessionInfo _info({String status = 'opened', int resetCount = 0, String? changeKey = 'opened||0'}) =>
    ProofingSessionInfo(
      id: 'sess-1',
      relyingParty: 'Acme Corp',
      requestedAttributes: const ['dg1'],
      expiresAt: DateTime.utc(2030),
      status: status,
      resetCount: resetCount,
      changeKey: changeKey,
    );

/// A long-poll that never answers until its client is closed, like the real
/// /events wait - closing it aborts the request, as IOClient.close() does.
class _HangingClient extends http.BaseClient {
  final _pending = Completer<http.StreamedResponse>();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _pending.future;

  @override
  void close() {
    closed = true;
    if (!_pending.isCompleted) _pending.completeError(http.ClientException('closed'));
  }
}

void main() {
  test('pause hangs up the open long-poll and polls again only after resume', () async {
    final polls = <_HangingClient>[];
    await http.runWithClient(
      () async {
        final watcher = ProofingSessionWatcher(
          client: const ProofingSessionClient(),
          ref: _ref,
          initial: _info(),
          onEvent: (_) {},
          retryDelay: Duration.zero,
        );
        unawaited(watcher.start());
        await pumpEventQueue();
        expect(polls, hasLength(1));

        watcher.pause(); // app went to the background
        await pumpEventQueue();
        expect(polls.single.closed, isTrue, reason: 'the open wait is hung up, so the server sees the device leave');
        expect(polls, hasLength(1), reason: 'no polling while backgrounded');

        watcher.resume();
        await pumpEventQueue();
        expect(polls, hasLength(2));
        watcher.stop();
        polls.last.close();
      },
      () {
        final client = _HangingClient();
        polls.add(client);
        return client;
      },
    );
  });

  test('waitForChange long-polls the events endpoint with the given key', () async {
    await http.runWithClient(
      () async {
        final info = await const ProofingSessionClient().waitForChange(_ref, 'opened||0');
        expect(info.status, 'opened');
        expect(info.resetCount, 1);
        expect(info.changeKey, 'opened||1');
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/app/tok-1/events');
        expect(request.url.queryParameters['since'], 'opened||0');
        expect(request.headers['X-Device-Token'], 'dev-1');
        return http.Response(json.encode(_view(status: 'opened', resetCount: 1, changeKey: 'opened||1')), 200);
      }),
    );
  });

  test('reports a reset only when resetCount goes up, and stops once the session is finished', () async {
    final responses = [
      _view(status: 'in_progress', resetCount: 0, changeKey: 'in_progress|nfc_read|0'),
      _view(status: 'opened', resetCount: 1, changeKey: 'opened||1'),
      _view(status: 'approved', resetCount: 1, changeKey: 'approved|nfc_read|1'),
    ];
    final sentKeys = <String?>[];
    final events = <ProofingSessionEvent>[];

    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
      ).start(),
      () => MockClient((request) async {
        sentKeys.add(request.url.queryParameters['since']);
        return http.Response(json.encode(responses.removeAt(0)), 200);
      }),
    );

    expect(sentKeys, ['opened||0', 'in_progress|nfc_read|0', 'opened||1']);
    expect(events.map((e) => e.runtimeType), [ProofingSessionUpdated, ProofingSessionWasReset, ProofingSessionUpdated]);
    final reset = events[1] as ProofingSessionWasReset;
    expect(reset.info.resetCount, 1);
    expect(reset.info.status, 'opened');
  });

  test('reports completion and stops once the session was submitted (on either device)', () async {
    final responses = [
      {..._view(status: 'in_progress', resetCount: 0, changeKey: 'k1'), 'lifecycle': 'ACTIVE', 'readyToSubmit': true},
      {..._view(status: 'approved', resetCount: 0, changeKey: 'k2'), 'lifecycle': 'COMPLETE'},
    ];
    final events = <ProofingSessionEvent>[];

    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
      ).start(),
      () => MockClient((request) async => http.Response(json.encode(responses.removeAt(0)), 200)),
    );

    expect(responses, isEmpty);
    expect(events.map((e) => e.runtimeType), [ProofingSessionUpdated, ProofingSessionCompleted]);
    expect((events.first as ProofingSessionUpdated).info.readyToSubmit, isTrue);
  });

  test('does not poll a server without reset support (no changeKey)', () async {
    var requests = 0;
    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(changeKey: null),
        onEvent: (e) => fail('no event expected, got $e'),
      ).start(),
      () => MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    expect(requests, 0);
  });

  test('reports access lost and stops when the session is gone', () async {
    var requests = 0;
    final events = <ProofingSessionEvent>[];
    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
      ).start(),
      () => MockClient((request) async {
        requests++;
        return http.Response('{"error":"session not found"}', 404);
      }),
    );
    expect(requests, 1);
    expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.gone);
  });

  test('reports a handover when the server says another device took over (403)', () async {
    final events = <ProofingSessionEvent>[];
    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
      ).start(),
      () => MockClient(
        (request) async => http.Response(json.encode({'error': 'handed over', 'code': 'device_handed_over'}), 403),
      ),
    );
    expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.handedOver);
  });

  test('reports a handover when the view says this device is no longer authorized', () async {
    final events = <ProofingSessionEvent>[];
    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
      ).start(),
      () => MockClient(
        (request) async => http.Response(
          json.encode(_view(status: 'in_progress', resetCount: 0, changeKey: 'x', authorized: false)),
          200,
        ),
      ),
    );
    expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.handedOver);
  });

  test('keeps listening through a network failure', () async {
    var requests = 0;
    final events = <ProofingSessionEvent>[];
    await http.runWithClient(
      () => ProofingSessionWatcher(
        client: const ProofingSessionClient(),
        ref: _ref,
        initial: _info(),
        onEvent: events.add,
        retryDelay: Duration.zero,
      ).start(),
      () => MockClient((request) async {
        requests++;
        if (requests == 1) throw http.ClientException('offline');
        return http.Response(json.encode(_view(status: 'approved', resetCount: 0, changeKey: 'done')), 200);
      }),
    );
    expect(requests, 2);
    expect(events.single, isA<ProofingSessionUpdated>());
  });
}
