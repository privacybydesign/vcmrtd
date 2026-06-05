import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_observation.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_worker.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FaceObservation _makeFace({double yaw = 5.0, double mouthRatio = 0.03}) {
  final landmarks = List<NormalizedLandmark>.generate(478, (i) => NormalizedLandmark(i * 0.001, i * 0.001 + 0.001, 0));
  final blendshapes = <String, double>{'jawOpen': 0.1, 'mouthSmileLeft': 0.2};
  final result = FaceLandmarkerResult(
    landmarks: [landmarks],
    blendshapes: [blendshapes.entries.map((e) => Category(e.key, e.value)).toList()],
  );
  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(10, 20, 100, 120),
    boundingBoxAreaRatio: 0.15,
    boundingBoxCenter: const Offset(0.5, 0.5),
    mouthRatio: mouthRatio,
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

  bool started = false;
  bool disposed = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<Map<String, dynamic>> request(String cmd, {Map<String, dynamic>? payload}) async {
    commands.add(cmd);
    payloads.add(payload);

    final handler = onRequest;
    if (handler != null) {
      return handler(cmd, payload);
    }

    return responses[cmd] ?? <String, dynamic>{'ok': true};
  }
}

class _FakeCameraBuffer implements FaceVerificationCameraBuffer {
  _FakeCameraBuffer({
    this.byteCapacity = 1024 * 1024,
    this.writeShouldReturnFalse = false,
    this.writeShouldThrow = false,
  });

  static const int free = 0;
  static const int writing = 1;
  static const int ready = 2;
  static const int pipelineReading = 3;
  static const int passiveReady = 4;
  static const int passiveReading = 5;

  int state = free;

  @override
  final int byteCapacity;

  final bool writeShouldReturnFalse;
  final bool writeShouldThrow;

  @override
  int get address => identityHashCode(this);

  bool disposed = false;
  bool aborted = false;
  bool committed = false;
  int committedWidth = 0;
  int committedHeight = 0;
  int committedChannels = 0;
  int writeCalls = 0;
  int pipelineReleaseWithoutPassive = 0;
  int passiveReleaseCount = 0;
  List<Uint8List> writtenPlanes = <Uint8List>[];

  @override
  bool beginWrite() {
    if (state != free) return false;
    state = writing;
    return true;
  }

  @override
  void abortWrite() {
    aborted = true;
    state = free;
  }

  @override
  void commitWrite(int width, int height, int channels) {
    committed = true;
    committedWidth = width;
    committedHeight = height;
    committedChannels = channels;
    state = ready;
  }

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
  bool writePlaneBytes(List<Uint8List> planesData) {
    writeCalls++;
    if (writeShouldThrow) {
      throw StateError('copy failed');
    }
    if (writeShouldReturnFalse) {
      return false;
    }
    writtenPlanes = planesData.map((p) => Uint8List.fromList(p)).toList(growable: false);
    return true;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _FakeCameraImage implements CameraImage {
  _FakeCameraImage({
    required this.width,
    required this.height,
    required ImageFormatGroup formatGroup,
    required this.planes,
  }) : format = _FakeImageFormat(formatGroup);

  @override
  final int width;

  @override
  final int height;

  @override
  final ImageFormat format;

  @override
  final List<Plane> planes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageFormat implements ImageFormat {
  const _FakeImageFormat(this.group);

  @override
  final ImageFormatGroup group;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlane implements Plane {
  _FakePlane({required this.bytes, required this.bytesPerRow, this.bytesPerPixel});

  @override
  final Uint8List bytes;

  @override
  final int bytesPerRow;

  @override
  final int? bytesPerPixel;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DebugWorkerHarness {
  _DebugWorkerHarness._(this._isolate, this._receivePort, this._sendPort);

  final Isolate _isolate;
  final ReceivePort _receivePort;
  final SendPort _sendPort;

  int _id = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};

  static Future<_DebugWorkerHarness> spawn(void Function(SendPort) entry) async {
    final receivePort = ReceivePort();
    final ready = Completer<SendPort>();

    late final StreamSubscription<dynamic> sub;

    final harnessCompleter = Completer<_DebugWorkerHarness>();

    final isolate = await Isolate.spawn(entry, receivePort.sendPort);

    late _DebugWorkerHarness harness;

    sub = receivePort.listen((dynamic message) {
      if (message is SendPort) {
        harness = _DebugWorkerHarness._(isolate, receivePort, message);
        if (!ready.isCompleted) ready.complete(message);
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

    final harnessResult = await harnessCompleter.future;
    harnessResult._subscription = sub;
    return harnessResult;
  }

  Future<Map<String, dynamic>> request(String cmd, {Map<String, dynamic>? payload}) {
    final id = ++_id;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    _sendPort.send(<String, dynamic>{'id': id, 'cmd': cmd, 'payload': payload ?? <String, dynamic>{}});

    return completer.future;
  }

  StreamSubscription<dynamic>? _subscription;

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
  group('FaceVerificationWorker — client orchestration', () {
    late _FakeWorkerClient pipeline;
    late _FakeWorkerClient passive;
    late _FakeWorkerClient match;
    late FaceVerificationWorker worker;

    setUp(() {
      pipeline = _FakeWorkerClient();
      passive = _FakeWorkerClient();
      match = _FakeWorkerClient();

      worker = FaceVerificationWorker.withClients(pipeline: pipeline, passive: passive, match: match);
    });

    test('startSession sends start_session to all worker clients', () async {
      await worker.startSession();

      expect(pipeline.commands, contains('start_session'));
      expect(passive.commands, contains('start_session'));
      expect(match.commands, contains('start_session'));
      expect(worker.debugSessionId, 1);
    });

    test('stop sends stop to all worker clients and increments session', () async {
      await worker.stop();

      expect(pipeline.commands, contains('stop'));
      expect(passive.commands, contains('stop'));
      expect(match.commands, contains('stop'));
      expect(worker.debugSessionId, 1);
    });

    test('getPassiveResult maps passive_result response', () async {
      passive.responses['passive_result'] = <String, dynamic>{
        'antiSpoofScore': 0.77,
        'antiSpoofPassed': true,
        'rppg': <String, dynamic>{'hr': 65.0, 'passed': true, 'sampleCount': 30, 'durationMs': 3000},
      };

      final result = await worker.getPassiveResult();

      expect(passive.commands, contains('passive_result'));
      expect(result.antiSpoofScore, closeTo(0.77, 1e-9));
      expect(result.antiSpoofPassed, isTrue);
      expect(result.rppgHr, closeTo(65.0, 1e-9));
      expect(result.rppgPassed, isTrue);
      expect(result.rppgSampleCount, 30);
      expect(result.rppgDurationMs, 3000);
    });

    test('getPassiveResult uses defaults when passive_result fields are missing', () async {
      passive.responses['passive_result'] = <String, dynamic>{};

      final result = await worker.getPassiveResult();

      expect(result.antiSpoofScore, isNull);
      expect(result.antiSpoofPassed, isFalse);
      expect(result.rppgHr, isNull);
      expect(result.rppgPassed, isFalse);
      expect(result.rppgSampleCount, 0);
      expect(result.rppgDurationMs, 0);
    });

    test('detectAndCropEncoded returns null when pipeline response is not ok', () async {
      pipeline.responses['detect_crop_encoded'] = <String, dynamic>{'ok': false};

      final result = await worker.detectAndCropEncoded(Uint8List.fromList(<int>[1, 2, 3]));

      expect(result, isNull);
      expect(pipeline.commands, contains('detect_crop_encoded'));
    });

    test('detectAndCropEncoded returns decoded image when pipeline returns png', () async {
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 3)));

      pipeline.responses['detect_crop_encoded'] = <String, dynamic>{'ok': true, 'png': png};

      final result = await worker.detectAndCropEncoded(Uint8List.fromList(<int>[1, 2, 3]));

      expect(result, isNotNull);
      expect(result!.width, 2);
      expect(result.height, 3);
    });

    test('checkConsistencySelfie returns score from match client', () async {
      match.responses['check_consistency_selfie'] = <String, dynamic>{'score': 0.42};

      final score = await worker.checkConsistencySelfie(img.Image(width: 112, height: 112));

      expect(match.commands, contains('check_consistency_selfie'));
      expect(score, closeTo(0.42, 1e-9));
    });

    test('checkConsistencySelfie defaults to 1.0 when score is missing', () async {
      match.responses['check_consistency_selfie'] = <String, dynamic>{};

      final score = await worker.checkConsistencySelfie(img.Image(width: 112, height: 112));

      expect(score, closeTo(1.0, 1e-9));
    });

    test('matchSelfie returns score from match client', () async {
      match.responses['match_selfie'] = <String, dynamic>{'score': 0.91};

      final result = await worker.matchSelfie(img.Image(width: 112, height: 112));

      expect(match.commands, contains('match_selfie'));
      expect(result.score, closeTo(0.91, 1e-9));
    });

    test('matchSelfie defaults to zero when score is missing', () async {
      match.responses['match_selfie'] = <String, dynamic>{};

      final result = await worker.matchSelfie(img.Image(width: 112, height: 112));

      expect(result.score, closeTo(0.0, 1e-9));
    });

    test('prepareNfcFace sends image payload to match client', () async {
      await worker.prepareNfcFace(img.Image(width: 112, height: 112));

      expect(match.commands, contains('prepare_nfc_face'));

      final payload = match.payloads.last!;
      expect(payload['width'], 112);
      expect(payload['height'], 112);
      expect(payload['rgb'], isA<Uint8List>());
    });

    test('storeConsistencySelfie sends image payload to match client', () async {
      await worker.storeConsistencySelfie(img.Image(width: 112, height: 112));

      expect(match.commands, contains('store_consistency_selfie'));

      final payload = match.payloads.last!;
      expect(payload['width'], 112);
      expect(payload['height'], 112);
      expect(payload['rgb'], isA<Uint8List>());
    });

    test('detectAndCropEncoded returns null when ok is true but png is missing', () async {
      pipeline.responses['detect_crop_encoded'] = <String, dynamic>{'ok': true};

      final result = await worker.detectAndCropEncoded(Uint8List.fromList(<int>[1, 2, 3]));

      expect(result, isNull);
    });

    test('detectAndCropEncoded returns null when ok is true but png is empty', () async {
      pipeline.responses['detect_crop_encoded'] = <String, dynamic>{'ok': true, 'png': Uint8List(0)};

      final result = await worker.detectAndCropEncoded(Uint8List.fromList(<int>[1, 2, 3]));

      expect(result, isNull);
    });

    test('getPassiveResult maps integer response values too', () async {
      passive.responses['passive_result'] = <String, dynamic>{
        'antiSpoofScore': 1,
        'antiSpoofPassed': true,
        'rppg': <String, dynamic>{'hr': 72, 'passed': true, 'sampleCount': 15.0, 'durationMs': 2400.0},
      };

      final result = await worker.getPassiveResult();

      expect(result.antiSpoofScore, closeTo(1.0, 1e-9));
      expect(result.rppgHr, closeTo(72.0, 1e-9));
      expect(result.rppgSampleCount, 15);
      expect(result.rppgDurationMs, 2400);
    });

    test('getPassiveResult handles missing rppg map', () async {
      passive.responses['passive_result'] = <String, dynamic>{'antiSpoofScore': 0.5, 'antiSpoofPassed': false};

      final result = await worker.getPassiveResult();

      expect(result.antiSpoofScore, closeTo(0.5, 1e-9));
      expect(result.antiSpoofPassed, isFalse);
      expect(result.rppgHr, isNull);
      expect(result.rppgPassed, isFalse);
      expect(result.rppgSampleCount, 0);
      expect(result.rppgDurationMs, 0);
    });

    test('prepareNfcFace payload contains exact rgb length for non-112 image', () async {
      await worker.prepareNfcFace(img.Image(width: 3, height: 2));

      final payload = match.payloads.last!;
      expect(payload['width'], 3);
      expect(payload['height'], 2);
      expect((payload['rgb'] as Uint8List).length, 3 * 2 * 3);
    });

    test('storeConsistencySelfie payload contains exact rgb length for non-112 image', () async {
      await worker.storeConsistencySelfie(img.Image(width: 4, height: 5));

      final payload = match.payloads.last!;
      expect(payload['width'], 4);
      expect(payload['height'], 5);
      expect((payload['rgb'] as Uint8List).length, 4 * 5 * 3);
    });
  });

  group('FaceVerificationWorker — camera buffer pipeline orchestration', () {
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

    Future<void> processPackedFrame(FaceVerificationWorker worker, int marker, {int width = 1, int height = 1}) {
      return worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[marker]),
        ],
        width: width,
        height: height,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );
    }

    Map<String, dynamic> serializedFace({double yaw = 5.0}) =>
        FaceVerificationWorker.debugSerializeFace(_makeFace(yaw: yaw));

    test('debugProcessPackedCameraFrame writes free buffer and sends process_frame', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3, 4]),
        ],
        width: 2,
        height: 2,
        format: 'bgra8888',
        rotationDegrees: 90,
        bytesPerRow: <int>[8],
        bytesPerPixel: <int?>[4],
      );

      await worker.debugWaitPipelineIdle();

      expect(buffer.writeCalls, 1);
      expect(buffer.committed, isTrue);
      expect(buffer.committedWidth, 2);
      expect(buffer.committedHeight, 2);
      expect(buffer.committedChannels, 1);

      expect(pipeline.commands, contains('process_frame'));

      final processPayload = pipeline.payloads.last!;
      expect(processPayload['camBufIdx'], 0);
      expect(processPayload['width'], 2);
      expect(processPayload['height'], 2);
      expect(processPayload['format'], 'bgra8888');
      expect(processPayload['rotation'], 90);
    });

    test('processCameraFrame packs camera plane metadata for the pipeline worker', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      Map<String, dynamic>? processPayload;
      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          processPayload = payload;
          expect(buffer.beginPipelineRead(), isTrue);
          buffer.endPipelineRead(handoffToPassive: false);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': null});
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await worker.processCameraFrame(
        _FakeCameraImage(
          width: 4,
          height: 2,
          formatGroup: ImageFormatGroup.yuv420,
          planes: <Plane>[
            _FakePlane(bytes: Uint8List.fromList(<int>[1, 2, 3, 4]), bytesPerRow: 4, bytesPerPixel: 1),
            _FakePlane(bytes: Uint8List.fromList(<int>[5, 6]), bytesPerRow: 2),
            _FakePlane(bytes: Uint8List.fromList(<int>[7, 8]), bytesPerRow: 2, bytesPerPixel: 2),
          ],
        ),
        270,
      );
      await worker.debugWaitPipelineIdle();

      expect(processPayload, isNotNull);
      expect(processPayload!['width'], 4);
      expect(processPayload!['height'], 2);
      expect(processPayload!['format'], ImageFormatGroup.yuv420.name);
      expect(processPayload!['rotation'], 270);

      final planes = (processPayload!['planes'] as List).cast<Map>();
      expect(planes[0]['offset'], 0);
      expect(planes[0]['byteCount'], 4);
      expect(planes[0]['bytesPerRow'], 4);
      expect(planes[0]['bytesPerPixel'], 1);
      expect(planes[1]['offset'], 4);
      expect(planes[1]['byteCount'], 2);
      expect(planes[1]['bytesPerPixel'], 1);
      expect(planes[2]['offset'], 6);
      expect(planes[2]['byteCount'], 2);
      expect(planes[2]['bytesPerPixel'], 2);
    });

    test('debugProcessPackedCameraFrame drops frame when no buffer is free', () async {
      final buffer = _FakeCameraBuffer()..state = _FakeCameraBuffer.ready;
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );

      expect(buffer.writeCalls, 0);
      expect(pipeline.commands, isNot(contains('process_frame')));
    });

    test('debugProcessPackedCameraFrame aborts oversized frame', () async {
      final buffer = _FakeCameraBuffer(byteCapacity: 2);
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );

      expect(buffer.aborted, isTrue);
      expect(buffer.committed, isFalse);
      expect(pipeline.commands, isNot(contains('process_frame')));
    });

    test('debugProcessPackedCameraFrame aborts when writePlaneBytes returns false', () async {
      final buffer = _FakeCameraBuffer(writeShouldReturnFalse: true);
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await processPackedFrame(worker, 1);

      expect(buffer.writeCalls, 1);
      expect(buffer.aborted, isTrue);
      expect(buffer.committed, isFalse);
      expect(pipeline.commands, isNot(contains('process_frame')));
    });

    test('debugProcessPackedCameraFrame aborts when writePlaneBytes throws', () async {
      final buffer = _FakeCameraBuffer(writeShouldThrow: true);
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await processPackedFrame(worker, 1);

      expect(buffer.writeCalls, 1);
      expect(buffer.aborted, isTrue);
      expect(buffer.committed, isFalse);
      expect(pipeline.commands, isNot(contains('process_frame')));
    });

    test('process frame is ignored when camera buffer pool is disposed', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);

      await worker.dispose();
      await processPackedFrame(worker, 1);

      expect(buffer.writeCalls, 0);
      expect(pipeline.commands, isNot(contains('process_frame')));
    });

    test('pipeline request throws worker stream error and becomes idle', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final streamError = expectLater(worker.debugFrames, emitsError(isA<StateError>()));

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          throw StateError('pipeline failed');
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      await worker.debugWaitPipelineIdle();

      await streamError;
      expect(pipeline.commands, contains('process_frame'));
      await expectLater(worker.debugWaitPipelineIdle(), completes);
    });

    test('pipeline serialized face emits result and enqueues passive collect_frame', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final frameResult = worker.debugFrames.first;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          expect(buffer.beginPipelineRead(), isTrue);
          buffer.endPipelineRead(handoffToPassive: true);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': serializedFace(yaw: 7.0)});
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };
      passive.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'collect_frame') {
          expect(buffer.beginPassiveRead(), isTrue);
          buffer.endPassiveRead();
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      final result = await frameResult;
      await worker.debugWaitPipelineIdle();
      await worker.debugWaitPassiveIdle();

      expect(result.face, isNotNull);
      expect(result.face!.yawDegrees, closeTo(7.0, 1e-6));
      expect(passive.commands, contains('collect_frame'));
      expect(passive.payloads.last!['camBufIdx'], 0);
      expect(buffer.passiveReleaseCount, 1);
    });

    test('passive queue drains multiple face results in order', () async {
      final buffers = <_FakeCameraBuffer>[_FakeCameraBuffer(), _FakeCameraBuffer()];
      final worker = buildWorker(buffers);
      final emitted = <WorkerFrameResult>[];
      final sub = worker.debugFrames.listen(emitted.add);
      addTearDown(sub.cancel);
      final firstPassiveResponse = Completer<Map<String, dynamic>>();
      var collectFrameCount = 0;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          final idx = payload!['camBufIdx'] as int;
          expect(buffers[idx].beginPipelineRead(), isTrue);
          buffers[idx].endPipelineRead(handoffToPassive: true);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': serializedFace(yaw: idx + 1.0)});
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };
      passive.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'collect_frame') {
          final idx = payload!['camBufIdx'] as int;
          collectFrameCount++;
          expect(buffers[idx].beginPassiveRead(), isTrue);
          if (collectFrameCount == 1) {
            return firstPassiveResponse.future;
          }
          buffers[idx].endPassiveRead();
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      await worker.debugWaitPipelineIdle();
      await processPackedFrame(worker, 2);
      await worker.debugWaitPipelineIdle();

      buffers[0].endPassiveRead();
      firstPassiveResponse.complete(<String, dynamic>{'ok': true});
      await worker.debugWaitPassiveIdle();

      final collectPayloads = <Map<String, dynamic>>[];
      for (var i = 0; i < passive.commands.length; i++) {
        if (passive.commands[i] == 'collect_frame') {
          collectPayloads.add(passive.payloads[i]!);
        }
      }

      expect(collectPayloads.map((p) => p['camBufIdx']), <int>[0, 1]);
      expect(emitted.map((r) => r.face?.yawDegrees), <double?>[1.0, 2.0]);
      expect(buffers.map((b) => b.passiveReleaseCount), <int>[1, 1]);
    });

    test('stale pipeline result with face after stop releases passive-ready buffer', () async {
      final buffer = _FakeCameraBuffer();
      final worker = buildWorker(<_FakeCameraBuffer>[buffer]);
      final pipelineResponse = Completer<Map<String, dynamic>>();

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          return pipelineResponse.future;
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      final stopFuture = worker.stop();

      expect(buffer.beginPipelineRead(), isTrue);
      buffer.endPipelineRead(handoffToPassive: true);
      pipelineResponse.complete(<String, dynamic>{'face': serializedFace()});

      await stopFuture;

      expect(buffer.passiveReleaseCount, 1);
      expect(buffer.state, _FakeCameraBuffer.free);
      expect(passive.commands, isNot(contains('collect_frame')));
    });

    test('queued stale pipeline frame is evicted when newer frame arrives', () async {
      final buffers = <_FakeCameraBuffer>[_FakeCameraBuffer(), _FakeCameraBuffer(), _FakeCameraBuffer()];
      final worker = buildWorker(buffers);

      final firstPipelineResponse = Completer<Map<String, dynamic>>();
      var processFrameCount = 0;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd != 'process_frame') return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});

        processFrameCount++;
        if (processFrameCount == 1) {
          return firstPipelineResponse.future;
        }

        return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': null});
      };

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[1]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[2]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );

      await worker.debugProcessPackedCameraFrame(
        planeBytes: <Uint8List>[
          Uint8List.fromList(<int>[3]),
        ],
        width: 1,
        height: 1,
        format: 'bgra8888',
        rotationDegrees: 0,
        bytesPerRow: <int>[4],
        bytesPerPixel: <int?>[4],
      );

      // Second frame was queued while first was still busy, then evicted by third frame.
      expect(buffers[1].pipelineReleaseWithoutPassive, 1);
      expect(buffers[1].state, _FakeCameraBuffer.free);

      firstPipelineResponse.complete(<String, dynamic>{'face': null});
      await worker.debugWaitPipelineIdle();

      expect(processFrameCount, 2);
    });

    test('stop releases queued pipeline and passive buffers before stop commands', () async {
      final buffers = List<_FakeCameraBuffer>.generate(4, (_) => _FakeCameraBuffer());
      final worker = buildWorker(buffers);
      final blockedPipeline = Completer<Map<String, dynamic>>();
      final blockedPassive = Completer<Map<String, dynamic>>();
      var processFrameCount = 0;
      var checkedBeforeStopCommand = false;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          final idx = payload!['camBufIdx'] as int;
          processFrameCount++;
          if (processFrameCount == 3) {
            return blockedPipeline.future;
          }
          expect(buffers[idx].beginPipelineRead(), isTrue);
          buffers[idx].endPipelineRead(handoffToPassive: true);
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'face': serializedFace(yaw: idx.toDouble())});
        }
        if (cmd == 'stop') {
          checkedBeforeStopCommand = true;
          expect(buffers[1].state, _FakeCameraBuffer.free);
          expect(buffers[3].state, _FakeCameraBuffer.free);
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };
      passive.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'collect_frame') {
          final idx = payload!['camBufIdx'] as int;
          expect(buffers[idx].beginPassiveRead(), isTrue);
          if (idx == 0) {
            return blockedPassive.future;
          }
          buffers[idx].endPassiveRead();
        }
        if (cmd == 'stop') {
          expect(buffers[1].state, _FakeCameraBuffer.free);
          expect(buffers[3].state, _FakeCameraBuffer.free);
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      await worker.debugWaitPipelineIdle();
      await processPackedFrame(worker, 2);
      await worker.debugWaitPipelineIdle();
      await processPackedFrame(worker, 3);
      await processPackedFrame(worker, 4);

      final stopFuture = worker.stop();

      expect(buffers[1].passiveReleaseCount, 1);
      expect(buffers[3].pipelineReleaseWithoutPassive, 1);

      buffers[2].beginPipelineRead();
      buffers[2].endPipelineRead(handoffToPassive: false);
      blockedPipeline.complete(<String, dynamic>{'face': null});
      buffers[0].endPassiveRead();
      blockedPassive.complete(<String, dynamic>{'ok': true});

      await stopFuture;

      expect(checkedBeforeStopCommand, isTrue);
      expect(pipeline.commands.last, 'stop');
      expect(passive.commands.last, 'stop');
    });

    test('dispose releases queued pipeline and passive buffers before disposing buffers', () async {
      final buffers = List<_FakeCameraBuffer>.generate(4, (_) => _FakeCameraBuffer());
      final worker = buildWorker(buffers);
      final blockedPipeline = Completer<Map<String, dynamic>>();
      final blockedPassive = Completer<Map<String, dynamic>>();
      var processFrameCount = 0;

      pipeline.onRequest = (String cmd, Map<String, dynamic>? payload) {
        if (cmd == 'process_frame') {
          final idx = payload!['camBufIdx'] as int;
          processFrameCount++;
          if (processFrameCount == 3) {
            return blockedPipeline.future;
          }
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
          if (idx == 0) {
            return blockedPassive.future;
          }
          buffers[idx].endPassiveRead();
        }
        return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': true});
      };

      await processPackedFrame(worker, 1);
      await worker.debugWaitPipelineIdle();
      await processPackedFrame(worker, 2);
      await worker.debugWaitPipelineIdle();
      await processPackedFrame(worker, 3);
      await processPackedFrame(worker, 4);

      final disposeFuture = worker.dispose();

      expect(buffers[1].passiveReleaseCount, 1);
      expect(buffers[3].pipelineReleaseWithoutPassive, 1);

      buffers[2].beginPipelineRead();
      buffers[2].endPipelineRead(handoffToPassive: false);
      blockedPipeline.complete(<String, dynamic>{'face': null});
      buffers[0].endPassiveRead();
      blockedPassive.complete(<String, dynamic>{'ok': true});

      await disposeFuture;

      expect(buffers.every((b) => b.disposed), isTrue);
      expect(pipeline.disposed, isTrue);
      expect(passive.disposed, isTrue);
      expect(match.disposed, isTrue);
    });

    test('dispose releases camera buffers', () async {
      final buffers = <_FakeCameraBuffer>[_FakeCameraBuffer(), _FakeCameraBuffer()];
      final worker = buildWorker(buffers);

      await worker.dispose();

      expect(buffers.every((b) => b.disposed), isTrue);
      expect(pipeline.disposed, isTrue);
      expect(passive.disposed, isTrue);
      expect(match.disposed, isTrue);
    });
  });

  group('FaceVerificationWorker — instance (no isolates)', () {
    test('frames is a broadcast stream', () {
      final worker = FaceVerificationWorker();
      expect(worker.debugFrames.isBroadcast, isTrue);
    });

    test('debugSessionId starts at 0', () {
      final worker = FaceVerificationWorker();
      expect(worker.debugSessionId, 0);
    });

    test('debugWaitPipelineIdle completes immediately when not busy', () async {
      final worker = FaceVerificationWorker();
      await expectLater(worker.debugWaitPipelineIdle(), completes);
    });

    test('debugWaitPassiveIdle completes immediately when not busy', () async {
      final worker = FaceVerificationWorker();
      await expectLater(worker.debugWaitPassiveIdle(), completes);
    });

    test('debugEmitFrameResult emits null-face result on frames stream', () async {
      final worker = FaceVerificationWorker();
      final future = worker.debugFrames.first;
      worker.debugEmitFrameResult(const WorkerFrameResult(face: null));
      final result = await future;
      expect(result.face, isNull);
    });

    test('debugEmitFrameResult emits non-null face result on frames stream', () async {
      final worker = FaceVerificationWorker();
      final face = _makeFace();
      final future = worker.debugFrames.first;
      worker.debugEmitFrameResult(WorkerFrameResult(face: face));
      final result = await future;
      expect(result.face, isNotNull);
      expect(result.face!.yawDegrees, 5.0);
    });

    test('debugEmitFrameError propagates error on frames stream', () async {
      final worker = FaceVerificationWorker();
      final future = worker.debugFrames.first.catchError((_) => const WorkerFrameResult(face: null));
      worker.debugEmitFrameError(Exception('test error'));
      await future; // just verify it doesnetes without hanging
    });
  });

  group('FaceVerificationWorker — BGRA to RGB conversion', () {
    test('2×1 BGRA pixel converts correctly (channels swapped)', () {
      // One pixel: B=10, G=20, R=30, A=255
      final bgra = Uint8List.fromList([10, 20, 30, 255]);
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 1, 1, 4);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 30); // R from position 2
      expect(bytes[1], 20); // G from position 1
      expect(bytes[2], 10); // B from position 0
    });

    test('output image has correct dimensions', () {
      final bgra = Uint8List(4 * 4 * 4); // 4×4 BGRA
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 4, 4, 16);
      expect(rgb.width, 4);
      expect(rgb.height, 4);
    });

    test('handles row stride padding correctly', () {
      // 2×2 image with 12-byte row stride (2 pixels×4 bytes + 4 bytes padding)
      final bgra = Uint8List(2 * 12);
      bgra[0] = 1;
      bgra[1] = 2;
      bgra[2] = 3; // pixel 0,0: B=1, G=2, R=3
      final rgb = FaceVerificationWorker.debugBgraToRgbImage(bgra, 2, 2, 12);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 3); // R
      expect(bytes[1], 2); // G
      expect(bytes[2], 1); // B
    });
  });

  group('FaceVerificationWorker — YUV420 to RGB conversion', () {
    test('output image has correct dimensions', () {
      final width = 4, height = 4;
      final yBytes = Uint8List(width * height);
      final uBytes = Uint8List(width * height ~/ 4);
      final vBytes = Uint8List(width * height ~/ 4);
      final planes = [
        {'bytes': yBytes, 'bytesPerRow': width, 'bytesPerPixel': 1},
        {'bytes': uBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
        {'bytes': vBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
      ];
      final rgb = FaceVerificationWorker.debugYuv420ToRgbImage(width, height, planes);
      expect(rgb.width, width);
      expect(rgb.height, height);
    });

    test('pure grey YUV (Y=128, U=128, V=128) produces grey pixel', () {
      const width = 2, height = 2;
      final yBytes = Uint8List(width * height)..fillRange(0, width * height, 128);
      final uBytes = Uint8List(width * height ~/ 4)..fillRange(0, width * height ~/ 4, 128);
      final vBytes = Uint8List(width * height ~/ 4)..fillRange(0, width * height ~/ 4, 128);
      final planes = [
        {'bytes': yBytes, 'bytesPerRow': width, 'bytesPerPixel': 1},
        {'bytes': uBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
        {'bytes': vBytes, 'bytesPerRow': width ~/ 2, 'bytesPerPixel': 1},
      ];
      final rgb = FaceVerificationWorker.debugYuv420ToRgbImage(width, height, planes);
      final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
      // Y=128, U=128, V=128 → near-grey (small rounding differences allowed)
      expect(bytes[0], closeTo(128, 5)); // R
      expect(bytes[1], closeTo(128, 5)); // G
      expect(bytes[2], closeTo(128, 5)); // B
    });

    test('YUV420 supports UV pixel stride of 2', () {
      const width = 2;
      const height = 2;

      final yBytes = Uint8List(width * height)..fillRange(0, width * height, 128);

      // Stride 2 means useful chroma value is at index 0 for this tiny image.
      final uBytes = Uint8List.fromList(<int>[128, 0]);
      final vBytes = Uint8List.fromList(<int>[128, 0]);

      final planes = <Map<String, dynamic>>[
        <String, dynamic>{'bytes': yBytes, 'bytesPerRow': width, 'bytesPerPixel': 1},
        <String, dynamic>{'bytes': uBytes, 'bytesPerRow': 2, 'bytesPerPixel': 2},
        <String, dynamic>{'bytes': vBytes, 'bytesPerRow': 2, 'bytesPerPixel': 2},
      ];

      final rgb = FaceVerificationWorker.debugYuv420ToRgbImage(width, height, planes);

      expect(rgb.width, width);
      expect(rgb.height, height);
    });
  });

  group('FaceVerificationWorker — image rotation', () {
    img.Image colorImage(int w, int h) {
      final image = img.Image(width: w, height: h, numChannels: 3);
      image.setPixelRgb(0, 0, 255, 0, 0); // top-left = red
      return image;
    }

    test('rotation 0 returns same dimensions', () {
      final src = colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 0);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('rotation 90 swaps width and height', () {
      final src = colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 90);
      expect(out.width, 6);
      expect(out.height, 4);
    });

    test('rotation 180 preserves dimensions', () {
      final src = colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 180);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('rotation 270 swaps width and height', () {
      final src = colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 270);
      expect(out.width, 6);
      expect(out.height, 4);
    });

    test('rotation 360 behaves like rotation 0', () {
      final src = colorImage(4, 6);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 360);
      expect(out.width, 4);
      expect(out.height, 6);
    });

    test('non-axis-aligned rotation (45°) produces output image', () {
      final src = colorImage(4, 4);
      final out = FaceVerificationWorker.debugRotateToUpright(src, 45);
      expect(out.width, greaterThan(0));
      expect(out.height, greaterThan(0));
    });

    test('non-axis-aligned rotation converts four-channel output back to RGB', () {
      final src = img.Image(width: 4, height: 4, numChannels: 4);

      final out = FaceVerificationWorker.debugRotateToUpright(src, 45);

      expect(out.width, greaterThan(0));
      expect(out.height, greaterThan(0));
      expect(out.numChannels, 3);
      expect(out.getBytes(order: img.ChannelOrder.rgb).length, out.width * out.height * 3);
    });

    test('negative rotation normalizes correctly', () {
      final src = img.Image(width: 4, height: 6, numChannels: 3);

      final out = FaceVerificationWorker.debugRotateToUpright(src, -90);

      expect(out.width, 6);
      expect(out.height, 4);
    });

    test('rotation greater than 360 normalizes correctly', () {
      final src = img.Image(width: 4, height: 6, numChannels: 3);

      final out = FaceVerificationWorker.debugRotateToUpright(src, 450);

      expect(out.width, 6);
      expect(out.height, 4);
    });
  });

  group('FaceVerificationWorker — image payload serialization', () {
    test('imagePayload round-trips through imageFromPayload', () {
      final original = img.Image(width: 10, height: 8);
      original.setPixelRgb(0, 0, 100, 150, 200);
      final payload = FaceVerificationWorker.debugImagePayload(original);
      final recovered = FaceVerificationWorker.debugImageFromPayload(payload);
      expect(recovered.width, 10);
      expect(recovered.height, 8);
    });

    test('imagePayload contains width, height and rgb bytes', () {
      final image = img.Image(width: 5, height: 3);
      final payload = FaceVerificationWorker.debugImagePayload(image);
      expect(payload['width'], 5);
      expect(payload['height'], 3);
      expect(payload['rgb'], isA<Uint8List>());
      expect((payload['rgb'] as Uint8List).length, 5 * 3 * 3);
    });

    test('imageFromPayload preserves pixel values', () {
      final image = img.Image(width: 2, height: 2);
      image.setPixelRgb(0, 0, 255, 0, 0); // red pixel
      final payload = FaceVerificationWorker.debugImagePayload(image);
      final recovered = FaceVerificationWorker.debugImageFromPayload(payload);
      final bytes = recovered.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes[0], 255); // R
      expect(bytes[1], 0); // G
      expect(bytes[2], 0); // B
    });
  });

  group('FaceVerificationWorker — face serialization round-trip', () {
    test('serializeFace / deserializeFaceMap preserves yaw', () {
      final face = _makeFace(yaw: 12.5);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.yawDegrees, closeTo(12.5, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves null yaw', () {
      final face = _makeFace(yaw: 0).copyWith(yawDegrees: null);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.yawDegrees, isNull);
    });

    test('serializeFace / deserializeFaceMap preserves mouthRatio', () {
      final face = _makeFace(mouthRatio: 0.08);
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.mouthRatio, closeTo(0.08, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves blendshape scores', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.blendshapeScores['jawOpen'], closeTo(0.1, 1e-6));
      expect(recovered.blendshapeScores['mouthSmileLeft'], closeTo(0.2, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves landmark count', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.result.landmarks.first.length, 478);
    });

    test('serializeFace / deserializeFaceMap preserves bounding box', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.boundingBox.left, closeTo(10, 1e-6));
      expect(recovered.boundingBox.top, closeTo(20, 1e-6));
    });

    test('serializeFace / deserializeFaceMap preserves alignedFace112 dimensions', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);
      expect(recovered.alignedFace112.width, 112);
      expect(recovered.alignedFace112.height, 112);
    });

    test('serializeFace / deserializeFaceMap preserves boundingBoxCenter', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);

      expect(recovered.boundingBoxCenter.dx, closeTo(0.5, 1e-6));
      expect(recovered.boundingBoxCenter.dy, closeTo(0.5, 1e-6));
    });

    test('deserializeFaceMap defaults boundingBoxCenter when missing', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face)..remove('bboxCenter');

      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);

      expect(recovered.boundingBoxCenter.dx, closeTo(0.5, 1e-6));
      expect(recovered.boundingBoxCenter.dy, closeTo(0.5, 1e-6));
    });

    test('deserializeFaceMap defaults boundingBoxAreaRatio when missing', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face)..remove('bboxAreaRatio');

      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);

      expect(recovered.boundingBoxAreaRatio, closeTo(0.0, 1e-6));
    });

    test('deserializeFaceMap throws when aligned image is missing', () {
      final face = _makeFace();
      final map = FaceVerificationWorker.debugSerializeFace(face)..remove('alignedRgb');

      expect(() => FaceVerificationWorker.debugDeserializeFaceMap(map), throwsStateError);
    });

    test('serializeFace / deserializeFaceMap preserves transform matrix', () {
      final landmarks = List<NormalizedLandmark>.generate(478, (i) => NormalizedLandmark(i * 0.001, i * 0.001, 0));

      final matrix = List<double>.generate(16, (i) => i.toDouble());

      final result = FaceLandmarkerResult(
        landmarks: <List<NormalizedLandmark>>[landmarks],
        blendshapes: const <List<Category>>[],
        transformMatrices: <List<double>>[matrix],
      );

      final face = FaceObservation(
        result: result,
        boundingBox: const Rect.fromLTWH(10, 20, 100, 120),
        boundingBoxAreaRatio: 0.15,
        boundingBoxCenter: const Offset(0.5, 0.5),
        mouthRatio: 0.03,
        yawDegrees: 5.0,
        blendshapeScores: const <String, double>{},
        alignedFace112: img.Image(width: 112, height: 112),
      );

      final map = FaceVerificationWorker.debugSerializeFace(face);
      final recovered = FaceVerificationWorker.debugDeserializeFaceMap(map);

      expect(recovered.result.transformMatrices, isNotNull);
      expect(recovered.result.transformMatrices!.first, matrix);
    });
  });

  group('FaceVerificationWorker — debug worker isolate loops', () {
    test('match worker handles non-model commands without initialization', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugMatchWorkerEntry);
      addTearDown(harness.dispose);

      expect(await harness.request('start_session'), containsPair('ok', true));

      final consistency = await harness.request(
        'check_consistency_selfie',
        payload: FaceVerificationWorker.debugImagePayload(img.Image(width: 112, height: 112)),
      );
      expect(consistency['score'], closeTo(1.0, 1e-9));

      final match = await harness.request(
        'match_selfie',
        payload: FaceVerificationWorker.debugImagePayload(img.Image(width: 112, height: 112)),
      );
      expect(match['score'], closeTo(0.0, 1e-9));

      expect(await harness.request('stop'), containsPair('ok', true));
      expect(await harness.request('dispose'), containsPair('ok', true));
    });

    test('match worker returns error for unknown command', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugMatchWorkerEntry);
      addTearDown(harness.dispose);

      await expectLater(harness.request('unknown_command'), throwsA(isA<StateError>()));
    });

    test('pipeline worker rejects empty encoded crop input without model initialization', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPipelineWorkerEntry);
      addTearDown(harness.dispose);

      final result = await harness.request('detect_crop_encoded', payload: <String, dynamic>{'bytes': Uint8List(0)});

      expect(result['ok'], isFalse);
    });

    test('pipeline worker returns error for malformed encoded crop input', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPipelineWorkerEntry);
      addTearDown(harness.dispose);

      await expectLater(
        harness.request(
          'detect_crop_encoded',
          payload: <String, dynamic>{
            'bytes': Uint8List.fromList(<int>[1, 2, 3]),
          },
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('pipeline worker returns error for unknown command', () async {
      final harness = await _DebugWorkerHarness.spawn(FaceVerificationWorker.debugPipelineWorkerEntry);
      addTearDown(harness.dispose);

      await expectLater(harness.request('unknown_command'), throwsA(isA<StateError>()));
    });
  });
}

extension on FaceObservation {
  FaceObservation copyWith({double? yawDegrees}) => FaceObservation(
    result: result,
    boundingBox: boundingBox,
    boundingBoxAreaRatio: boundingBoxAreaRatio,
    boundingBoxCenter: boundingBoxCenter,
    mouthRatio: mouthRatio,
    yawDegrees: yawDegrees,
    blendshapeScores: blendshapeScores,
    alignedFace112: alignedFace112,
  );
}
