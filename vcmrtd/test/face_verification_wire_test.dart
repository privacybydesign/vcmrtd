// Wire-level tests for the face verification method comparison: what the
// wallet declares at start-validation, how the issuer's assignment is parsed,
// and the Iris fields on the verify response and the issuance request.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vcmrtd/vcmrtd.dart';

void main() {
  group('FaceVerificationMethod', () {
    test('round-trips its wire names', () {
      for (final method in FaceVerificationMethod.values) {
        expect(FaceVerificationMethod.tryParse(method.wireName), method);
      }
      expect(FaceVerificationMethod.regula.wireName, 'regula');
      expect(FaceVerificationMethod.iris.wireName, 'iris');
      expect(FaceVerificationMethod.irisOndevice.wireName, 'iris_ondevice');
    });

    test('an unknown or non-string wire value parses to null', () {
      expect(FaceVerificationMethod.tryParse('holo'), isNull);
      expect(FaceVerificationMethod.tryParse(''), isNull);
      expect(FaceVerificationMethod.tryParse(null), isNull);
      expect(FaceVerificationMethod.tryParse(3), isNull);
    });
  });

  group('StartValidationRequest body', () {
    test('no request means no body, as wallets before the declaration sent', () {
      expect(DefaultPassportIssuer.startValidationBody(null), isNull);
    });

    test('declares the capabilities and nothing else on a first attempt', () {
      final body = DefaultPassportIssuer.startValidationBody(
        const StartValidationRequest(capabilities: [FaceVerificationMethod.regula, FaceVerificationMethod.iris]),
      );
      expect(body, {
        'face_verification': {
          'capabilities': ['regula', 'iris'],
        },
      });
    });

    test('carries the sticky-retry fields, the preference and the client block', () {
      final body = DefaultPassportIssuer.startValidationBody(
        const StartValidationRequest(
          capabilities: [FaceVerificationMethod.regula, FaceVerificationMethod.iris],
          previousMethod: FaceVerificationMethod.iris,
          attempt: 2,
          preferredMethod: FaceVerificationMethod.iris,
          client: ClientInfo(platform: 'android', flavor: 'play', appVersion: '8.3.0'),
        ),
      );
      expect(body, {
        'face_verification': {
          'capabilities': ['regula', 'iris'],
          'previous_method': 'iris',
          'attempt': 2,
          'preferred_method': 'iris',
        },
        'client': {'platform': 'android', 'flavor': 'play', 'app_version': '8.3.0'},
      });
    });

    test('a build with the on-device method declares it too', () {
      final body = DefaultPassportIssuer.startValidationBody(
        const StartValidationRequest(
          capabilities: [
            FaceVerificationMethod.regula,
            FaceVerificationMethod.iris,
            FaceVerificationMethod.irisOndevice,
          ],
        ),
      );
      expect(body!['face_verification'], {
        'capabilities': ['regula', 'iris', 'iris_ondevice'],
      });
    });

    test('a Regula-only build declares just regula', () {
      final body = DefaultPassportIssuer.startValidationBody(
        const StartValidationRequest(capabilities: [FaceVerificationMethod.regula]),
      );
      expect(body!['face_verification'], {
        'capabilities': ['regula'],
      });
    });
  });

  group('parseStartValidationResponse: the four announcement shapes', () {
    const base = {'session_id': 'sess-1', 'nonce': 'nonce-1'};

    test('absent → no face verification', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse(base);
      expect(result.faceVerification, isNull);
    });

    test('method regula with a face_api_url → Regula with that url', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'regula', 'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.regula);
      expect(result.faceVerification?.faceApiUrl, 'https://faceapi.example');
    });

    test('face_api_url without a method (issuers before the method field) → Regula', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.regula);
      expect(result.faceVerification?.faceApiUrl, 'https://faceapi.example');
    });

    test('method iris → Iris without a Face API url', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'iris'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.iris);
      expect(result.faceVerification?.faceApiUrl, isNull);
    });

    test('method iris ignores a face_api_url the issuer happens to include', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'iris', 'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.iris);
      expect(result.faceVerification?.faceApiUrl, isNull);
    });

    test('method iris_ondevice → on-device Iris, with nothing to address', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'iris_ondevice'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.irisOndevice);
      expect(result.faceVerification?.faceApiUrl, isNull);
    });

    test('method iris_ondevice ignores a face_api_url the issuer happens to include', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'iris_ondevice', 'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification?.method, FaceVerificationMethod.irisOndevice);
      expect(result.faceVerification?.faceApiUrl, isNull);
    });

    test('method regula without a usable face_api_url is treated as absent', () {
      for (final announcement in [
        {'method': 'regula'},
        {'method': 'regula', 'face_api_url': 'http://faceapi.example'},
        {'method': 'regula', 'face_api_url': ''},
      ]) {
        final result = DefaultPassportIssuer.parseStartValidationResponse({...base, 'face_verification': announcement});
        expect(result.faceVerification, isNull, reason: 'for $announcement');
      }
    });

    // A method this build cannot run is not an error the wallet can act on:
    // the flow skips the step and the issuer rejects issuance for missing
    // evidence with its self-explanatory "please update" body.
    test('an unknown method is treated as absent, even with a face_api_url', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 'holo', 'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification, isNull);
    });

    test('a method that is not a string is treated as absent', () {
      final result = DefaultPassportIssuer.parseStartValidationResponse({
        ...base,
        'face_verification': {'method': 1, 'face_api_url': 'https://faceapi.example'},
      });
      expect(result.faceVerification, isNull);
    });
  });

  group('FaceVerificationConfig', () {
    test('defaults to Regula so existing call sites keep their meaning', () {
      const config = FaceVerificationConfig(faceApiUrl: 'https://faceapi.example');
      expect(config.method, FaceVerificationMethod.regula);
    });
  });

  group('VerificationResponse.faceSession', () {
    test('parses the Iris face session announced by the issuer', () {
      final response = VerificationResponse.fromJson({
        'authentic_content': true,
        'authentic_chip': true,
        'is_expired': false,
        'face_session': {
          'face_session_id': 'fs_1',
          'stream_url': 'wss://iris-verifier.example/stream/fs_1',
          'token': 'tok',
          'expires_in': 600,
        },
      });
      expect(response.faceSession, isNotNull);
      expect(response.faceSession!.faceSessionId, 'fs_1');
      expect(response.faceSession!.streamUrl, 'wss://iris-verifier.example/stream/fs_1');
      expect(response.faceSession!.token, 'tok');
      expect(response.faceSession!.expiresIn, 600);
    });

    test('is null when the issuer announced none (Regula session or old issuer)', () {
      final response = VerificationResponse.fromJson({
        'authentic_content': true,
        'authentic_chip': true,
        'is_expired': false,
        'face_match': {'matched': true, 'similarity': 0.9},
      });
      expect(response.faceSession, isNull);
      expect(response.faceMatch?.matched, isTrue);
    });

    test('round-trips through JSON', () {
      final original = FaceSession(faceSessionId: 'fs_2', streamUrl: 'wss://x/stream/fs_2', token: 't', expiresIn: 5);
      final restored = FaceSession.fromJson(original.toJson());
      expect(restored.faceSessionId, 'fs_2');
      expect(restored.streamUrl, 'wss://x/stream/fs_2');
      expect(restored.token, 't');
      expect(restored.expiresIn, 5);
    });
  });

  group('RawDocumentData Iris fields', () {
    RawDocumentData document() => RawDocumentData(
      dataGroups: const {'DG1': 'aa', 'DG2': 'bb'},
      efSod: '0102',
      sessionId: 'session-1',
      nonce: Uint8List.fromList([1, 2, 3, 4]),
      aaSignature: Uint8List.fromList([9, 9]),
    );

    test('are omitted from JSON when unset, so the Regula request is unchanged', () {
      final json = document().toJson();
      expect(json.containsKey('face_session_id'), isFalse);
      expect(json.containsKey('face_attempt'), isFalse);
      expect(json.containsKey('face_duration_ms'), isFalse);
      expect(json.containsKey('liveness_transaction_id'), isFalse);
    });

    test('are serialised under their wire names when set', () {
      final json = document().copyWith(faceSessionId: 'fs_1', faceAttempt: 2, faceDurationMs: 4200).toJson();
      expect(json['face_session_id'], 'fs_1');
      expect(json['face_attempt'], 2);
      expect(json['face_duration_ms'], 4200);
    });

    test('copyWith preserves every other field and earlier evidence', () {
      final original = document().copyWith(livenessTransactionId: 'txn-1');
      final copy = original.copyWith(faceSessionId: 'fs_1', faceAttempt: 1, faceDurationMs: 10);
      expect(copy.dataGroups, original.dataGroups);
      expect(copy.efSod, original.efSod);
      expect(copy.sessionId, original.sessionId);
      expect(copy.nonce, original.nonce);
      expect(copy.aaSignature, original.aaSignature);
      expect(copy.livenessTransactionId, 'txn-1');
      expect(copy.faceSessionId, 'fs_1');
      expect(copy.faceAttempt, 1);
      expect(copy.faceDurationMs, 10);
    });

    test('round-trip through JSON keeps the Iris fields', () {
      final restored = RawDocumentData.fromJson(
        document().copyWith(faceSessionId: 'fs_1', faceAttempt: 3, faceDurationMs: 99).toJson(),
      );
      expect(restored.faceSessionId, 'fs_1');
      expect(restored.faceAttempt, 3);
      expect(restored.faceDurationMs, 99);
    });
  });

  group('RawDocumentData on-device Iris fields', () {
    RawDocumentData document() => RawDocumentData(
      dataGroups: const {'DG1': 'aa', 'DG2': 'bb'},
      efSod: '0102',
      sessionId: 'session-1',
      nonce: Uint8List.fromList([1, 2, 3, 4]),
      aaSignature: Uint8List.fromList([9, 9]),
    );

    test('are omitted from JSON when unset', () {
      final json = document().toJson();
      expect(json.containsKey('face_ondevice_passed'), isFalse);
      expect(json.containsKey('face_ondevice_portrait_sha256'), isFalse);
      expect(json.containsKey('face_ondevice_distance'), isFalse);
    });

    test('a passing verdict is serialised with the portrait it was obtained against', () {
      final json = document().copyWith(faceOndevicePassed: true, faceOndevicePortraitSha256: 'ab12').toJson();
      expect(json['face_ondevice_passed'], isTrue);
      expect(json['face_ondevice_portrait_sha256'], 'ab12');
    });

    // The whole point of reporting failures: `false` must reach the issuer as
    // `false`, not be dropped as if the step had never run. Absent means "not
    // attempted" and is answered with a different error.
    test('a failing verdict is serialised as false, not omitted', () {
      final json = document().copyWith(faceOndevicePassed: false, faceOndevicePortraitSha256: 'ab12').toJson();
      expect(json.containsKey('face_ondevice_passed'), isTrue);
      expect(json['face_ondevice_passed'], isFalse);
    });

    test('round-trip through JSON keeps both values, including false', () {
      final restored = RawDocumentData.fromJson(
        document().copyWith(faceOndevicePassed: false, faceOndevicePortraitSha256: 'ab12').toJson(),
      );
      expect(restored.faceOndevicePassed, isFalse);
      expect(restored.faceOndevicePortraitSha256, 'ab12');
    });

    // Recording only: the issuer logs it under its own score kind and gates on
    // the verdict alone. Nothing populates it while the vendor's mobile SDK
    // reports no distance, so what is pinned here is that the wire carries it
    // the moment something does.
    test('a reported distance is serialised and round-trips', () {
      final json = document()
          .copyWith(faceOndevicePassed: true, faceOndevicePortraitSha256: 'ab12', faceOndeviceDistance: 0.41)
          .toJson();
      expect(json['face_ondevice_distance'], 0.41);

      final restored = RawDocumentData.fromJson(json);
      expect(restored.faceOndeviceDistance, 0.41);
      expect(restored.faceOndevicePassed, isTrue);
    });

    // A distance is as interesting on a rejection as on a pass, so it is not
    // tied to a passing verdict.
    test('a distance rides along with a failing verdict too', () {
      final json = document().copyWith(faceOndevicePassed: false, faceOndeviceDistance: 0.93).toJson();
      expect(json['face_ondevice_passed'], isFalse);
      expect(json['face_ondevice_distance'], 0.93);
    });

    test('copyWith preserves them alongside the recording fields', () {
      final copy = document().copyWith(
        faceOndevicePassed: true,
        faceOndevicePortraitSha256: 'ab12',
        faceAttempt: 2,
        faceDurationMs: 3300,
      );
      expect(copy.faceOndevicePassed, isTrue);
      expect(copy.faceOndevicePortraitSha256, 'ab12');
      expect(copy.faceAttempt, 2);
      expect(copy.faceDurationMs, 3300);
      expect(copy.faceSessionId, isNull);
      expect(copy.livenessTransactionId, isNull);
    });
  });
}
