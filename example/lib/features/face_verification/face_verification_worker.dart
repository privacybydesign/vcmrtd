import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
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
  // Single pipeline isolate handles decode + detect + landmarks (matches Kotlin FaceLandmarkPipeline)
  final _pipeline = _IsolateClient(_pipelineWorkerMain);
  final _passive = _IsolateClient(_passiveWorkerMain);
  final _match = _IsolateClient(_matchWorkerMain);

  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast();

  Map<String, dynamic>? _queuedPipelinePayload;
  Map<String, dynamic>? _queuedPassivePayload;
  bool _pipelineBusy = false;
  bool _passiveBusy = false;
  Completer<void>? _passiveIdle;
  int _sessionId = 0;

  Stream<WorkerFrameResult> get frames => _frames.stream;

  Future<void> initialize() async {
    // Spawn all 3 isolates in parallel.
    await Future.wait(<Future<void>>[_pipeline.start(), _passive.start(), _match.start()]);

    final results = await Future.wait([
      rootBundle.load('assets/face_verification/face_detector.tflite'),
      rootBundle.load('assets/face_verification/face_landmarks_detector.tflite'),
      rootBundle.load('assets/face_verification/face_blendshapes.tflite'),
      rootBundle.load('assets/face_verification/minifasnet_v1se.tflite'),
      rootBundle.load('assets/face_verification/minifasnet_v2.tflite'),
      rootBundle.load('assets/face_verification/bigsmall_1.tflite'),
      rootBundle.load('assets/face_verification/bigsmall_2.tflite'),
      rootBundle.load('assets/face_verification/bigsmall_3.tflite'),
      rootBundle.load('assets/face_verification/GhostFaceNet_fp32.tflite'),
    ]);
    final detectorBytes = results[0].buffer.asUint8List();
    final landmarksBytes = results[1].buffer.asUint8List();
    final blendshapesBytes = results[2].buffer.asUint8List();
    final v1Bytes = results[3].buffer.asUint8List();
    final v2Bytes = results[4].buffer.asUint8List();
    final bs1Bytes = results[5].buffer.asUint8List();
    final bs2Bytes = results[6].buffer.asUint8List();
    final bs3Bytes = results[7].buffer.asUint8List();
    final recognizerBytes = results[8].buffer.asUint8List();

    // Initialize all 3 isolates in parallel — each loads its own TFLite interpreters.
    await Future.wait(<Future<Map<String, dynamic>>>[
      _pipeline.request(
        'init',
        payload: <String, dynamic>{
          'detector': detectorBytes,
          'landmarks': landmarksBytes,
          'blendshapes': blendshapesBytes,
        },
      ),
      _passive.request(
        'init',
        payload: <String, dynamic>{
          'v1': v1Bytes,
          'v2': v2Bytes,
          'bigSmall': <Uint8List>[bs1Bytes, bs2Bytes, bs3Bytes],
        },
      ),
      _match.request('init', payload: <String, dynamic>{'model': recognizerBytes}),
    ]);
  }

  Future<void> startSession() async {
    _sessionId++;
    await Future.wait(<Future<Map<String, dynamic>>>[
      _pipeline.request('start_session'),
      _passive.request('start_session'),
      _match.request('start_session'),
    ]);
    _queuedPipelinePayload = null;
    _queuedPassivePayload = null;
    _pipelineBusy = false;
    _passiveBusy = false;
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

  Future<double> matchSelfie(img.Image selfie) async {
    final res = await _match.request('match_selfie', payload: _imagePayload(selfie));
    return (res['score'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> processCameraFrame(CameraImage cameraImage, int rotationDegrees) async {
    _enqueuePipelineFrame(<String, dynamic>{
      'sessionId': _sessionId,
      'camera': _cameraPayload(cameraImage, rotationDegrees),
    });
  }

  // Back-pressure: only the latest camera frame is queued. If the isolate is still busy
  // with the previous frame, the intermediate frames are silently dropped so the pipeline
  // never accumulates unbounded lag.
  void _enqueuePipelineFrame(Map<String, dynamic> payload) {
    if (_pipelineBusy) {
      _queuedPipelinePayload = payload;
      return;
    }
    _pipelineBusy = true;
    unawaited(_runPipelinePayload(payload));
  }

  Future<void> _runPipelinePayload(Map<String, dynamic> payload) async {
    final sessionId = payload['sessionId'] as int;
    final cameraPayload = (payload['camera'] as Map).cast<String, dynamic>();
    try {
      final pipelineResult = await _pipeline.request('process_frame', payload: cameraPayload);
      if (sessionId == _sessionId) {
        final faceMap = pipelineResult['face'] as Map<String, dynamic>?;
        if (faceMap != null) {
          // Forward the already-decoded frame so passive skips its own YUV decode+rotate.
          _enqueuePassiveFrame(<String, dynamic>{
            'face': faceMap,
            'frameRgb': pipelineResult['frameRgb'] as Uint8List?,
            'frameW': pipelineResult['frameW'] as int?,
            'frameH': pipelineResult['frameH'] as int?,
          });
        }
        _emitFrameResult(WorkerFrameResult(face: faceMap == null ? null : _deserializeFaceMap(faceMap)));
      }
    } catch (e) {
      if (sessionId == _sessionId) _emitFrameError(e);
    }

    final next = _queuedPipelinePayload;
    _queuedPipelinePayload = null;
    if (next != null) {
      unawaited(_runPipelinePayload(next));
    } else {
      _pipelineBusy = false;
    }
  }

  void _emitFrameResult(WorkerFrameResult result) {
    if (!_frames.isClosed) _frames.add(result);
  }

  void _emitFrameError(Object error) {
    if (!_frames.isClosed) _frames.addError(error);
  }

  Future<WorkerPassiveResult> getPassiveResult() async {
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
    _queuedPipelinePayload = null;
    _queuedPassivePayload = null;
    await _waitPassiveIdle();
    await _pipeline.request('stop');
    await _passive.request('stop');
    await _match.request('stop');
  }

  Future<void> dispose() async {
    await _pipeline.dispose();
    await _passive.dispose();
    await _match.dispose();
    await _frames.close();
    _queuedPipelinePayload = null;
    _queuedPassivePayload = null;
    _pipelineBusy = false;
    _passiveBusy = false;
    _completePassiveIdle();
  }

  void _enqueuePassiveFrame(Map<String, dynamic> payload) {
    if (_passiveBusy) {
      _queuedPassivePayload = payload;
      _passiveIdle ??= Completer<void>();
      return;
    }
    _passiveBusy = true;
    _passiveIdle ??= Completer<void>();
    unawaited(_runPassivePayload(payload));
  }

  Future<void> _runPassivePayload(Map<String, dynamic> payload) async {
    try {
      await _passive.request('collect_frame', payload: payload);
    } catch (_) {}

    final next = _queuedPassivePayload;
    _queuedPassivePayload = null;
    if (next != null) {
      unawaited(_runPassivePayload(next));
      return;
    }

    _passiveBusy = false;
    _completePassiveIdle();
  }

  // Must drain the passive queue before reading results: the last buffered frames may still
  // be in-flight in the isolate when getPassiveResult() is called after the session ends.
  Future<void> _waitPassiveIdle() {
    if (!_passiveBusy && _queuedPassivePayload == null) return Future<void>.value();
    return (_passiveIdle ??= Completer<void>()).future;
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

// Single isolate that handles decode + detect + landmarks, matching Kotlin's FaceLandmarkPipeline.
// Tracking crop is updated internally — no round-trip to main needed.
Future<void> _pipelineWorkerLoop(SendPort mainSendPort) async {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  final detector = FaceDetectorService();

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        detector.initializeFromBuffers(
          detector: payload['detector'] as Uint8List,
          landmarks: payload['landmarks'] as Uint8List,
          blendshapes: payload['blendshapes'] as Uint8List,
        );
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
        return _handleProcessFrame(detector, payload);
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

Map<String, dynamic> _handleProcessFrame(FaceDetectorService detector, Map<String, dynamic> payload) {
  final frame = _decodeCameraPayload(payload);
  if (frame == null) {
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }
  final crop = detector.runDetectorStage(frame);
  if (crop == null) {
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }
  final face = detector.runLandmarkStage(frame, crop, runBlendshapes: true);
  if (face == null) {
    detector.resetTracking();
    return <String, dynamic>{'face': null};
  }
  detector.setTrackingCrop(detector.computeTrackingCrop(face.result, frame.width, frame.height));
  // Include decoded frame so passive can skip its own YUV decode.
  return <String, dynamic>{
    'face': _serializeFace(face),
    'frameRgb': frame.getBytes(order: img.ChannelOrder.rgb),
    'frameW': frame.width,
    'frameH': frame.height,
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

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        passive.initializeFromBuffers(
          v1: payload['v1'] as Uint8List,
          v2: payload['v2'] as Uint8List,
          bigSmall: (payload['bigSmall'] as List).cast<Uint8List>(),
        );
        return <String, dynamic>{'ok': true};
      case 'start_session':
        passive.reset();
        return <String, dynamic>{'ok': true};
      case 'collect_frame':
        final frameRgb = payload['frameRgb'] as Uint8List?;
        final frameW = (payload['frameW'] as num?)?.toInt();
        final frameH = (payload['frameH'] as num?)?.toInt();
        if (frameRgb == null || frameW == null || frameH == null) {
          return <String, dynamic>{'ok': true};
        }
        final frame = img.Image.fromBytes(width: frameW, height: frameH, bytes: frameRgb.buffer, numChannels: 3);
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

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        await recognizer.initializeFromBuffer(payload['model'] as Uint8List);
        return <String, dynamic>{'ok': true};
      case 'start_session':
        // nfcEmbedding is preserved across sessions — the NFC image doesn't change
        // within a widget lifetime, so re-embedding is wasteful.
        return <String, dynamic>{'ok': true};
      case 'prepare_nfc_face':
        nfcEmbedding = recognizer.generateEmbedding(_imageFromPayload(payload));
        return <String, dynamic>{'ok': true};
      case 'match_selfie':
        final nfc = nfcEmbedding;
        if (nfc == null) return <String, dynamic>{'score': 0.0};
        final emb = recognizer.generateEmbedding(_imageFromPayload(payload));
        return <String, dynamic>{'score': recognizer.cosineSimilarity(nfc, emb)};
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

Map<String, dynamic> _cameraPayload(CameraImage image, int rotationDegrees) {
  return <String, dynamic>{
    'width': image.width,
    'height': image.height,
    'format': image.format.group.name,
    'rotation': rotationDegrees,
    'planes': image.planes
        .map(
          (Plane plane) => <String, dynamic>{
            'bytes': plane.bytes,
            'bytesPerRow': plane.bytesPerRow,
            'bytesPerPixel': plane.bytesPerPixel,
          },
        )
        .toList(growable: false),
  };
}

img.Image? _decodeCameraPayload(Map<String, dynamic> payload) {
  final width = (payload['width'] as num).toInt();
  final height = (payload['height'] as num).toInt();
  final format = payload['format'] as String;
  final rotation = (payload['rotation'] as num).toInt();
  final planes = (payload['planes'] as List).cast<Map>().map((Map p) => p.cast<String, dynamic>()).toList();

  img.Image? frame;
  if (format == ImageFormatGroup.bgra8888.name && planes.isNotEmpty) {
    frame = _bgraToRgbImage(planes.first['bytes'] as Uint8List, width, height, planes.first['bytesPerRow'] as int);
  } else if (format == ImageFormatGroup.yuv420.name && planes.length >= 3) {
    frame = _yuv420ToRgbImage(width, height, planes);
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

  return FaceObservation(
    result: result,
    boundingBox: Rect.fromLTRB(bbox[0].toDouble(), bbox[1].toDouble(), bbox[2].toDouble(), bbox[3].toDouble()),
    mouthRatio: mouthRatio,
    yawDegrees: yaw,
    blendshapeScores: blend,
    alignedFace112: aligned,
  );
}
