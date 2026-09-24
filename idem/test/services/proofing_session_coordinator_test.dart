import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_coordinator.dart';
import 'package:idem/services/proofing_session_watcher.dart';

const _api = 'https://proof.example.com';

Map<String, dynamic> _view({
  String status = 'opened',
  bool authorized = true,
  String? currentStep = 'document_capture',
  String lifecycle = 'ACTIVE',
  String expiresAt = '2030-01-01T00:00:00Z',
}) => {
  'id': 'sess-1',
  'relyingParty': 'Acme Corp',
  'requestedAttributes': ['dg1'],
  'expiresAt': expiresAt,
  'status': status,
  'lifecycle': lifecycle,
  'currentStep': ?currentStep,
  'completedSteps': <String>[],
  'device': {'authorized': authorized, 'role': 'native', 'state': 'active'},
};

Map<String, dynamic> _claimBody({bool authorized = true}) => {
  'token': 'tok-1',
  'deviceToken': 'dev-1',
  'role': 'native',
  'session': _view(authorized: authorized),
};

http.Response _json(Object body, [int status = 200]) => http.Response(json.encode(body), status);

http.Response _refused(int status, String code) => _json({'error': code, 'code': code}, status);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ProofingSessionLink.parse', () {
    test('recognises a handover deep link', () {
      final link = ProofingSessionLink.parse('vcmrtd://verify?handover=h-1&api=$_api');
      expect(link, isA<ProofingHandoverLink>());
      expect((link as ProofingHandoverLink).handoverToken, 'h-1');
      expect(link.apiBase, _api);
    });

    test('recognises session links', () {
      expect(ProofingSessionLink.parse('vcmrtd://verify?token=tok-1&api=$_api'), isA<ProofingSessionTokenLink>());
      expect(ProofingSessionLink.parse('$_api/s/tok-1'), isA<ProofingSessionTokenLink>());
    });

    test('rejects an incomplete handover link and unrelated values', () {
      expect(ProofingSessionLink.parse('vcmrtd://verify?handover=h-1'), isNull);
      expect(ProofingSessionLink.parse('vcmrtd://verify?handover=&api=$_api'), isNull);
      expect(ProofingSessionLink.parse('hello'), isNull);
    });
  });

  group('ProofingSessionClient', () {
    test('claimHandover claims through the grant token alone and keeps the issued device token', () async {
      await http.runWithClient(
        () async {
          final claim = await const ProofingSessionClient().claimHandover(
            const ProofingHandoverLink(apiBase: _api, handoverToken: 'h-1'),
          );
          expect(claim.ref.apiBase, _api);
          expect(claim.ref.token, 'tok-1');
          expect(claim.ref.deviceToken, 'dev-1');
          expect(claim.info.currentStep, 'document_capture');
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/app/handover/h-1/claim');
          expect(request.headers.containsKey('X-Device-Token'), isFalse);
          return _json(_claimBody());
        }),
      );
    });

    test('maps every refusal code to its reason', () async {
      const cases = {
        (403, 'device_handed_over'): ProofingAccessDenial.handedOver,
        (410, 'session_expired'): ProofingAccessDenial.expired,
        (401, 'device_unauthorized'): ProofingAccessDenial.unauthorized,
        (409, 'session_complete'): ProofingAccessDenial.complete,
        (409, 'device_already_claimed'): ProofingAccessDenial.alreadyClaimed,
        (404, 'handover_invalid'): ProofingAccessDenial.handoverInvalid,
        (410, 'handover_expired'): ProofingAccessDenial.handoverExpired,
        (409, 'handover_used'): ProofingAccessDenial.handoverUsed,
        (410, 'claim_token_required'): ProofingAccessDenial.claimTokenRequired,
      };
      for (final MapEntry(key: (status, code), value: reason) in cases.entries) {
        final denial = proofingAccessDenialFor(_refused(status, code));
        expect(denial?.reason, reason, reason: code);
        expect(denial?.statusCode, status);
      }
    });

    test('an uncoded 409 is an ordinary failure, not a refusal', () {
      expect(proofingAccessDenialFor(_json({'error': 'reference photo not available yet'}, 409)), isNull);
      expect(proofingAccessDenialFor(_json({'error': 'bad'}, 400)), isNull);
    });

    test('step submissions carry the device token and return the server\'s next step', () async {
      const ref = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-1');
      await http.runWithClient(
        () async {
          final response = await const ProofingSessionClient().submitSelfieStep(
            ref,
            selfie: const ProofingPhotoInfo(imageBase64: 'AAAA', mimeType: 'image/jpeg'),
          );
          expect(response.completedSteps, ['document_capture', 'nfc_read', 'face_verification']);
          expect(response.currentStep, '');
          // The last step doesn't finish the session: it waits for a submit.
          expect(response.readyToSubmit, isTrue);
          expect(response.complete, isFalse);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/v1/app/tok-1/steps/selfie');
          expect(request.headers['X-Device-Token'], 'dev-1');
          expect(json.decode(request.body), {'image': 'AAAA', 'mimeType': 'image/jpeg'});
          return _json({
            'status': 'in_progress',
            'completedSteps': ['document_capture', 'nfc_read', 'face_verification'],
            'currentStep': '',
            'lifecycle': 'ACTIVE',
            'readyToSubmit': true,
          });
        }),
      );
    });

    test('submitSession posts with only the device token and returns the outcome', () async {
      const ref = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-1');
      await http.runWithClient(
        () async {
          final response = await const ProofingSessionClient().submitSession(ref);
          expect(response.complete, isTrue);
          expect(response.status, 'approved');
          expect(response.alreadyRecorded, isTrue);
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/app/tok-1/submit');
          expect(request.headers['X-Device-Token'], 'dev-1');
          expect(request.body, isEmpty);
          return _json({
            'status': 'approved',
            'completedSteps': ['document_capture', 'nfc_read'],
            'currentStep': '',
            'lifecycle': 'COMPLETE',
            'readyToSubmit': false,
            'alreadyRecorded': true,
          });
        }),
      );
    });

    test('submitSession tells steps_incomplete apart from an access refusal', () async {
      const ref = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-1');
      await http.runWithClient(() async {
        await expectLater(
          const ProofingSessionClient().submitSession(ref),
          throwsA(isA<ProofingStepsIncompleteException>()),
        );
      }, () => MockClient((request) async => _refused(409, 'steps_incomplete')));
      await http.runWithClient(() async {
        await expectLater(
          const ProofingSessionClient().submitSession(ref),
          throwsA(
            isA<ProofingSessionAccessException>().having((e) => e.reason, 'reason', ProofingAccessDenial.handedOver),
          ),
        );
      }, () => MockClient((request) async => _refused(403, 'device_handed_over')));
    });

    test('the session view carries readyToSubmit', () {
      expect(ProofingSessionInfo.fromJson(_view()).readyToSubmit, isFalse);
      expect(ProofingSessionInfo.fromJson({..._view(currentStep: ''), 'readyToSubmit': true}).readyToSubmit, isTrue);
    });

    test('a step submitted after a handover is refused as handed over', () async {
      const ref = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'old-dev');
      await http.runWithClient(() async {
        await expectLater(
          const ProofingSessionClient().markStepStarted(ref, stepNfcRead),
          throwsA(
            isA<ProofingSessionAccessException>().having((e) => e.reason, 'reason', ProofingAccessDenial.handedOver),
          ),
        );
      }, () => MockClient((request) async => _refused(403, 'device_handed_over')));
    });
  });

  group('ProofingSessionInfo.accessLost', () {
    test('is null while this device may continue', () {
      expect(ProofingSessionInfo.fromJson(_view()).accessLost, isNull);
    });

    test('leaves expiry to the server rather than this device\'s clock', () {
      expect(ProofingSessionInfo.fromJson(_view(expiresAt: '2000-01-01T00:00:00Z')).accessLost, isNull);
    });

    test('reads a handover, an expiry and a cancellation off the view', () {
      expect(ProofingSessionInfo.fromJson(_view(authorized: false)).accessLost, ProofingAccessDenial.handedOver);
      expect(ProofingSessionInfo.fromJson(_view(lifecycle: 'EXPIRED')).accessLost, ProofingAccessDenial.expired);
      expect(ProofingSessionInfo.fromJson(_view(status: 'expired')).accessLost, ProofingAccessDenial.expired);
      expect(ProofingSessionInfo.fromJson(_view(lifecycle: 'CANCELLED')).accessLost, ProofingAccessDenial.cancelled);
    });
  });

  group('ProofingSessionCoordinator', () {
    test('connect claims with the grant, then reuses the credential when the same QR is scanned again', () async {
      final requests = <String>[];
      await http.runWithClient(
        () async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          final link = ProofingSessionLink.parse('vcmrtd://verify?handover=claim-1&api=$_api')!;
          await coordinator.connect(link);
          final again = await coordinator.connect(link);
          expect(again.ref.deviceToken, 'dev-1');
        },
        () => MockClient((request) async {
          requests.add('${request.method} ${request.url.path} ${request.headers['X-Device-Token']}');
          return request.method == 'POST' ? _json(_claimBody()) : _json(_view());
        }),
      );
      expect(requests, ['POST /api/v1/app/handover/claim-1/claim null', 'GET /api/v1/app/tok-1 dev-1']);
    });

    test('connect refuses a session-token link without calling the server', () async {
      final requests = <String>[];
      await http.runWithClient(
        () async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          for (final raw in ['$_api/s/tok-1', 'vcmrtd://verify?token=tok-1&api=$_api']) {
            await expectLater(
              coordinator.connect(ProofingSessionLink.parse(raw)!),
              throwsA(
                isA<ProofingSessionAccessException>().having(
                  (e) => e.reason,
                  'reason',
                  ProofingAccessDenial.claimTokenRequired,
                ),
              ),
            );
          }
        },
        () => MockClient((request) async {
          requests.add(request.url.path);
          return _json(_claimBody());
        }),
      );
      expect(requests, isEmpty);
    });

    test('taking over its own session (the browser\'s handover QR scanned after a resume) drops the old '
        'credential without reporting it as handed over', () async {
      await http.runWithClient(() async {
        final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
        final events = <ProofingSessionEvent>[];
        coordinator.events.listen(events.add);
        const old = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-old');
        // No changeKey, so tracking doesn't start long-polling.
        coordinator.track(old, ProofingSessionInfo.fromJson(_view()));

        final claim = await coordinator.connect(ProofingSessionLink.parse('vcmrtd://verify?handover=h-2&api=$_api')!);
        expect(claim.ref.deviceToken, 'dev-1');
        expect(coordinator.held, isNull);

        // The old credential's watcher or resume check now hears 403
        // device_handed_over: that's this app itself, not another device.
        coordinator.reportAccessLost(old, ProofingAccessDenial.handedOver);
        await _settle();
        expect(events, isEmpty);

        // The new credential is still known and is reported when it's lost.
        coordinator.track(claim.ref, claim.info);
        coordinator.reportAccessLost(claim.ref, ProofingAccessDenial.handedOver);
        await _settle();
        expect(events.single, isA<ProofingSessionAccessLost>().having((e) => e.ref.deviceToken, 'device', 'dev-1'));
      }, () => MockClient((request) async => _json(_claimBody())));
    });

    test('the browser\'s own handover QR is explained, not claimed', () async {
      final link = ProofingSessionLink.parse('$_api/api/v1/db-test/proofing?handover=web-1');
      expect(link, isA<ProofingBrowserHandoverLink>());
      final requests = <String>[];
      await http.runWithClient(
        () async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          await expectLater(
            coordinator.connect(link!),
            throwsA(
              isA<ProofingSessionAccessException>().having(
                (e) => e.reason,
                'reason',
                ProofingAccessDenial.browserHandover,
              ),
            ),
          );
        },
        () => MockClient((request) async {
          requests.add(request.url.path);
          return _json(_claimBody());
        }),
      );
      expect(requests, isEmpty);
    });

    test('connect refuses a used handover QR', () async {
      await http.runWithClient(() async {
        final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
        await expectLater(
          coordinator.connect(ProofingSessionLink.parse('vcmrtd://verify?handover=h-1&api=$_api')!),
          throwsA(
            isA<ProofingSessionAccessException>().having((e) => e.reason, 'reason', ProofingAccessDenial.handoverUsed),
          ),
        );
      }, () => MockClient((request) async => _refused(409, 'handover_used')));
    });

    group('lifecycle', () {
      const ref = ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-1');
      // No changeKey, so tracking doesn't start long-polling in these tests.
      final info = ProofingSessionInfo.fromJson(_view());

      test('reports inactive when backgrounded and active on return, but ignores a plain inactive', () async {
        final states = <String>[];
        await http.runWithClient(
          () async {
            final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
            final events = <ProofingSessionEvent>[];
            coordinator.events.listen(events.add);
            coordinator.track(ref, info);

            // e.g. the iOS NFC sheet: not a trip to the background.
            coordinator.appLifecycleChanged(AppLifecycleState.inactive);
            coordinator.appLifecycleChanged(AppLifecycleState.resumed);
            await _settle();
            expect(states, isEmpty);

            coordinator.appLifecycleChanged(AppLifecycleState.inactive);
            coordinator.appLifecycleChanged(AppLifecycleState.hidden);
            coordinator.appLifecycleChanged(AppLifecycleState.paused);
            await _settle();
            coordinator.appLifecycleChanged(AppLifecycleState.hidden);
            coordinator.appLifecycleChanged(AppLifecycleState.inactive);
            coordinator.appLifecycleChanged(AppLifecycleState.resumed);
            expect(coordinator.check.value, ProofingSessionCheck.checking);
            await _settle();
            await _settle();
            expect(coordinator.check.value, ProofingSessionCheck.idle);
            expect(events.single, isA<ProofingSessionUpdated>());
          },
          () => MockClient((request) async {
            expect(request.url.path, '/api/v1/app/tok-1/device/state');
            expect(request.headers['X-Device-Token'], 'dev-1');
            states.add((json.decode(request.body) as Map)['state'] as String);
            return _json(_view());
          }),
        );
        expect(states, ['inactive', 'active']);
      });

      test('ends the session when the server says it was handed over while backgrounded', () async {
        var calls = 0; // http.runWithClient builds a new client per request
        await http.runWithClient(() async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          final events = <ProofingSessionEvent>[];
          coordinator.events.listen(events.add);
          coordinator.track(ref, info);
          coordinator.appLifecycleChanged(AppLifecycleState.hidden);
          await _settle();
          expect(events, isEmpty); // the inactive report still went through

          coordinator.appLifecycleChanged(AppLifecycleState.resumed);
          await _settle();
          await _settle();
          expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.handedOver);
          expect(coordinator.held, isNull);
          expect(coordinator.check.value, ProofingSessionCheck.idle);
        }, () => MockClient((request) async => ++calls == 1 ? _json(_view()) : _refused(403, 'device_handed_over')));
      });

      test('ends the session when it expired while backgrounded', () async {
        await http.runWithClient(() async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          final events = <ProofingSessionEvent>[];
          coordinator.events.listen(events.add);
          coordinator.track(ref, info);
          coordinator.appLifecycleChanged(AppLifecycleState.paused);
          coordinator.appLifecycleChanged(AppLifecycleState.resumed);
          await _settle();
          await _settle();
          expect((events.single as ProofingSessionAccessLost).reason, ProofingAccessDenial.expired);
        }, () => MockClient((request) async => _refused(410, 'session_expired')));
      });

      test('keeps blocking while the server is unreachable, then continues once it confirms', () async {
        var calls = 0;
        await http.runWithClient(
          () async {
            final coordinator = ProofingSessionCoordinator(
              client: const ProofingSessionClient(),
              retryDelay: const Duration(milliseconds: 1),
            );
            final events = <ProofingSessionEvent>[];
            coordinator.events.listen(events.add);
            coordinator.track(ref, info);
            final checks = <ProofingSessionCheck>[];
            coordinator.check.addListener(() => checks.add(coordinator.check.value));
            coordinator.appLifecycleChanged(AppLifecycleState.hidden);
            await _settle();
            coordinator.appLifecycleChanged(AppLifecycleState.resumed);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            expect(checks, [
              ProofingSessionCheck.checking,
              ProofingSessionCheck.unreachable,
              ProofingSessionCheck.idle,
            ]);
            expect(events.single, isA<ProofingSessionUpdated>());
          },
          () => MockClient((request) async {
            calls++;
            if (calls == 2) throw http.ClientException('offline'); // first "active" report
            return _json(_view());
          }),
        );
      });

      test('a session submitted on the other device while backgrounded ends as completed, and stops the '
          'device state reports', () async {
        final requests = <String>[];
        await http.runWithClient(
          () async {
            final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
            final events = <ProofingSessionEvent>[];
            coordinator.events.listen(events.add);
            coordinator.track(ref, info);
            coordinator.appLifecycleChanged(AppLifecycleState.hidden);
            await _settle();
            coordinator.appLifecycleChanged(AppLifecycleState.resumed);
            await _settle();
            await _settle();
            expect(events.single, isA<ProofingSessionCompleted>());
            expect(coordinator.held, isNull);
            expect(coordinator.check.value, ProofingSessionCheck.idle);

            coordinator.appLifecycleChanged(AppLifecycleState.hidden);
            coordinator.appLifecycleChanged(AppLifecycleState.resumed);
            await _settle();
          },
          () => MockClient((request) async {
            requests.add((json.decode(request.body) as Map)['state'] as String);
            return requests.length == 1 ? _json(_view()) : _refused(409, 'session_complete');
          }),
        );
        expect(requests, ['inactive', 'active']);
      });

      test('reportCompleted ends the session once, and a late session_complete refusal adds nothing', () async {
        final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
        final events = <ProofingSessionEvent>[];
        final sub = coordinator.events.listen(events.add);
        coordinator.track(ref, info);
        coordinator.reportCompleted(ref);
        coordinator.reportCompleted(ref);
        coordinator.reportAccessLost(ref, ProofingAccessDenial.complete);
        await _settle();
        expect(events.single, isA<ProofingSessionCompleted>());
        expect(coordinator.held, isNull);
        await sub.cancel();
      });

      test('passes a loss on only once', () async {
        final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
        final events = <ProofingSessionEvent>[];
        final sub = coordinator.events.listen(events.add);
        coordinator.track(ref, info);
        coordinator.reportAccessLost(ref, ProofingAccessDenial.handedOver);
        coordinator.reportAccessLost(ref, ProofingAccessDenial.handedOver);
        await _settle();
        expect(events, hasLength(1));
        await sub.cancel();
      });

      test('reports nothing without a held session', () async {
        await http.runWithClient(() async {
          final coordinator = ProofingSessionCoordinator(client: const ProofingSessionClient());
          coordinator.appLifecycleChanged(AppLifecycleState.hidden);
          coordinator.appLifecycleChanged(AppLifecycleState.resumed);
          await _settle();
          expect(coordinator.check.value, ProofingSessionCheck.idle);
        }, () => MockClient((request) async => fail('no request expected')));
      });
    });
  });
}
