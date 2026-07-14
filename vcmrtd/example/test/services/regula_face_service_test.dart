import 'dart:convert';

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

/// A fake [FaceSDK] backed by [noSuchMethod]; only the members the service
/// touches are overridden.
class _FakeFaceSdk implements FaceSDK {
  _FakeFaceSdk({this.alreadyInitialized = false, this.initSucceeds = true, LivenessResponse? liveness})
    : _liveness = liveness;

  final bool alreadyInitialized;
  final bool initSucceeds;
  final LivenessResponse? _liveness;

  int initializeCalls = 0;
  int startLivenessCalls = 0;
  String? assignedServiceUrl;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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

  group('regulaFaceServiceProvider', () {
    test('exposes a RegulaFaceServiceImpl configured for the face api url', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(faceApiUrlProvider), RegulaFaceServiceImpl.defaultServiceUrl);
      expect(container.read(regulaFaceServiceProvider), isA<RegulaFaceServiceImpl>());
    });
  });
}
