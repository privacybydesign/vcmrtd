import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/features/face_verification/detection/face_detector.dart';
import 'package:vcmrtdapp/features/face_verification/detection/face_landmarker_types.dart';
import 'package:vcmrtdapp/features/face_verification/liveness/liveness_service.dart';

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

class FaceVerificationWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  int _requestId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};

  Future<void> initialize() async {
    if (_isolate != null) return;
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
    _isolate = await Isolate.spawn(_workerMain, _receivePort!.sendPort);
    await ready.future;
    await _request('init');
  }

  Future<void> startSession() async {
    await _request('start_session');
  }

  Future<img.Image?> detectAndCropEncoded(Uint8List encoded) async {
    final res = await _request('detect_crop_encoded', payload: <String, dynamic>{'bytes': encoded});
    if (res['ok'] != true) return null;
    final png = res['png'] as Uint8List?;
    if (png == null || png.isEmpty) return null;
    return img.decodeImage(png);
  }

  Future<WorkerFrameResult> processFrame(img.Image frame) async {
    final rgb = Uint8List(frame.width * frame.height * 3);
    var i = 0;
    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        final p = frame.getPixel(x, y);
        rgb[i++] = p.r.toInt();
        rgb[i++] = p.g.toInt();
        rgb[i++] = p.b.toInt();
      }
    }

    final res = await _request(
      'process_frame',
      payload: <String, dynamic>{'width': frame.width, 'height': frame.height, 'rgb': rgb},
    );
    final faceMap = res['face'] as Map<String, dynamic>?;
    final face = faceMap == null ? null : _deserializeFace(faceMap);
    return WorkerFrameResult(face: face);
  }

  Future<WorkerPassiveResult> getPassiveResult() async {
    final res = await _request('passive_result');
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
    if (_isolate == null) return;
    await _request('stop');
  }

  Future<void> dispose() async {
    final isolate = _isolate;
    if (isolate == null) return;
    try {
      await _request('dispose');
    } catch (_) {}
    isolate.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Worker disposed'));
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> _request(String cmd, {Map<String, dynamic>? payload}) {
    final send = _sendPort;
    if (send == null) throw StateError('Worker not initialized');
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    send.send(<String, dynamic>{'id': id, 'cmd': cmd, 'payload': payload ?? <String, dynamic>{}});
    return completer.future;
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

  FaceObservation _deserializeFace(Map<String, dynamic> map) {
    final bbox = (map['bbox'] as List).cast<num>();
    final yaw = (map['yaw'] as num?)?.toDouble();
    final mouthRatio = (map['mouthRatio'] as num).toDouble();
    final blendRaw = (map['blendshapes'] as Map).cast<String, dynamic>();
    final blend = <String, double>{for (final e in blendRaw.entries) e.key: (e.value as num).toDouble()};

    final landmarksFlat = (map['landmarks'] as List).cast<num>();
    final landmarks = <NormalizedLandmark>[];
    for (var i = 0; i + 2 < landmarksFlat.length; i += 3) {
      landmarks.add(
        NormalizedLandmark(
          landmarksFlat[i].toDouble(),
          landmarksFlat[i + 1].toDouble(),
          landmarksFlat[i + 2].toDouble(),
        ),
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

    final alignedPng = map['alignedPng'] as Uint8List?;
    final aligned = alignedPng != null ? img.decodeImage(alignedPng) : null;
    if (aligned == null) {
      throw StateError('Worker face payload missing aligned image');
    }

    return FaceObservation(
      result: result,
      boundingBox: Rect.fromLTRB(bbox[0].toDouble(), bbox[1].toDouble(), bbox[2].toDouble(), bbox[3].toDouble()),
      mouthRatio: mouthRatio,
      yawDegrees: yaw,
      blendshapeScores: blend,
      alignedFace112: aligned,
    );
  }
}

Future<void> _workerMain(SendPort mainSendPort) async {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  final detector = FaceDetectorService();
  final passive = PassiveLivenessService();

  Future<Map<String, dynamic>> handle(String cmd, Map<String, dynamic> payload) async {
    switch (cmd) {
      case 'init':
        await detector.initialize();
        await passive.initialize();
        return <String, dynamic>{'ok': true};
      case 'start_session':
        detector.resetTracking();
        passive.reset();
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
        final width = (payload['width'] as num).toInt();
        final height = (payload['height'] as num).toInt();
        final rgb = payload['rgb'] as Uint8List;
        final frame = img.Image(width: width, height: height);
        var i = 0;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final r = rgb[i++];
            final g = rgb[i++];
            final b = rgb[i++];
            frame.setPixelRgb(x, y, r, g, b);
          }
        }
        final face = detector.detectPrimaryFace(frame, runBlendshapes: true);
        if (face != null) {
          passive.collectPassiveMetrics(frame, face);
        } else {
          detector.resetTracking();
        }
        return <String, dynamic>{'face': face == null ? null : _serializeFace(face)};
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
        await detector.close();
        await passive.dispose();
        return <String, dynamic>{'ok': true};
      default:
        throw StateError('Unknown worker cmd: $cmd');
    }
  }

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

Map<String, dynamic> _serializeFace(FaceObservation face) {
  final landmarks = face.result.landmarks.first;
  final flat = <double>[];
  for (final lm in landmarks) {
    flat.add(lm.x);
    flat.add(lm.y);
    flat.add(lm.z);
  }
  final matrix = face.result.transformMatrices?.isNotEmpty == true ? face.result.transformMatrices!.first : null;
  final alignedPng = Uint8List.fromList(img.encodePng(face.alignedFace112));
  return <String, dynamic>{
    'bbox': <double>[face.boundingBox.left, face.boundingBox.top, face.boundingBox.right, face.boundingBox.bottom],
    'yaw': face.yawDegrees,
    'mouthRatio': face.mouthRatio,
    'blendshapes': face.blendshapeScores,
    'landmarks': flat,
    'matrix': matrix,
    'alignedPng': alignedPng,
  };
}
