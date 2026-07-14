import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/providers/face_api_provider.dart';
import 'package:vcmrtdapp/services/regula_face_service.dart';

/// Builds a [LivenessResponse] via its `@visibleForTesting` JSON factory so the
/// service can be exercised without the native SDK.
LivenessResponse _liveness({required bool passed, String? transactionId, bool withImage = true, String? error}) {
  return LivenessResponse.fromJson({
    if (withImage) 'image': base64Encode(const [1, 2, 3]),
    'liveness': passed ? LivenessStatus.PASSED.value : LivenessStatus.UNKNOWN.value,
    'transactionId': transactionId,
    if (error != null) 'error': {'code': LivenessErrorCode.PROCESSING_FAILED.value, 'message': error},
  })!;
}

/// Builds a [MatchFacesResponse]. Pass [similarity] for a comparable pair, or
/// leave it null (with no [error]) to simulate a response with no faces.
MatchFacesResponse _match({double? similarity, String? error}) {
  final image = {
    'image': base64Encode(const [1, 2, 3]),
    'imageType': ImageType.LIVE.value,
    'detectAll': false,
    'identifier': '',
  };
  final face = {'imageIndex': 0, 'image': image, 'faceIndex': 0, 'face': null};
  return MatchFacesResponse.fromJson({
    'results': similarity == null
        ? []
        : [
            {'first': face, 'second': face, 'similarity': similarity, 'score': similarity, 'error': null},
          ],
    'detections': [],
    'tag': null,
    if (error != null) 'error': {'code': MatchFacesErrorCode.PROCESSING_FAILED.value, 'message': error},
  })!;
}

/// A fake [FaceSDK] backed by [noSuchMethod]; only the members the service
/// touches are overridden.
class _FakeFaceSdk implements FaceSDK {
  _FakeFaceSdk({
    this.alreadyInitialized = false,
    this.initSucceeds = true,
    LivenessResponse? liveness,
    MatchFacesResponse? match,
  }) : _liveness = liveness,
       _match = match;

  final bool alreadyInitialized;
  final bool initSucceeds;
  final LivenessResponse? _liveness;
  final MatchFacesResponse? _match;

  int initializeCalls = 0;
  int startLivenessCalls = 0;
  String? assignedServiceUrl;
  MatchFacesRequest? lastMatchRequest;

  @override
  set serviceUrl(String? val) => assignedServiceUrl = val;

  @override
  Future<bool> isInitialized() async => alreadyInitialized;

  @override
  Future<(bool, InitException?)> initialize({InitConfig? config}) async {
    initializeCalls++;
    return (initSucceeds, null);
  }

  @override
  Future<LivenessResponse> startLiveness({
    LivenessConfig? config,
    LivenessNotificationCompletion? notificationCompletion,
    CameraSwitchCallback? cameraSwitchCallback,
  }) async {
    startLivenessCalls++;
    return _liveness!;
  }

  @override
  Future<MatchFacesResponse> matchFaces(MatchFacesRequest request, {MatchFacesConfig? config}) async {
    lastMatchRequest = request;
    return _match!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RegulaFaceResult', () {
    RegulaFaceResult result(double? similarity, {bool isLive = true, double threshold = 0.75}) =>
        RegulaFaceResult(isLive: isLive, matchThreshold: threshold, similarity: similarity);

    test('matched is false when similarity is null', () {
      expect(result(null).matched, isFalse);
    });

    test('matched is false below the threshold', () {
      expect(result(0.74).matched, isFalse);
    });

    test('matched is true at or above the threshold', () {
      expect(result(0.75).matched, isTrue);
      expect(result(0.9).matched, isTrue);
    });

    test('passed requires both liveness and a match', () {
      expect(result(0.9, isLive: true).passed, isTrue);
      expect(result(0.9, isLive: false).passed, isFalse);
      expect(result(0.5, isLive: true).passed, isFalse);
    });
  });

  test('RegulaLivenessResult carries the liveness verdict and transaction id', () {
    const r = RegulaLivenessResult(isLive: true, transactionId: 'tx-1');
    expect(r.isLive, isTrue);
    expect(r.transactionId, 'tx-1');
  });

  group('RegulaFaceServiceImpl.initialize', () {
    test('points the SDK at the service url and initializes once', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: true));
      final service = RegulaFaceServiceImpl(serviceUrl: 'https://faceapi.test', sdk: sdk);

      await service.initialize();
      await service.initialize();

      expect(sdk.assignedServiceUrl, 'https://faceapi.test');
      expect(sdk.initializeCalls, 1);
    });

    test('skips initialize() when the SDK is already initialized', () async {
      final sdk = _FakeFaceSdk(alreadyInitialized: true);
      final service = RegulaFaceServiceImpl(sdk: sdk);

      await service.initialize();

      expect(sdk.initializeCalls, 0);
    });

    test('throws when SDK initialization fails', () async {
      final sdk = _FakeFaceSdk(initSucceeds: false);
      final service = RegulaFaceServiceImpl(sdk: sdk);

      expect(service.initialize(), throwsA(isA<StateError>()));
    });
  });

  group('RegulaFaceServiceImpl.captureLiveness', () {
    test('reports a live verdict and the transaction id', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: true, transactionId: 'tx-42'));
      final service = RegulaFaceServiceImpl(sdk: sdk);

      final result = await service.captureLiveness();

      expect(result.isLive, isTrue);
      expect(result.transactionId, 'tx-42');
    });

    test('reports a non-live verdict when liveness does not pass', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: false, transactionId: 'tx-9'));
      final service = RegulaFaceServiceImpl(sdk: sdk);

      final result = await service.captureLiveness();

      expect(result.isLive, isFalse);
    });

    test('throws when the liveness session reports an error', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: false, error: 'boom'));
      final service = RegulaFaceServiceImpl(sdk: sdk);

      expect(service.captureLiveness(), throwsA(isA<StateError>()));
    });
  });

  group('RegulaFaceServiceImpl.verifyAgainstDocument', () {
    final portrait = Uint8List.fromList(const [9, 8, 7]);

    test('matches the live face against the document portrait when live', () async {
      final sdk = _FakeFaceSdk(
        liveness: _liveness(passed: true, transactionId: 'tx-1'),
        match: _match(similarity: 0.9),
      );
      final service = RegulaFaceServiceImpl(sdk: sdk, matchThreshold: 0.75);

      final result = await service.verifyAgainstDocument(portrait);

      expect(result.isLive, isTrue);
      expect(result.similarity, 0.9);
      expect(result.matched, isTrue);
      expect(result.passed, isTrue);
      expect(result.transactionId, 'tx-1');
      expect(sdk.lastMatchRequest, isNotNull);
    });

    test('skips the match when liveness fails', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: false));
      final service = RegulaFaceServiceImpl(sdk: sdk);

      final result = await service.verifyAgainstDocument(portrait);

      expect(result.isLive, isFalse);
      expect(result.similarity, isNull);
      expect(result.passed, isFalse);
      expect(sdk.lastMatchRequest, isNull);
    });

    test('skips the match when the document portrait is empty', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: true));
      final service = RegulaFaceServiceImpl(sdk: sdk);

      final result = await service.verifyAgainstDocument(Uint8List(0));

      expect(result.isLive, isTrue);
      expect(result.similarity, isNull);
      expect(sdk.lastMatchRequest, isNull);
    });

    test('throws when the match step reports an error', () async {
      final sdk = _FakeFaceSdk(
        liveness: _liveness(passed: true),
        match: _match(error: 'match boom'),
      );
      final service = RegulaFaceServiceImpl(sdk: sdk);

      expect(service.verifyAgainstDocument(portrait), throwsA(isA<StateError>()));
    });

    test('throws when the match step returns no comparable faces', () async {
      final sdk = _FakeFaceSdk(liveness: _liveness(passed: true), match: _match());
      final service = RegulaFaceServiceImpl(sdk: sdk);

      expect(service.verifyAgainstDocument(portrait), throwsA(isA<StateError>()));
    });
  });

  group('regulaFaceServiceProvider', () {
    test('exposes a RegulaFaceServiceImpl configured for the face api url', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(faceApiUrlProvider), RegulaFaceServiceImpl.defaultServiceUrl);
      expect(container.read(regulaFaceServiceProvider), isA<RegulaFaceServiceImpl>());
    });
  });
}
