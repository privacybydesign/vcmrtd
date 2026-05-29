import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_diagnostics.dart';
import 'package:vcmrtdapp/features/face_verification/ffi/face_frame_buffer.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/liveness_service.dart';
import 'package:vcmrtdapp/features/face_verification/recognition/face_recognizer.dart';

class WorkerFrameResult {
  const WorkerFrameResult({required this.face});

  final FaceObservation? face;
}

class WorkerPassiveResult {
  const WorkerPassiveResult({
    required this.antiSpoofScore,
    required this.antiSpoofPassed,
    required this.rppgHr,
    required this.rppgPassed,
    required this.rppgSampleCount,
    required this.rppgDurationMs,
  });

  final double? antiSpoofScore;
  final bool antiSpoofPassed;
  final double? rppgHr;
  final bool rppgPassed;
  final int rppgSampleCount;
  final int rppgDurationMs;
}

class WorkerMatchResult {
  const WorkerMatchResult({required this.score, this.nfcInputPng, this.selfieInputPng});

  final double score;
  final Uint8List? nfcInputPng;
  final Uint8List? selfieInputPng;
}

class _IsolateClient {
  _IsolateClient(this.entryPoint);

  final void Function(List<Object?>) entryPoint;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  int _requestId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};

  Future<void> start() async {
    if (_isolate != null) return;
    final rootToken = RootIsolateToken.instance;
    if (rootToken == null) {
      throw StateError('Flutter binding must be initialized before starting face verification isolates');
    }
    _receivePort = ReceivePort();
    final ready = Completer<void>();
    _receivePort!.listen((dynamic message) {
      if (message is SendPort && _sendPort == null) {
        _sendPort = message;
        if (!ready.isCompleted) ready.complete();
        return;
      }
      _handleMessage(message);
    });
    _isolate = await Isolate.spawn(entryPoint, <Object?>[_receivePort!.sendPort, rootToken]);
    await ready.future;
  }

  Future<Map<String, dynamic>> request(String cmd, {Map<String, dynamic>? payload}) {
    final send = _sendPort;
    if (send == null) throw StateError('Worker isolate not initialized');
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    send.send(<String, dynamic>{'id': id, 'cmd': cmd, 'payload': payload ?? <String, dynamic>{}});
    return completer.future;
  }

  Future<void> dispose() async {
    if (_isolate == null) return;
    try {
      await request('dispose');
    } catch (_) {}
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(StateError('Worker isolate disposed'));
    }
    _pending.clear();
  }

  void _handleMessage(dynamic message) {
    if (message is! Map) return;
    final id = message['id'] as int?;
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['error'] != null) {
      completer.completeError(StateError(message['error'].toString()));
      return;
    }
    completer.complete((message['result'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
  }
}

class FaceVerificationWorker {
  // Single pipeline isolate handles decode + detect + landmarks (matches FaceLandmarkPipeline)
  final _pipeline = _IsolateClient(_pipelineWorkerMain);
  final _passive = _IsolateClient(_passiveWorkerMain);
  final _match = _IsolateClient(_matchWorkerMain);

  // Pool of native camera frame buffers — main writes raw camera bytes once,
  // pipeline and passive each decode independently from the same native memory.
  // At most PIL_READING(1) + PASS_READY(queued,1) + PASS_READING(1) = 3 occupied at once.
  static const int _camPoolSize = 10;
  static const int _camBufCap = 12 * 1024 * 1024; // 12 MB — covers 1080p BGRA with headroom
  late final List<FaceFrameBuffer> _camPool;

  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast();

  final Queue<Map<String, dynamic>> _pipelineQueue = Queue<Map<String, dynamic>>();
  final Queue<Map<String, dynamic>> _passiveQueue = Queue<Map<String, dynamic>>();
  bool _camPoolDisposed = false;
  bool _pipelineBusy = false;
  bool _passiveBusy = false;
  Completer<void>? _pipelineIdle;
  Completer<void>? _passiveIdle;
  int _sessionId = 0;
  int _diagPipelineFrameSeq = 0;
  int _diagPipelineResultCount = 0;
  Stream<WorkerFrameResult> get frames => _frames.stream;

  Future<void> initialize() async {
    _camPool = List.generate(_camPoolSize, (_) => FaceFrameBuffer.create(_camBufCap));
    final camBufAddrs = _camPool.map((b) => b.address).toList(growable: false);

    // Start isolates while loading bytes — both are non-blocking.
    await Future.wait<void>([_pipeline.start(), _passive.start(), _match.start()]);

    // Load all model bytes asynchronously via platform channel — pure I/O, does not block UI.
    const assets = <String>[
      'assets/face_verification/face_detector.tflite',
      'assets/face_verification/face_landmarks_detector.tflite',
      'assets/face_verification/face_blendshapes.tflite',
      'assets/face_verification/minifasnet_v1se.tflite',
      'assets/face_verification/minifasnet_v2.tflite',
      'assets/face_verification/bigsmall_1.tflite',
      'assets/face_verification/bigsmall_2.tflite',
      'assets/face_verification/bigsmall_3.tflite',
      'assets/face_verification/GhostFaceNet_fp32_V2.tflite',
    ];
    final bytes = await Future.wait(assets.map(_loadModelBytes));
    debugPrint('[FaceVerification] Worker: all ${bytes.length} model assets loaded');

    // Wrap each buffer in TransferableTypedData for zero-copy transfer to worker isolates.
    // Workers call initializeFromBuffers() / initializeFromBuffer() — pure FFI, no ServicesBinding.
    final ttds = bytes.map((b) => TransferableTypedData.fromList(<Uint8List>[b])).toList(growable: false);

    await Future.wait(<Future<Map<String, dynamic>>>[
      _pipeline.request(
        'init',
        payload: <String, dynamic>{
          'detector': ttds[0],
          'landmarks': ttds[1],
          'blendshapes': ttds[2],
          'camBufAddrs': camBufAddrs,
          'camBufCap': _camBufCap,
        },
      ),
      _passive.request(
        'init',
        payload: <String, dynamic>{
          'v1': ttds[3],
          'v2': ttds[4],
          'bigSmall1': ttds[5],
          'bigSmall2': ttds[6],
          'bigSmall3': ttds[7],
          'camBufAddrs': camBufAddrs,
          'camBufCap': _camBufCap,
        },
      ),
      _match.request('init', payload: <String, dynamic>{'ghost': ttds[8]}),
    ]);
    debugPrint('[FaceVerification] Worker: all workers initialized');
  }

  Future<void> startSession() async {
    _sessionId++;
    _diagPipelineFrameSeq = 0;
    _diagPipelineResultCount = 0;
    await Future.wait(<Future<Map<String, dynamic>>>[
      _pipeline.request('start_session'),
      _passive.request('start_session'),
      _match.request('start_session'),
    ]);
    _pipelineQueue.clear();
    _passiveQueue.clear();
    _pipelineBusy = false;
    _passiveBusy = false;
    _completePipelineIdle();
    _completePassiveIdle();
  }

  Future<img.Image?> detectAndCropEncoded(Uint8List encoded) async {
    final res = await _pipeline.request('detect_crop_encoded', payload: <String, dynamic>{'bytes': encoded});
    if (res['ok'] != true) return null;
    final png = res['png'] as Uint8List?;
    if (png == null || png.isEmpty) return null;
    return img.decodeImage(png);
  }

  Future<void> prepareNfcFace(img.Image face) async {
    await _match.request('prepare_nfc_face', payload: _imagePayload(face));
  }

  Future<WorkerMatchResult> matchSelfie(img.Image selfie) async {
    final res = await _match.request('match_selfie', payload: _imagePayload(selfie));
    final rawScore = res['score'];
    debugPrint(
      '[FaceVerification] Match worker response: keys=${res.keys.toList()} '
      'rawScore=$rawScore rawScoreType=${rawScore.runtimeType}',
    );
    return WorkerMatchResult(
      score: (res['score'] as num?)?.toDouble() ?? 0.0,
      nfcInputPng: res['nfcInputPng'] as Uint8List?,
      selfieInputPng: res['selfieInputPng'] as Uint8List?,
    );
  }

  Future<void> processCameraFrame(CameraImage cameraImage, int rotationDegrees) async {
    if (_camPoolDisposed) return;
    // Find the first FREE native buffer — never block, just drop the frame if all are busy.
    int? freeBufIdx;
    for (var i = 0; i < _camPool.length; i++) {
      if (_camPool[i].beginWrite()) {
        freeBufIdx = i;
        break;
      }
    }
    if (freeBufIdx == null) {
      return; // all buffers in use — drop frame
    }

    // Copy camera planes into native memory (one write, shared by both isolates).
    final buf = _camPool[freeBufIdx];
    final dst = buf.dataPtr;
    var planeOffset = 0;
    for (final Plane plane in cameraImage.planes) {
      (dst + planeOffset).asTypedList(plane.bytes.length).setAll(0, plane.bytes);
      planeOffset += plane.bytes.length;
    }
    buf.commitWrite(cameraImage.width, cameraImage.height, cameraImage.planes.length);

    final diagFrameSeq = ++_diagPipelineFrameSeq;
    _enqueuePipelineFrame(<String, dynamic>{
      'sessionId': _sessionId,
      'diagFrameSeq': diagFrameSeq,
      'camera': _cameraNativeMetadata(cameraImage, rotationDegrees),
      'camBufIdx': freeBufIdx,
    });
  }

  // Latest-frame-wins: when the pipeline is busy, evict any already-queued frame
  // (freeing its native buffer atomically) and replace it with the new one.
  // This bounds lag to at most one pipeline frame time instead of letting stale
  // frames pile up until the native buffer pool is exhausted (~8 frames / ~267ms).
  void _enqueuePipelineFrame(Map<String, dynamic> payload) {
    if (_pipelineBusy) {
      _evictPipelineQueue();
      _pipelineQueue.add(payload);
      _pipelineIdle ??= Completer<void>();
      return;
    }
    _pipelineBusy = true;
    _pipelineIdle ??= Completer<void>();
    unawaited(_runPipelinePayload(payload));
  }

  // Reclaims native buffers for all frames waiting in the pipeline queue.
  // READY → PIL_READING → FREE via the same atomic ops the pipeline uses,
  // safe to call from the main isolate because the pipeline hasn't received
  // a process_frame command for these buffers yet.
  void _evictPipelineQueue() {
    while (_pipelineQueue.isNotEmpty) {
      final stale = _pipelineQueue.removeFirst();
      final buf = _camPool[stale['camBufIdx'] as int];
      if (buf.beginPipelineRead()) buf.endPipelineRead(handoffToPassive: false);
    }
  } 

  Future<void> _runPipelinePayload(Map<String, dynamic> payload) async {
    final sessionId = payload['sessionId'] as int;
    final diagFrameSeq = payload['diagFrameSeq'] as int?;
    final diagStartMs = FaceVerificationDiagnostics.enabled ? DateTime.now().millisecondsSinceEpoch : 0;
    final cameraPayload = (payload['camera'] as Map).cast<String, dynamic>();
    final camBufIdx = payload['camBufIdx'] as int;
    try {
      final pipelineResult = await _pipeline.request(
        'process_frame',
        payload: <String, dynamic>{...cameraPayload, 'camBufIdx': camBufIdx},
      );
      if (sessionId == _sessionId) {
        final faceMap = pipelineResult['face'] as Map<String, dynamic>?;
        if (FaceVerificationDiagnostics.enabled && _diagPipelineResultCount < 8) {
          final durationMs = DateTime.now().millisecondsSinceEpoch - diagStartMs;
          FaceVerificationDiagnostics.log(
            'pipeline result #${_diagPipelineResultCount + 1} seq=$diagFrameSeq '
            'duration=${durationMs}ms hasFace=${faceMap != null}',
          );
        }
        _diagPipelineResultCount++;
        if (faceMap != null) {
          // Pipeline transitioned the buffer to PASS_READY — passive reads the same raw frame.
          // Send buffer index + camera metadata (no pixel bytes) so passive can decode.
          _enqueuePassiveFrame(<String, dynamic>{
            'face': faceMap,
            'camBufIdx': camBufIdx,
            ...cameraPayload, // width, height, format, rotation, planes metadata (no bytes)
          });
        }
        _emitFrameResult(WorkerFrameResult(face: faceMap == null ? null : _deserializeFaceMap(faceMap)));
      }
    } catch (e) {
      if (sessionId == _sessionId) _emitFrameError(e);
    }

    if (_pipelineQueue.isNotEmpty) {
      unawaited(_runPipelinePayload(_pipelineQueue.removeFirst()));
    } else {
      _pipelineBusy = false;
      _completePipelineIdle();
    }
  }

  void _emitFrameResult(WorkerFrameResult result) {
    if (!_frames.isClosed) _frames.add(result);
  }

  void _emitFrameError(Object error) {
    if (!_frames.isClosed) _frames.addError(error);
  }

  Future<WorkerPassiveResult> getPassiveResult() async {
    await _waitPipelineIdle();
    await _waitPassiveIdle();
    final res = await _passive.request('passive_result');
    final rppg = res['rppg'] as Map<String, dynamic>?;
    return WorkerPassiveResult(
      antiSpoofScore: (res['antiSpoofScore'] as num?)?.toDouble(),
      antiSpoofPassed: (res['antiSpoofPassed'] as bool?) ?? false,
      rppgHr: (rppg?['hr'] as num?)?.toDouble(),
      rppgPassed: (rppg?['passed'] as bool?) ?? false,
      rppgSampleCount: (rppg?['sampleCount'] as num?)?.toInt() ?? 0,
      rppgDurationMs: (rppg?['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> stop() async {
    _sessionId++;
    _pipelineQueue.clear();
    _passiveQueue.clear();
    await _waitPipelineIdle();
    await _waitPassiveIdle();
    await _pipeline.request('stop');
    await _passive.request('stop');
    await _match.request('stop');
  }

  void _disposeCamPool() {
    if (_camPoolDisposed) return;
    _camPoolDisposed = true;
    for (final buf in _camPool) {
      buf.dispose();
    }
  }

  Future<void> dispose() async {
    await _pipeline.dispose();
    await _passive.dispose();
    await _match.dispose();
    await _frames.close();
    _pipelineQueue.clear();
    _passiveQueue.clear();
    _pipelineBusy = false;
    _passiveBusy = false;
    _completePipelineIdle();
    _completePassiveIdle();
    _disposeCamPool();
  }

  void _enqueuePassiveFrame(Map<String, dynamic> payload) {
    _passiveQueue.add(payload);
    if (_passiveBusy) {
      _passiveIdle ??= Completer<void>();
      return;
    }
    _passiveBusy = true;
    _passiveIdle ??= Completer<void>();
    unawaited(_runPassivePayload(_passiveQueue.removeFirst()));
  }

  Future<void> _runPassivePayload(Map<String, dynamic> payload) async {
    try {
      await _passive.request('collect_frame', payload: payload);
    } catch (_) {}

    if (_passiveQueue.isNotEmpty) {
      unawaited(_runPassivePayload(_passiveQueue.removeFirst()));
      return;
    }
    _passiveBusy = false;
    _completePassiveIdle();
  }

  // Must drain the passive queue before reading results: the last buffered frames may still
  // be in-flight in the isolate when getPassiveResult() is called after the session ends.
  Future<void> _waitPassiveIdle() {
    if (!_passiveBusy && _passiveQueue.isEmpty) return Future<void>.value();
    return (_passiveIdle ??= Completer<void>()).future;
  }

  Future<void> _waitPipelineIdle() {
    if (!_pipelineBusy && _pipelineQueue.isEmpty) return Future<void>.value();
    return (_pipelineIdle ??= Completer<void>()).future;
  }

  void _completePipelineIdle() {
    final idle = _pipelineIdle;
    if (idle != null && !idle.isCompleted) idle.complete();
    _pipelineIdle = null;
  }

  void _completePassiveIdle() {
    final idle = _passiveIdle;
    if (idle != null && !idle.isCompleted) idle.complete();
    _passiveIdle = null;
  }
}

SendPort _initializeWorkerIsolate(List<Object?> args) {
  final mainSendPort = args[0] as SendPort;
  final rootToken = args[1] as RootIsolateToken;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
  DartPluginRegistrant.ensureInitialized();
  return mainSendPort;
}

void _pipelineWorkerMain(List<Object?> args) {
  final mainSendPort = _initializeWorkerIsolate(args);
  unawaited(_pipelineWorkerLoop(mainSendPort));
}

// Single isolate that handles decode + detect + landmarks, matching FaceLandmarkPipeline.
// Tracking crop is updated internally — no round-trip to main needed.
Future<void> _pipelineWorkerLoop(SendPort mainSendPort) async {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  final detector = FaceDetectorService();
  List<FaceFrameBuffer>? camPool;

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        debugPrint('[FaceVerification] Pipeline worker: initializing from model buffers');
        detector.initializeFromBuffers(
          detector: (payload['detector'] as TransferableTypedData).materialize().asUint8List(),
          landmarks: (payload['landmarks'] as TransferableTypedData).materialize().asUint8List(),
          blendshapes: (payload['blendshapes'] as TransferableTypedData).materialize().asUint8List(),
        );
        camPool = (payload['camBufAddrs'] as List)
            .cast<int>()
            .map((a) => FaceFrameBuffer.fromAddress(a, payload['camBufCap'] as int))
            .toList(growable: false);
        debugPrint('[FaceVerification] Pipeline worker: initialized');
        return <String, dynamic>{'ok': true};
      case 'start_session':
        detector.resetTracking();
        return <String, dynamic>{'ok': true};
      case 'detect_crop_encoded':
        final bytes = payload['bytes'] as Uint8List?;
        if (bytes == null || bytes.isEmpty) return <String, dynamic>{'ok': false};
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return <String, dynamic>{'ok': false};
        final cropped = detector.detectAndCrop(decoded);
        if (cropped == null) return <String, dynamic>{'ok': false};
        return <String, dynamic>{'ok': true, 'png': Uint8List.fromList(img.encodePng(cropped))};
      case 'process_frame':
        return _handleProcessFrame(detector, payload, camPool!);
      case 'stop':
        return <String, dynamic>{'ok': true};
      case 'dispose':
        await detector.close();
        return <String, dynamic>{'ok': true};
      default:
        throw StateError('Unknown pipeline worker cmd: $cmd');
    }
  }

  await _serve(commandPort, mainSendPort, handle);
}

Map<String, dynamic> _handleProcessFrame(
  FaceDetectorService detector,
  Map<String, dynamic> payload,
  List<FaceFrameBuffer> camPool,
) {
  final camBufIdx = payload['camBufIdx'] as int;
  final buf = camPool[camBufIdx];

  // Claim the buffer for pipeline reading (READY → PIL_READING).
  if (!buf.beginPipelineRead()) {
    // Buffer is not READY — very unlikely (main just wrote it), treat as lost frame.
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }

  // Decode raw camera bytes from native memory into a Dart-heap img.Image.
  // The decode functions (_bgraToRgbImage / _yuv420ToRgbImage) build a new
  // Dart-heap buffer, so it is safe to release the native buffer afterwards.
  final frame = _decodeCameraFromBuffer(buf, payload);

  if (frame == null) {
    buf.endPipelineRead(handoffToPassive: false); // PIL_READING → FREE
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }

  final crop = detector.runDetectorStage(frame);
  if (crop == null) {
    buf.endPipelineRead(handoffToPassive: false);
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }

  final face = detector.runLandmarkStage(frame, crop, runBlendshapes: true);
  if (face == null) {
    buf.endPipelineRead(handoffToPassive: false);
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }

  detector.setTrackingCrop(detector.computeTrackingCrop(face.result, frame.width, frame.height));

  // Hand off to passive: PIL_READING → PASS_READY.
  // Native buffer remains valid until passive calls endPassiveRead().
  buf.endPipelineRead(handoffToPassive: true);

  return <String, dynamic>{
    'face': _serializeFace(face),
    // camBufIdx not needed in response — main already has it from the request payload.
  };
}

void _passiveWorkerMain(List<Object?> args) {
  final mainSendPort = _initializeWorkerIsolate(args);
  unawaited(_passiveWorkerLoop(mainSendPort));
}

Future<void> _passiveWorkerLoop(SendPort mainSendPort) async {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  final passive = PassiveLivenessService();
  List<FaceFrameBuffer>? camPool;

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        debugPrint('[FaceVerification] Passive worker: initializing from model buffers');
        passive.initializeFromBuffers(
          v1: (payload['v1'] as TransferableTypedData).materialize().asUint8List(),
          v2: (payload['v2'] as TransferableTypedData).materialize().asUint8List(),
          bigSmall: <Uint8List>[
            (payload['bigSmall1'] as TransferableTypedData).materialize().asUint8List(),
            (payload['bigSmall2'] as TransferableTypedData).materialize().asUint8List(),
            (payload['bigSmall3'] as TransferableTypedData).materialize().asUint8List(),
          ],
        );
        camPool = (payload['camBufAddrs'] as List)
            .cast<int>()
            .map((a) => FaceFrameBuffer.fromAddress(a, payload['camBufCap'] as int))
            .toList(growable: false);
        debugPrint('[FaceVerification] Passive worker: initialized');
        return <String, dynamic>{'ok': true};
      case 'start_session':
        passive.reset();
        return <String, dynamic>{'ok': true};
      case 'collect_frame':
        final camBufIdx = (payload['camBufIdx'] as num?)?.toInt();
        if (camBufIdx == null || camPool == null) return <String, dynamic>{'ok': true};

        final buf = camPool![camBufIdx];
        // Claim PASS_READY → PASS_READING.
        if (!buf.beginPassiveRead()) {
          // Buffer was freed (e.g. main reused it) — skip this frame.
          return <String, dynamic>{'ok': true};
        }

        // Decode raw camera bytes from native memory.
        // The decode builds a new Dart-heap img.Image, so we can release the
        // native buffer as soon as decode returns.
        final frame = _decodeCameraFromBuffer(buf, payload);
        buf.endPassiveRead(); // PASS_READING → FREE — native buffer available for reuse

        if (frame == null) return <String, dynamic>{'ok': true};

        final face = _deserializeFaceMap((payload['face'] as Map).cast<String, dynamic>());
        passive.collectPassiveMetrics(frame, face);
        return <String, dynamic>{'ok': true};
      case 'passive_result':
        final antiSpoofScore = passive.getAntiSpoofScore();
        final antiSpoofPassed = passive.isAntiSpoofPassed();
        final rppg = passive.getRppgResult();
        return <String, dynamic>{
          'antiSpoofScore': antiSpoofScore,
          'antiSpoofPassed': antiSpoofPassed,
          'rppg': <String, dynamic>{
            'hr': rppg?.hr,
            'passed': rppg?.passed ?? false,
            'sampleCount': rppg?.sampleCount ?? 0,
            'durationMs': rppg?.durationMs ?? 0,
          },
        };
      case 'stop':
        return <String, dynamic>{'ok': true};
      case 'dispose':
        await passive.dispose();
        return <String, dynamic>{'ok': true};
      default:
        throw StateError('Unknown passive worker cmd: $cmd');
    }
  }

  await _serve(commandPort, mainSendPort, handle);
}

void _matchWorkerMain(List<Object?> args) {
  final mainSendPort = _initializeWorkerIsolate(args);
  unawaited(_matchWorkerLoop(mainSendPort));
}

Future<void> _matchWorkerLoop(SendPort mainSendPort) async {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  final recognizer = FaceRecognizer();
  List<double>? nfcEmbedding;
  Uint8List? nfcInputPng;
  Uint8List? selfieInputPng;

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        debugPrint('[FaceVerification] Match worker: initializing GhostFaceNet from buffer');
        await recognizer.initializeFromBuffer((payload['ghost'] as TransferableTypedData).materialize().asUint8List());
        debugPrint('[FaceVerification] Match worker: initialized');
        return <String, dynamic>{'ok': true};
      case 'start_session':
        // nfcEmbedding is preserved across sessions — the NFC image doesn't change
        // within a widget lifetime, so re-embedding is wasteful.
        return <String, dynamic>{'ok': true};
      case 'prepare_nfc_face':
        debugPrint(
          '[FaceVerification] Match worker: preparing NFC embedding from ${payload['width']}x${payload['height']} crop',
        );
        final nfcFace = _imageFromPayload(payload);
        nfcInputPng = recognizer.modelInputPng(nfcFace);
        nfcEmbedding = recognizer.generateEmbedding(nfcFace, label: 'NFC');
        debugPrint('[FaceVerification] Match worker: NFC embedding ready, length=${nfcEmbedding?.length ?? 0}');
        return <String, dynamic>{'ok': true};
      case 'match_selfie':
        final nfc = nfcEmbedding;
        if (nfc == null) {
          debugPrint('[FaceVerification] Match worker: cannot match selfie, NFC embedding is null');
          return <String, dynamic>{'score': 0.0};
        }
        debugPrint(
          '[FaceVerification] Match worker: generating selfie embedding from ${payload['width']}x${payload['height']} crop',
        );
        final selfieFace = _imageFromPayload(payload);
        selfieInputPng = recognizer.modelInputPng(selfieFace);
        final emb = recognizer.generateEmbedding(selfieFace, label: 'selfie');
        final score = recognizer.cosineSimilarity(nfc, emb);
        debugPrint('[FaceVerification] Match worker: comparison done, score=${(score * 100).toStringAsFixed(2)}%');
        return <String, dynamic>{'score': score, 'nfcInputPng': nfcInputPng, 'selfieInputPng': selfieInputPng};
      case 'stop':
        return <String, dynamic>{'ok': true};
      case 'dispose':
        await recognizer.dispose();
        return <String, dynamic>{'ok': true};
      default:
        throw StateError('Unknown match worker cmd: $cmd');
    }
  }

  await _serve(commandPort, mainSendPort, handle);
}

Future<Uint8List> _loadModelBytes(String asset) async {
  final data = await rootBundle.load(asset);
  return data.buffer.asUint8List();
}

Future<void> _serve(
  ReceivePort commandPort,
  SendPort mainSendPort,
  Future<Map<String, dynamic>> Function(String cmd, Map<String, dynamic> payload) handle,
) async {
  await for (final dynamic message in commandPort) {
    if (message is! Map) continue;
    final id = message['id'] as int?;
    final cmd = message['cmd'] as String?;
    final payload = (message['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    if (id == null || cmd == null) continue;
    try {
      final result = await handle(cmd, payload);
      mainSendPort.send(<String, dynamic>{'id': id, 'result': result});
    } catch (e) {
      mainSendPort.send(<String, dynamic>{'id': id, 'error': e.toString()});
    }
  }
}

/// Builds plane metadata (no pixel bytes) for passing via SendPort to isolates.
/// Each plane entry records its byte offset within the packed native buffer.
Map<String, dynamic> _cameraNativeMetadata(CameraImage image, int rotationDegrees) {
  var offset = 0;
  final planesList = <Map<String, dynamic>>[];
  for (final Plane p in image.planes) {
    final byteCount = p.bytes.length;
    planesList.add(<String, dynamic>{
      'offset': offset,
      'byteCount': byteCount,
      'bytesPerRow': p.bytesPerRow,
      'bytesPerPixel': p.bytesPerPixel ?? 1,
    });
    offset += byteCount;
  }
  return <String, dynamic>{
    'width': image.width,
    'height': image.height,
    'format': image.format.group.name,
    'rotation': rotationDegrees,
    'planes': planesList,
  };
}

/// Decodes raw camera bytes from a native FFI buffer into a Dart-heap img.Image.
/// Creates zero-copy Uint8List views into native memory — no alloc until the
/// decode functions write their output RGB buffers.
img.Image? _decodeCameraFromBuffer(FaceFrameBuffer buf, Map<String, dynamic> payload) {
  final width = (payload['width'] as num).toInt();
  final height = (payload['height'] as num).toInt();
  final format = payload['format'] as String;
  final rotation = (payload['rotation'] as num).toInt();
  final planes = (payload['planes'] as List).cast<Map>().map((Map m) => m.cast<String, dynamic>()).toList();
  final dataPtr = buf.dataPtr;

  img.Image? frame;
  if (format == ImageFormatGroup.bgra8888.name && planes.isNotEmpty) {
    final p = planes.first;
    final bytes = (dataPtr + (p['offset'] as num).toInt()).asTypedList((p['byteCount'] as num).toInt());
    frame = _bgraToRgbImage(bytes, width, height, (p['bytesPerRow'] as num).toInt());
  } else if (format == ImageFormatGroup.yuv420.name && planes.length >= 3) {
    final planeViews = planes
        .map(
          (Map<String, dynamic> p) => <String, dynamic>{
            'bytes': (dataPtr + (p['offset'] as num).toInt()).asTypedList((p['byteCount'] as num).toInt()),
            'bytesPerRow': p['bytesPerRow'],
            'bytesPerPixel': p['bytesPerPixel'],
          },
        )
        .toList(growable: false);
    frame = _yuv420ToRgbImage(width, height, planeViews);
  }
  if (frame == null) return null;
  return _rotateToUpright(frame, rotation);
}

img.Image _bgraToRgbImage(Uint8List bytes, int width, int height, int bytesPerRow) {
  final rgb = Uint8List(width * height * 3);
  var dst = 0;
  for (var y = 0; y < height; y++) {
    var src = y * bytesPerRow;
    for (var x = 0; x < width; x++) {
      rgb[dst++] = bytes[src + 2];
      rgb[dst++] = bytes[src + 1];
      rgb[dst++] = bytes[src];
      src += 4;
    }
  }
  return img.Image.fromBytes(width: width, height: height, bytes: rgb.buffer, numChannels: 3);
}

img.Image _yuv420ToRgbImage(int width, int height, List<Map<String, dynamic>> planes) {
  final yBytes = planes[0]['bytes'] as Uint8List;
  final uBytes = planes[1]['bytes'] as Uint8List;
  final vBytes = planes[2]['bytes'] as Uint8List;
  final yRowStride = planes[0]['bytesPerRow'] as int;
  final uvRowStride = planes[1]['bytesPerRow'] as int;
  final uvPixelStride = (planes[1]['bytesPerPixel'] as int?) ?? 1;
  final vRowStride = planes[2]['bytesPerRow'] as int;
  final vPixelStride = (planes[2]['bytesPerPixel'] as int?) ?? 1;

  final rgb = Uint8List(width * height * 3);
  var dst = 0;
  for (var y = 0; y < height; y++) {
    final uvRow = y >> 1;
    final yRowStart = y * yRowStride;
    final uRowStart = uvRow * uvRowStride;
    final vRowStart = uvRow * vRowStride;
    for (var x = 0; x < width; x++) {
      final uvCol = x >> 1;
      final yv = yBytes[yRowStart + x] & 0xFF;
      final uv = (uBytes[uRowStart + uvCol * uvPixelStride] & 0xFF) - 128;
      final vv = (vBytes[vRowStart + uvCol * vPixelStride] & 0xFF) - 128;
      // Full-range BT.601 YCbCr→RGB, coefficients ×1024 for integer arithmetic
      final yScaled = yv << 10;
      rgb[dst++] = ((yScaled + 1436 * vv) >> 10).clamp(0, 255);
      rgb[dst++] = ((yScaled - 352 * uv - 731 * vv) >> 10).clamp(0, 255);
      rgb[dst++] = ((yScaled + 1814 * uv) >> 10).clamp(0, 255);
    }
  }
  return img.Image.fromBytes(width: width, height: height, bytes: rgb.buffer, numChannels: 3);
}

img.Image _rotateToUpright(img.Image image, int rotationDegrees) {
  final normalized = ((rotationDegrees % 360) + 360) % 360;
  if (normalized == 0) return image;
  if (normalized == 90) return _rotate90CW(image);
  if (normalized == 270) return _rotate270CW(image);
  if (normalized == 180) return _rotate180(image);
  // Non-axis-aligned fallback (rare)
  final rotated = img.copyRotate(image, angle: normalized.toDouble());
  if (rotated.numChannels == 3) return rotated;
  final rgb = rotated.getBytes(order: img.ChannelOrder.rgb);
  return img.Image.fromBytes(width: rotated.width, height: rotated.height, bytes: rgb.buffer, numChannels: 3);
}

img.Image _transposePixels(img.Image src, int dstW, int dstH, int Function(int x, int y) dstIdx) {
  final srcW = src.width, srcH = src.height;
  final s = src.getBytes(order: img.ChannelOrder.rgb);
  final d = Uint8List(dstW * dstH * 3);
  for (var y = 0; y < srcH; y++) {
    for (var x = 0; x < srcW; x++) {
      final si = (y * srcW + x) * 3;
      final di = dstIdx(x, y) * 3;
      d[di] = s[si];
      d[di + 1] = s[si + 1];
      d[di + 2] = s[si + 2];
    }
  }
  return img.Image.fromBytes(width: dstW, height: dstH, bytes: d.buffer, numChannels: 3);
}

// 90° CW: output[dstY=x][dstX=srcH-1-y] = src[y][x], output size = srcH × srcW
img.Image _rotate90CW(img.Image src) {
  final dstW = src.height, dstH = src.width;
  return _transposePixels(src, dstW, dstH, (x, y) => x * dstW + (dstW - 1 - y));
}

// 270° CW (= 90° CCW): output[dstY=srcW-1-x][dstX=y] = src[y][x]
img.Image _rotate270CW(img.Image src) {
  final dstW = src.height, dstH = src.width;
  return _transposePixels(src, dstW, dstH, (x, y) => (dstH - 1 - x) * dstW + y);
}

// 180°: output[srcH-1-y][srcW-1-x] = src[y][x]
img.Image _rotate180(img.Image src) {
  final w = src.width, h = src.height;
  return _transposePixels(src, w, h, (x, y) => (h - 1 - y) * w + (w - 1 - x));
}

Map<String, dynamic> _imagePayload(img.Image image) {
  return <String, dynamic>{
    'width': image.width,
    'height': image.height,
    'rgb': image.getBytes(order: img.ChannelOrder.rgb),
  };
}

img.Image _imageFromPayload(Map<String, dynamic> payload) {
  return img.Image.fromBytes(
    width: (payload['width'] as num).toInt(),
    height: (payload['height'] as num).toInt(),
    bytes: (payload['rgb'] as Uint8List).buffer,
    numChannels: 3,
  );
}

Map<String, dynamic> _serializeFace(FaceObservation face) {
  final landmarks = face.result.landmarks.first;
  final flat = <double>[];
  for (final lm in landmarks) {
    flat.add(lm.x);
    flat.add(lm.y);
    flat.add(lm.z);
  }
  final matrix = face.result.transformMatrices?.isNotEmpty == true ? face.result.transformMatrices!.first : null;
  return <String, dynamic>{
    'bbox': <double>[face.boundingBox.left, face.boundingBox.top, face.boundingBox.right, face.boundingBox.bottom],
    'bboxAreaRatio': face.boundingBoxAreaRatio,
    'bboxCenter': <double>[face.boundingBoxCenter.dx, face.boundingBoxCenter.dy],
    'yaw': face.yawDegrees,
    'mouthRatio': face.mouthRatio,
    'blendshapes': face.blendshapeScores,
    'landmarks': flat,
    'matrix': matrix,
    'alignedRgb': face.alignedFace112.getBytes(order: img.ChannelOrder.rgb),
  };
}

FaceObservation _deserializeFaceMap(Map<String, dynamic> map) {
  final bbox = (map['bbox'] as List).cast<num>();
  final yaw = (map['yaw'] as num?)?.toDouble();
  final mouthRatio = (map['mouthRatio'] as num).toDouble();
  final blendRaw = (map['blendshapes'] as Map).cast<String, dynamic>();
  final blend = <String, double>{for (final e in blendRaw.entries) e.key: (e.value as num).toDouble()};

  final landmarksFlat = (map['landmarks'] as List).cast<num>();
  final landmarks = <NormalizedLandmark>[];
  for (var i = 0; i + 2 < landmarksFlat.length; i += 3) {
    landmarks.add(
      NormalizedLandmark(landmarksFlat[i].toDouble(), landmarksFlat[i + 1].toDouble(), landmarksFlat[i + 2].toDouble()),
    );
  }

  final matrix = (map['matrix'] as List?)?.cast<num>().map((num v) => v.toDouble()).toList(growable: false);
  final categories = blend.entries
      .map((MapEntry<String, double> e) => Category(e.key, e.value))
      .toList(growable: false);
  final result = FaceLandmarkerResult(
    landmarks: <List<NormalizedLandmark>>[landmarks],
    blendshapes: <List<Category>>[categories],
    transformMatrices: matrix == null ? null : <List<double>>[matrix],
  );

  final alignedRgb = map['alignedRgb'] as Uint8List?;
  if (alignedRgb == null) throw StateError('Worker face payload missing aligned image');
  final aligned = img.Image.fromBytes(width: 112, height: 112, bytes: alignedRgb.buffer, numChannels: 3);

  final center = (map['bboxCenter'] as List?)?.cast<num>();
  return FaceObservation(
    result: result,
    boundingBox: Rect.fromLTRB(bbox[0].toDouble(), bbox[1].toDouble(), bbox[2].toDouble(), bbox[3].toDouble()),
    boundingBoxAreaRatio: (map['bboxAreaRatio'] as num?)?.toDouble() ?? 0.0,
    boundingBoxCenter: center != null && center.length >= 2
        ? Offset(center[0].toDouble(), center[1].toDouble())
        : const Offset(0.5, 0.5),
    mouthRatio: mouthRatio,
    yawDegrees: yaw,
    blendshapeScores: blend,
    alignedFace112: aligned,
  );
}
