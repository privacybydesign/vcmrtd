import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_landmarker_types.dart';
import 'package:face_verification/src/detection/face_observation.dart';
import 'package:face_verification/src/face_verification_worker.dart';

// ---------------------------------------------------------------------------
// Helpers (mirrors of the fakes in face_verification_worker_test.dart but kept
// local to this file so the two suites stay independent).
// ---------------------------------------------------------------------------

FaceObservation _makeFace({double yaw = 5.0}) {
  final landmarks = List<NormalizedLandmark>.generate(478, (i) => NormalizedLandmark(i * 0.001, i * 0.001 + 0.001, 0));
  final blendshapes = <String, double>{'jawOpen': 0.1};
  final result = FaceLandmarkerResult(
    landmarks: <List<NormalizedLandmark>>[landmarks],
    blendshapes: <List<Category>>[blendshapes.entries.map((e) => Category(e.key, e.value)).toList()],
  );
  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(10, 20, 100, 120),
    boundingBoxAreaRatio: 0.15,
    boundingBoxCenter: const Offset(0.5, 0.5),
    mouthRatio: 0.03,
    yawDegrees: yaw,
    blendshapeScores: blendshapes,
    alignedFace112: img.Image(width: 112, height: 112),
  );
}

class _FakeWorkerClient implements FaceVerificationWorkerClient {
  final List<String> commands = <String>[];
  final List<Map<String, dynamic>?> payloads = <Map<String, dynamic>?>[];
  Future<Map<String, dynamic>> Function(String cmd, Map<String, dynamic>? payload)? onRequest;
  final Map<String, Map<String, dynamic>> responses = <String, Map<String, dynamic>>{};
  bool disposed = false;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<Map<String, dynamic>> request(String cmd, {Map<String, dynamic>? payload}) async {
    commands.add(cmd);
    payloads.add(payload);
    final handler = onRequest;
    if (handler != null) return handler(cmd, payload);
    return responses[cmd] ?? <String, dynamic>{'ok': true};
  }
}

class _FakeCameraBuffer implements FaceVerificationCameraBuffer {
  _FakeCameraBuffer({this.byteCapacity = 1024 * 1024});

  static const int free = 0;
  static const int writing = 1;
  static const int ready = 2;
  static const int pipelineReading = 3;
  static const int passiveReady = 4;
  static const int passiveReading = 5;

  int state = free;

  @override
  final int byteCapacity;

  @override
  int get address => identityHashCode(this);

  bool disposed = false;
  int pipelineReleaseWithoutPassive = 0;
  int passiveReleaseCount = 0;

  @override
  bool beginWrite() {
    if (state != free) return false;
    state = writing;
    return true;
  }

  @override
  void abortWrite() => state = free;

  @override
  void commitWrite(int width, int height, int channels) => state = ready;

  @override
  bool beginPipelineRead() {
    if (state != ready) return false;
    state = pipelineReading;
    return true;
  }

  @override
  void endPipelineRead({required bool handoffToPassive}) {
    if (handoffToPassive) {
      state = passiveReady;
    } else {
      pipelineReleaseWithoutPassive++;
      state = free;
    }
  }

  @override
  bool beginPassiveRead() {
    if (state != passiveReady) return false;
    state = passiveReading;
    return true;
  }

  @override
  void endPassiveRead() {
    passiveReleaseCount++;
    state = free;
  }

  @override
  bool writePlaneBytes(List<Uint8List> planesData) => true;

  @override
  void dispose() => disposed = true;
}

class _DebugWorkerHarness {
  _DebugWorkerHarness._(this._isolate, this._receivePort, this._sendPort);

  final Isolate _isolate;
  final ReceivePort _receivePort;
  final SendPort _sendPort;
  int _id = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};
  StreamSubscription<dynamic>? _subscription;

  static Future<_DebugWorkerHarness> spawn(void Function(SendPort) entry) async {
    final receivePort = ReceivePort();
    final harnessCompleter = Completer<_DebugWorkerHarness>();
    final isolate = await Isolate.spawn(entry, receivePort.sendPort);
    late _DebugWorkerHarness harness;

    final sub = receivePort.listen((dynamic message) {
      if (message is SendPort) {
        harness = _DebugWorkerHarness._(isolate, receivePort, message);
        if (!harnessCompleter.isCompleted) harnessCompleter.complete(harness);
        return;
      }
      if (message is Map && harnessCompleter.isCompleted) {
        final id = message['id'] as int?;
        if (id == null) return;
        final completer = harness._pending.remove(id);
        if (completer == null) return;
        if (message['error'] != null) {
          completer.completeError(StateError(message['error'].toString()));
        } else {
          completer.complete((message['result'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
        }
      }
    });

    final result = await harnessCompleter.future;
    result._subscription = sub;
    return result;
  }

  Future<Map<String, dynamic>> request(String cmd, {Map<String, dynamic>? payload}) {
    final id = ++_id;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _sendPort.send(<String, dynamic>{'id': id, 'cmd': cmd, 'payload': payload ?? <String, dynamic>{}});
    return completer.future;
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    await _subscription?.cancel();
    _receivePort.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FaceVerificationWorker — pipeline result branches', () {
    late _FakeWorkerClient pipeline;
    late _FakeWorkerClient passive;
    late _FakeWorkerClient match;

    FaceVerificationWorker buildWorker(List<_FakeCameraBuffer> buffers) {
      pipeline = _FakeWorkerClient();
      passive = _FakeWorkerClient();
      match = _FakeWorkerClient();
      return FaceVerificationWorker.withClients(
        pipeline: pipeline,
        passive: passive,
        match: match,
        cameraBuffers: buffers,
      );
    }

    Future<void> processFrame(FaceVerificationWorker worker, int marker) {
      return worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[marker]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );
    }

    Map<String, dynamic> serializedFace({double yaw = 5.0}) =>
        FaceVerificationWorker.debugSerializeFace(_makeFace(yaw: yaw));

    test('null-face pipeline result emits a null-face frame and never enqueues passive', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final frameResult = worker.debugFrames.first;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          expect(buffer.beginPipelineRead(), isTrue);
          buffer.endPipelineRead(handoffToPassive: false);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': null});
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processFrame(worker, 1);
      final result = await frameResult;
      await worker.debugWaitPipelineIdle();
      await worker.debugWaitPassiveIdle();

      expect(result.face, isNull);
      expect(passive.commands, isNot(contains('collect_frame')));
      expect(buffer.pipelineReleaseWithoutPassive, 1);
    });

    test('stale pipeline result with NULL face after stop does not touch the buffer', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final pipelineResponse = Completer<Map<String, dynamic>>();

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') return pipelineResponse.future;
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processFrame(worker, 1);
      final stopFuture = worker.stop();

      // Simulate the pipeline having released the buffer to FREE on a no-face frame.
      expect(buffer.beginPipelineRead(), isTrue);
      buffer.endPipelineRead(handoffToPassive: false);
      // Resolve the in-flight request with a NULL face AFTER the session changed.
      pipelineResponse.complete(<String, dynamic>{'face': null});

      await stopFuture;

      // _releaseStalePipelineResult returns early on null face → no passive release.
      expect(buffer.passiveReleaseCount, 0);
      expect(passive.commands, isNot(contains('collect_frame')));
    });

    test('startSession after in-flight frames resets busy flags and completes idle waiters', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final pipelineResponse = Completer<Map<String, dynamic>>();

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') return pipelineResponse.future;
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processFrame(worker, 1);

      // Pipeline is busy (request not yet resolved). startSession bumps the
      // session, evicts queues, waits idle, then resets _pipelineBusy.
      final startFuture = worker.startSession();

      // Release the buffer + resolve the stale in-flight result so idle completes.
      expect(buffer.beginPipelineRead(), isTrue);
      buffer.endPipelineRead(handoffToPassive: false);
      pipelineResponse.complete(<String, dynamic>{'face': null});

      await startFuture;

      expect(worker.debugSessionId, 1);
      expect(pipeline.commands, contains('start_session'));
      await expectLater(worker.debugWaitPipelineIdle(), completes);
      await expectLater(worker.debugWaitPassiveIdle(), completes);
    });

    test('two faces in same session each enqueue passive collect_frame', () async {
      final buffers = <_FakeCameraBuffer>[_FakeCameraBuffer(), _FakeCameraBuffer()];
      final worker = buildWorker(buffers);

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          final idx = payload!['camBufIdx'] as int;
          expect(buffers[idx].beginPipelineRead(), isTrue);
          buffers[idx].endPipelineRead(handoffToPassive: true);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': serializedFace(yaw: idx.toDouble())});
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };
      passive.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'collect_frame') {
          final idx = payload!['camBufIdx'] as int;
          expect(buffers[idx].beginPassiveRead(), isTrue);
          buffers[idx].endPassiveRead();
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processFrame(worker, 1);
      await worker.debugWaitPipelineIdle();
      await worker.debugWaitPassiveIdle();
      await processFrame(worker, 2);
      await worker.debugWaitPipelineIdle();
      await worker.debugWaitPassiveIdle();

      final collects = passive.commands.where((c) => c == 'collect_frame').length;
      // Each face frame hands off to passive exactly once.
      expect(collects, 2);
      final totalReleases = buffers.fold<int>(0, (sum, b) => sum + b.passiveReleaseCount);
      expect(totalReleases, 2);
    });
  });

  group('FaceVerificationWorker — passive worker isolate edge cases', () {
    test('collect_frame with missing camBufIdx is a no-op returning ok', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPassiveWorkerEntry);
      addTearDown(harness.dispose);

      final result = await harness.request('collect_frame', payload: <String, dynamic>{});
      expect(result['ok'], isTrue);
    });

    test('passive worker rejects unknown command', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPassiveWorkerEntry);
      addTearDown(harness.dispose);

      await expectLater(harness.request('bogus'), throwsA(isA<StateError>()));
    });

    test('passive worker handles dispose', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPassiveWorkerEntry);
      addTearDown(harness.dispose);

      expect(await harness.request('dispose'), containsPair('ok', true));
    });
  });

  group('FaceVerificationWorker — match worker isolate error paths', () {
    test('prepare_nfc_face without a model errors (embedding requires init)', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugMatchWorkerEntry);
      addTearDown(harness.dispose);

      final payload = FaceVerificationWorker.debugImagePayload(img.Image(width: 112, height: 112));
      await expectLater(harness.request('prepare_nfc_face', payload: payload), throwsA(isA<StateError>()));
    });

    test('store_consistency_selfie without a model errors (embedding requires init)', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugMatchWorkerEntry);
      addTearDown(harness.dispose);

      final payload = FaceVerificationWorker.debugImagePayload(img.Image(width: 112, height: 112));
      await expectLater(harness.request('store_consistency_selfie', payload: payload), throwsA(isA<StateError>()));
    });
  });
}
