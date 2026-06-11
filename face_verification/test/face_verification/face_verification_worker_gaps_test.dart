import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/face_verification_worker.dart';

// ---------------------------------------------------------------------------
// These tests drive the worker isolate command handlers through their model-
// backed branches by loading the real TFLite assets in the test isolate and
// shipping them to the spawned worker as TransferableTypedData. The debug
// entry points skip the plugin/binary-messenger init, so no platform channels
// are needed inside the worker. The native FaceFrameBuffer FFI is NOT used:
// 'init' only consumes buffer addresses (never dereferenced) and the embedding
// / encoded-crop commands operate purely on Dart-heap images.
//
// This reaches the match-worker init + embedding paths and the pipeline-worker
// init + detect_crop_encoded success/no-face paths that the existing suites,
// which never initialise a model, cannot.
// ---------------------------------------------------------------------------

Future<Uint8List> _load(String name) async {
  final data = await rootBundle.load('packages/face_verification/lib/src/models/$name');
  return data.buffer.asUint8List();
}

TransferableTypedData _ttd(Uint8List b) => TransferableTypedData.fromList(<Uint8List>[b]);

// A face-like 128x128 image the MediaPipe detector reliably detects.
img.Image _faceImage() {
  const w = 128, h = 128;
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 180, 160));
  img.fillCircle(im, x: w ~/ 2, y: h ~/ 2, radius: (w * 0.3).round(), color: img.ColorRgb8(220, 190, 170));
  img.fillCircle(
    im,
    x: (w * 0.4).round(),
    y: (h * 0.42).round(),
    radius: (w * 0.04).round(),
    color: img.ColorRgb8(30, 30, 30),
  );
  img.fillCircle(
    im,
    x: (w * 0.6).round(),
    y: (h * 0.42).round(),
    radius: (w * 0.04).round(),
    color: img.ColorRgb8(30, 30, 30),
  );
  img.fillCircle(
    im,
    x: (w * 0.5).round(),
    y: (h * 0.55).round(),
    radius: (w * 0.03).round(),
    color: img.ColorRgb8(180, 150, 130),
  );
  img.fillRect(
    im,
    x1: (w * 0.42).round(),
    y1: (h * 0.66).round(),
    x2: (w * 0.58).round(),
    y2: (h * 0.70).round(),
    color: img.ColorRgb8(150, 80, 80),
  );
  return im;
}

// Minimal request/response harness over a spawned worker isolate (mirrors the
// helper used in the existing worker suites, kept local for independence).
class _Harness {
  _Harness._(this._isolate, this._receivePort, this._sendPort);

  final Isolate _isolate;
  final ReceivePort _receivePort;
  final SendPort _sendPort;
  int _id = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = <int, Completer<Map<String, dynamic>>>{};
  StreamSubscription<dynamic>? _subscription;

  static Future<_Harness> spawn(void Function(SendPort) entry) async {
    final receivePort = ReceivePort();
    final ready = Completer<_Harness>();
    final isolate = await Isolate.spawn(entry, receivePort.sendPort);
    late _Harness harness;

    final sub = receivePort.listen((dynamic message) {
      if (message is SendPort) {
        harness = _Harness._(isolate, receivePort, message);
        if (!ready.isCompleted) ready.complete(harness);
        return;
      }
      if (message is Map && ready.isCompleted) {
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

    final result = await ready.future;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Match worker — model-backed embedding paths', () {
    late _Harness harness;

    setUp(() async {
      harness = await _Harness.spawn(FaceVerificationWorker.debugMatchWorkerEntry);
      final init = await harness.request(
        'init',
        payload: <String, dynamic>{'ghost': _ttd(await _load('GhostFaceNet_fp32_V2.tflite'))},
      );
      expect(init['ok'], isTrue);
    });

    tearDown(() => harness.dispose());

    Map<String, dynamic> payload(img.Image image) => FaceVerificationWorker.debugImagePayload(image);

    test('prepare_nfc_face then match_selfie returns a real cosine score', () async {
      expect(
        await harness.request('prepare_nfc_face', payload: payload(img.Image(width: 112, height: 112))),
        containsPair('ok', true),
      );

      final res = await harness.request('match_selfie', payload: payload(img.Image(width: 112, height: 112)));
      final score = res['score'] as num;
      // Same image embedded twice → cosine similarity is 1.0.
      expect(score.toDouble(), closeTo(1.0, 1e-3));
    });

    test('match_selfie of differing faces produces a finite in-range score', () async {
      await harness.request('prepare_nfc_face', payload: payload(_faceImage()));

      final other = img.Image(width: 112, height: 112);
      img.fill(other, color: img.ColorRgb8(20, 40, 60));
      final res = await harness.request('match_selfie', payload: payload(other));
      final score = (res['score'] as num).toDouble();
      expect(score, inInclusiveRange(-1.0001, 1.0001));
    });

    test('store_consistency_selfie then check_consistency_selfie scores against the stored reference', () async {
      expect(
        await harness.request('store_consistency_selfie', payload: payload(img.Image(width: 112, height: 112))),
        containsPair('ok', true),
      );

      // With a reference stored, the consistency check now runs the model path
      // (not the 1.0 fallback for a missing reference). Identical image → ~1.0.
      final res = await harness.request(
        'check_consistency_selfie',
        payload: payload(img.Image(width: 112, height: 112)),
      );
      expect((res['score'] as num).toDouble(), closeTo(1.0, 1e-3));
    });

    test('start_session clears the stored consistency reference but keeps nfc embedding', () async {
      await harness.request('store_consistency_selfie', payload: payload(img.Image(width: 112, height: 112)));
      await harness.request('prepare_nfc_face', payload: payload(img.Image(width: 112, height: 112)));

      expect(await harness.request('start_session'), containsPair('ok', true));

      // Consistency reference was cleared → check falls back to 1.0.
      final check = await harness.request(
        'check_consistency_selfie',
        payload: payload(img.Image(width: 112, height: 112)),
      );
      expect((check['score'] as num).toDouble(), closeTo(1.0, 1e-9));

      // NFC embedding survives the session reset → match still computes a real score.
      final match = await harness.request('match_selfie', payload: payload(img.Image(width: 112, height: 112)));
      expect((match['score'] as num).toDouble(), closeTo(1.0, 1e-3));
    });

    test('dispose after init releases the recognizer', () async {
      expect(await harness.request('dispose'), containsPair('ok', true));
    });
  });

  group('Passive worker — model-backed init', () {
    late _Harness harness;

    setUp(() async {
      harness = await _Harness.spawn(FaceVerificationWorker.debugPassiveWorkerEntry);
      final init = await harness.request(
        'init',
        payload: <String, dynamic>{
          'v1': _ttd(await _load('minifasnet_v1se.tflite')),
          'v2': _ttd(await _load('minifasnet_v2.tflite')),
          'bigSmall1': _ttd(await _load('bigsmall_1.tflite')),
          'bigSmall2': _ttd(await _load('bigsmall_2.tflite')),
          'bigSmall3': _ttd(await _load('bigsmall_3.tflite')),
          // Addresses only stored, never dereferenced without a collect_frame.
          'camBufAddrs': <int>[0x1000, 0x2000],
          'camBufCap': 1024,
        },
      );
      expect(init['ok'], isTrue);
    });

    tearDown(() => harness.dispose());

    test('init loads models, start_session resets, passive_result reports defaults', () async {
      expect(await harness.request('start_session'), containsPair('ok', true));

      // No frames collected yet → anti-spoof has no score, rPPG has not passed.
      final res = await harness.request('passive_result');
      expect(res['antiSpoofPassed'], isFalse);
      final rppg = (res['rppg'] as Map).cast<String, dynamic>();
      expect(rppg['passed'], isFalse);
      expect((rppg['sampleCount'] as num).toInt(), 0);
    });

    test('collect_frame with a missing camBufIdx is a no-op even after init', () async {
      expect(await harness.request('collect_frame', payload: <String, dynamic>{}), containsPair('ok', true));
    });

    test('stop and dispose succeed after init', () async {
      expect(await harness.request('stop'), containsPair('ok', true));
      expect(await harness.request('dispose'), containsPair('ok', true));
    });
  });

  group('Pipeline worker — model-backed detect_crop_encoded', () {
    late _Harness harness;

    setUp(() async {
      harness = await _Harness.spawn(FaceVerificationWorker.debugPipelineWorkerEntry);
      final init = await harness.request(
        'init',
        payload: <String, dynamic>{
          'detector': _ttd(await _load('face_detector.tflite')),
          'landmarks': _ttd(await _load('face_landmarks_detector.tflite')),
          'blendshapes': _ttd(await _load('face_blendshapes.tflite')),
          // Addresses are only stored, never dereferenced by detect_crop_encoded.
          'camBufAddrs': <int>[0x1000, 0x2000],
          'camBufCap': 1024,
        },
      );
      expect(init['ok'], isTrue);
    });

    tearDown(() => harness.dispose());

    test('detect_crop_encoded returns ok with a 112x112 PNG for a detectable face', () async {
      final png = Uint8List.fromList(img.encodePng(_faceImage()));
      final res = await harness.request('detect_crop_encoded', payload: <String, dynamic>{'bytes': png});

      expect(res['ok'], isTrue);
      final cropPng = res['png'] as Uint8List;
      expect(cropPng, isNotEmpty);
      final decoded = img.decodeImage(cropPng)!;
      expect(decoded.width, 112);
      expect(decoded.height, 112);
    });

    test('detect_crop_encoded returns not-ok when no face is present', () async {
      final blank = img.Image(width: 128, height: 128);
      img.fill(blank, color: img.ColorRgb8(0, 0, 0));
      final png = Uint8List.fromList(img.encodePng(blank));

      final res = await harness.request('detect_crop_encoded', payload: <String, dynamic>{'bytes': png});
      expect(res['ok'], isFalse);
    });

    test('start_session resets tracking and dispose closes the detector', () async {
      expect(await harness.request('start_session'), containsPair('ok', true));
      expect(await harness.request('stop'), containsPair('ok', true));
      expect(await harness.request('dispose'), containsPair('ok', true));
    });
  });
}
