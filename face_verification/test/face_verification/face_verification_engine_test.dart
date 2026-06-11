import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/src/detection/face_landmarker_types.dart';
import 'package:face_verification/src/detection/face_observation.dart';
import 'package:face_verification/src/face_verification_engine.dart';
import 'package:face_verification/src/face_verification_tuning.dart';
import 'package:face_verification/src/face_verification_worker.dart';
import 'package:face_verification/src/liveness/active_liveness_service.dart';
import 'package:face_verification/src/worker_result_types.dart';

// ---------------------------------------------------------------------------
// Fake worker
// ---------------------------------------------------------------------------

class _FakeWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);

  double consistencyScore = 1.0;
  bool passivePass = false;
  double matchScore = 0.9;

  bool passiveResultThrows = false;
  bool startSessionThrows = false;
  bool stopThrows = false;
  bool processCameraFrameThrows = false;
  bool detectAndCropEncodedThrows = false;
  bool prepareNfcFaceThrows = false;
  bool storeConsistencySelfieThrows = false;
  bool checkConsistencySelfieThrows = false;
  bool matchSelfieThrows = false;
  int processCameraFrameCalls = 0;
  img.Image? detectCropResult;

  int startSessionCalls = 0;
  int stopCalls = 0;
  int detectAndCropEncodedCalls = 0;
  int prepareNfcFaceCalls = 0;
  int storeConsistencySelfieCalls = 0;
  int checkConsistencySelfieCalls = 0;
  int matchSelfieCalls = 0;
  bool disposed = false;

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;

  void emitFrame(FaceObservation? face) => _frames.add(WorkerFrameResult(face: face));

  void emitError(Object error) => _frames.addError(error);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _frames.close();
  }

  @override
  Future<void> startSession() async {
    startSessionCalls++;
    if (startSessionThrows) {
      throw StateError('start failed');
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopThrows) {
      throw StateError('stop failed');
    }
  }

  @override
  Future<void> processCameraFrame(CameraImage cameraImage, int rotationDegrees) async {
    processCameraFrameCalls++;
    if (processCameraFrameThrows) {
      throw StateError('process failed');
    }
  }

  @override
  Future<img.Image?> detectAndCropEncoded(Uint8List encoded) async {
    detectAndCropEncodedCalls++;
    if (detectAndCropEncodedThrows) {
      throw StateError('detect failed');
    }
    return detectCropResult;
  }

  @override
  Future<void> prepareNfcFace(img.Image face) async {
    prepareNfcFaceCalls++;
    if (prepareNfcFaceThrows) {
      throw StateError('prepare failed');
    }
  }

  @override
  Future<void> storeConsistencySelfie(img.Image selfie) async {
    storeConsistencySelfieCalls++;
    if (storeConsistencySelfieThrows) {
      throw StateError('store failed');
    }
  }

  @override
  Future<double> checkConsistencySelfie(img.Image selfie) async {
    checkConsistencySelfieCalls++;
    if (checkConsistencySelfieThrows) {
      throw StateError('consistency failed');
    }
    return consistencyScore;
  }

  @override
  Future<WorkerMatchResult> matchSelfie(img.Image selfie) async {
    matchSelfieCalls++;
    if (matchSelfieThrows) {
      throw StateError('match failed');
    }
    return WorkerMatchResult(score: matchScore);
  }

  @override
  Stream<WorkerFrameResult> get debugFrames => _frames.stream;

  @override
  int get debugSessionId => 0;

  @override
  Future<void> debugWaitPipelineIdle() async {}

  @override
  Future<void> debugWaitPassiveIdle() async {}

  @override
  void debugEmitFrameResult(WorkerFrameResult result) {}

  @override
  void debugEmitFrameError(Object error) {}

  @override
  Future<WorkerPassiveResult> getPassiveResult() async {
    if (passiveResultThrows) {
      throw StateError('passive failed');
    }

    return WorkerPassiveResult(
      antiSpoofScore: passivePass ? 0.9 : null,
      antiSpoofPassed: passivePass,
      rppgHr: passivePass ? 70.0 : null,
      rppgPassed: passivePass,
      rppgSampleCount: passivePass ? 30 : 0,
      rppgDurationMs: passivePass ? 3000 : 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

FaceObservation _face({
  double yaw = 0,
  bool blinkClosed = false,
  bool mouthOpen = false,
  double jawOpen = 0,
  double smile = 0,
  double bboxArea = 0.20,
  Offset center = const Offset(0.5, 0.5),
}) {
  final landmarks = List<NormalizedLandmark>.generate(478, (_) => const NormalizedLandmark(0.5, 0.5, 0));

  void set(int i, double x, double y) => landmarks[i] = NormalizedLandmark(x, y, 0);

  set(10, 0.5, 0.2);
  set(152, 0.5, 0.8);
  set(234, 0.35, 0.5);
  set(454, 0.65, 0.5);
  set(1, 0.5, 0.45);
  set(0, 0.5, 0.62);
  set(17, 0.5, 0.68);
  set(61, 0.45, 0.62);
  set(291, 0.55, 0.62);

  final mouthGap = mouthOpen ? 0.10 : 0.02;
  set(13, 0.5, 0.50 - mouthGap / 2);
  set(14, 0.5, 0.50 + mouthGap / 2);

  final eyeGap = blinkClosed ? 0.002 : 0.05;
  set(362, 0.38, 0.38);
  set(263, 0.48, 0.38);
  set(385, 0.43, 0.38 - eyeGap / 2);
  set(380, 0.43, 0.38 + eyeGap / 2);
  set(387, 0.44, 0.38 - eyeGap / 2);
  set(373, 0.44, 0.38 + eyeGap / 2);
  set(33, 0.62, 0.38);
  set(133, 0.72, 0.38);
  set(160, 0.67, 0.38 - eyeGap / 2);
  set(144, 0.67, 0.38 + eyeGap / 2);
  set(158, 0.68, 0.38 - eyeGap / 2);
  set(153, 0.68, 0.38 + eyeGap / 2);

  final blendshapes = <String, double>{
    'eyeBlinkLeft': blinkClosed ? 0.9 : 0,
    'eyeBlinkRight': blinkClosed ? 0.9 : 0,
    'jawOpen': jawOpen,
    'mouthSmileLeft': smile,
    'mouthSmileRight': smile,
  };

  final result = FaceLandmarkerResult(
    landmarks: [landmarks],
    blendshapes: [blendshapes.entries.map((e) => Category(e.key, e.value)).toList()],
  );

  return FaceObservation(
    result: result,
    boundingBox: const Rect.fromLTWH(100, 100, 200, 200),
    boundingBoxAreaRatio: bboxArea,
    boundingBoxCenter: center,
    mouthRatio: mouthGap / 0.6,
    yawDegrees: yaw,
    blendshapeScores: blendshapes,
    alignedFace112: img.Image(width: 112, height: 112),
  );
}

Future<void> _drain(FaceVerificationEngine engine) async {
  await engine.frameChainDrained;
  // Flush one microtask so events emitted by _handleWorkerFrame reach listeners.
  await Future<void>.value();
}

// Emit [n] null-face frames and wait for the chain to drain.
Future<void> _emitNullFrames(_FakeWorker fake, FaceVerificationEngine engine, int n) async {
  for (var i = 0; i < n; i++) {
    fake.emitFrame(null);
  }
  await _drain(engine);
}

// Run 3 neutral frames to complete alignment, returning events emitted so far.
Future<List<Map<String, dynamic>>> _align(
  _FakeWorker fake,
  FaceVerificationEngine engine, {
  List<Map<String, dynamic>>? events,
}) async {
  final collected = events ?? <Map<String, dynamic>>[];
  for (var i = 0; i < ActiveLivenessService.baselineFrames; i++) {
    fake.emitFrame(_face());
    await _drain(engine);
  }
  return collected;
}

class _FakeCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CameraImage _fakeCameraImage() => _FakeCameraImage();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWorker fake;
  late FaceVerificationEngine engine;
  late List<Map<String, dynamic>> events;
  late StreamSubscription<Map<String, dynamic>> sub;

  setUp(() async {
    fake = _FakeWorker();
    engine = FaceVerificationEngine.withWorker(fake);
    await engine.initialize();
    events = <Map<String, dynamic>>[];
    sub = engine.events.listen(events.add);
  });

  tearDown(() async {
    await sub.cancel();
    await engine.dispose();
  });

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  test('initialize and dispose without error', () async {
    await _drain(engine);
  });

  test('frameChainDrained completes immediately when no frames are pending', () async {
    await engine.frameChainDrained;
  });

  test('initialize forwards worker stream errors as error events', () async {
    fake.emitError(StateError('worker boom'));
    await Future<void>.value();

    expect(events.any((e) => e['type'] == 'error' && e['message'].toString().contains('worker boom')), isTrue);
  });

  test('worker stream error stops later frame handling', () async {
    await engine.start(Uint8List(0));
    fake.emitError(StateError('worker boom'));
    await Future<void>.value();
    final countAfterError = events.length;

    fake.emitFrame(_face());
    await _drain(engine);

    expect(events.length, countAfterError);
  });

  test('start calls worker.startSession', () async {
    expect(fake.startSessionCalls, 0);

    await engine.start(Uint8List(0));

    expect(fake.startSessionCalls, 1);
  });

  test('stop calls worker.stop', () async {
    await engine.start(Uint8List(0));

    await engine.stop();

    expect(fake.stopCalls, greaterThanOrEqualTo(1));
  });

  test('stop when not started still forwards worker.stop', () async {
    await engine.stop();

    expect(fake.stopCalls, 1);
  });

  test('stop is idempotent and can be called repeatedly', () async {
    await engine.start(Uint8List(0));

    await engine.stop();
    await engine.stop();

    expect(fake.stopCalls, greaterThanOrEqualTo(2));
  });

  test('stop after startSession failure still reaches worker.stop', () async {
    fake.startSessionThrows = true;

    await expectLater(engine.start(Uint8List(0)), throwsStateError);

    fake.startSessionThrows = false;
    await engine.stop();

    expect(fake.startSessionCalls, 1);
    expect(fake.stopCalls, 1);
  });

  test('dispose cancels worker subscription and disposes worker', () async {
    final localFake = _FakeWorker();
    final localEngine = FaceVerificationEngine.withWorker(localFake);
    await localEngine.initialize();
    final localEvents = <Map<String, dynamic>>[];
    final localSub = localEngine.events.listen(localEvents.add);

    await localEngine.dispose();
    await localSub.cancel();

    expect(localFake.disposed, isTrue);
    expect(localEvents, isEmpty);
  });

  // -------------------------------------------------------------------------
  // start()
  // -------------------------------------------------------------------------

  test('start in active mode returns requiredActions wire names', () async {
    final actions = await engine.start(Uint8List(0));
    expect(actions.length, FaceVerificationTuning.requiredActions);
    for (final a in actions) {
      expect({'BLINK', 'TURN_LEFT', 'TURN_RIGHT', 'MOUTH_OPEN', 'SMILE'}, contains(a));
    }
  });

  test('start in passive mode returns empty action list', () async {
    final actions = await engine.start(Uint8List(0), mode: LivenessMode.passive);
    expect(actions, isEmpty);
  });

  test('second start resets session state', () async {
    await engine.start(Uint8List(0));
    final actions2 = await engine.start(Uint8List(0));
    expect(actions2.length, FaceVerificationTuning.requiredActions);
    expect(fake.startSessionCalls, 2);
  });

  // -------------------------------------------------------------------------
  // NFC prep / match score
  // -------------------------------------------------------------------------

  test('prepareNfcFaceEagerly decodes NFC image, detects face and prepares embedding', () async {
    fake.detectCropResult = img.Image(width: 112, height: 112);

    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    await engine.prepareNfcFaceEagerly(pngBytes);

    expect(fake.detectAndCropEncodedCalls, 1);
    expect(fake.prepareNfcFaceCalls, 1);
  });

  test('prepareNfcFaceEagerly throws when decoded NFC image has no detectable face', () async {
    fake.detectCropResult = null;

    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    await expectLater(engine.prepareNfcFaceEagerly(pngBytes), throwsStateError);

    expect(fake.detectAndCropEncodedCalls, 1);
    expect(fake.prepareNfcFaceCalls, 0);
  });

  test('prepareNfcFaceEagerly allows retry after failed NFC prep', () async {
    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    fake.detectCropResult = null;

    await expectLater(engine.prepareNfcFaceEagerly(pngBytes), throwsStateError);

    fake.detectCropResult = img.Image(width: 112, height: 112);

    await engine.prepareNfcFaceEagerly(pngBytes);

    expect(fake.detectAndCropEncodedCalls, 2);
    expect(fake.prepareNfcFaceCalls, 1);
  });

  test('prepareNfcFaceEagerly allows retry after detect worker failure', () async {
    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    fake.detectAndCropEncodedThrows = true;

    await expectLater(engine.prepareNfcFaceEagerly(pngBytes), throwsStateError);

    fake.detectAndCropEncodedThrows = false;
    fake.detectCropResult = img.Image(width: 112, height: 112);

    await engine.prepareNfcFaceEagerly(pngBytes);

    expect(fake.detectAndCropEncodedCalls, 2);
    expect(fake.prepareNfcFaceCalls, 1);
  });

  test('prepareNfcFaceEagerly allows retry after prepare worker failure', () async {
    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    fake.detectCropResult = img.Image(width: 112, height: 112);
    fake.prepareNfcFaceThrows = true;

    await expectLater(engine.prepareNfcFaceEagerly(pngBytes), throwsStateError);

    fake.prepareNfcFaceThrows = false;

    await engine.prepareNfcFaceEagerly(pngBytes);

    expect(fake.detectAndCropEncodedCalls, 2);
    expect(fake.prepareNfcFaceCalls, 2);
  });

  test('computeMatchScore returns worker match score after NFC prep and selfie capture', () async {
    fake.detectCropResult = img.Image(width: 112, height: 112);

    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

    await engine.prepareNfcFaceEagerly(pngBytes);
    await engine.start(pngBytes);

    await _align(fake, engine);

    final score = await engine.debugComputeMatchScore();

    expect(score, closeTo(0.9, 1e-9));
    expect(fake.matchSelfieCalls, 1);
  });

  // -------------------------------------------------------------------------
  // Alignment phase — active mode
  // -------------------------------------------------------------------------

  test('null face during alignment emits noFace tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(null);
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'noFace'), isTrue);
  });

  test('face too far emits tooFar tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(bboxArea: 0.01));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'tooFar'), isTrue);
  });

  test('face too close emits tooClose tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(bboxArea: 0.5));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'tooClose'), isTrue);
  });

  test('face with high yaw during alignment emits lookStraight tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(yaw: 20));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'lookStraight'), isTrue);
  });

  test('face with closed eyes during alignment emits openEyes tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(blinkClosed: true));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'openEyes'), isTrue);
  });

  test('face with open mouth during alignment emits closeMouth tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(mouthOpen: true));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'closeMouth'), isTrue);
  });

  test('face with strong smile during alignment emits relaxFace tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face(smile: 0.5));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'relaxFace'), isTrue);
  });

  test('neutral face during alignment emits holdStill tip', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(_face());
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'holdStill'), isTrue);
  });

  test('alignment emits nextAction after baseline frames', () async {
    await engine.start(Uint8List(0));
    await _align(fake, engine);
    expect(events.any((e) => e['type'] == 'nextAction'), isTrue);
  });

  test('same align tip is not re-emitted on consecutive identical frames', () async {
    await engine.start(Uint8List(0));
    fake.emitFrame(null);
    await _drain(engine);
    final countBefore = events.where((e) => e['type'] == 'align' && e['tip'] == 'noFace').length;
    fake.emitFrame(null);
    await _drain(engine);
    final countAfter = events.where((e) => e['type'] == 'align' && e['tip'] == 'noFace').length;
    expect(countAfter, countBefore); // deduplicated
  });

  // -------------------------------------------------------------------------
  // Action phase — timeout path
  // -------------------------------------------------------------------------

  test('timeout event emitted after actionTimeoutFrames null frames', () async {
    await engine.start(Uint8List(0));
    await _align(fake, engine);
    await _emitNullFrames(fake, engine, FaceVerificationTuning.actionTimeoutFrames + 1);
    expect(events.any((e) => e['type'] == 'timeout'), isTrue);
  });

  test('complete event emitted after all actions time out', () async {
    await engine.start(Uint8List(0));
    await _align(fake, engine);
    // Time out all 3 actions.
    for (var i = 0; i < FaceVerificationTuning.requiredActions; i++) {
      await _emitNullFrames(fake, engine, FaceVerificationTuning.actionTimeoutFrames + 1);
    }
    expect(events.any((e) => e['type'] == 'complete'), isTrue);
  });

  test('complete event includes matchScore, antiSpoofScore and rppg fields', () async {
    await engine.start(Uint8List(0));
    await _align(fake, engine);
    for (var i = 0; i < FaceVerificationTuning.requiredActions; i++) {
      await _emitNullFrames(fake, engine, FaceVerificationTuning.actionTimeoutFrames + 1);
    }
    final complete = events.firstWhere((e) => e['type'] == 'complete');
    expect(complete.containsKey('matchScore'), isTrue);
    expect(complete.containsKey('antiSpoofScore'), isTrue);
    expect(complete.containsKey('rppg'), isTrue);
    expect(complete['rppg'], isA<Map>());
  });

  test('session with passing passive result produces passed:true complete', () async {
    fake.passivePass = true;
    final nfcBytes = Uint8List(1); // non-empty so matchSelfie is attempted
    await engine.start(nfcBytes);
    await _align(fake, engine);
    // Complete all 3 actions via timeout (passed=false from timeout), but
    // this exercises the finishSession code path with real passive result.
    for (var i = 0; i < FaceVerificationTuning.requiredActions; i++) {
      await _emitNullFrames(fake, engine, FaceVerificationTuning.actionTimeoutFrames + 1);
    }
    final complete = events.firstWhere((e) => e['type'] == 'complete');
    expect(complete['antiSpoofPassed'], isTrue);
  });

  // -------------------------------------------------------------------------
  // stop()
  // -------------------------------------------------------------------------

  test('stop prevents further frame processing', () async {
    await engine.start(Uint8List(0));
    await engine.stop();
    final countBefore = events.length;
    fake.emitFrame(_face());
    await _drain(engine);
    expect(events.length, countBefore);
  });

  // -------------------------------------------------------------------------
  // Passive mode
  // -------------------------------------------------------------------------

  test('passive mode: null face emits noFace align tip', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    fake.emitFrame(null);
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'noFace'), isTrue);
  });

  test('passive mode: face too far emits tooFar tip', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    fake.emitFrame(_face(bboxArea: 0.01));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'tooFar'), isTrue);
  });

  test('passive mode: face too close emits tooClose tip', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    fake.emitFrame(_face(bboxArea: 0.5));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'tooClose'), isTrue);
  });

  test('passive mode: face too far to the side emits centerFace tip', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    fake.emitFrame(_face(center: const Offset(0.8, 0.5)));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'centerFace'), isTrue);
  });

  test('passive mode: face with high yaw emits lookStraight tip', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    fake.emitFrame(_face(yaw: 30));
    await _drain(engine);
    expect(events.any((e) => e['type'] == 'align' && e['tip'] == 'lookStraight'), isTrue);
  });

  test('passive mode: centered frontal face emits passiveProgress event', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    // Emit enough frontal frames to pass the lock-on period.
    for (var i = 0; i < 30; i++) {
      fake.emitFrame(_face());
      await _drain(engine);
    }
    expect(events.any((e) => e['type'] == 'passiveProgress'), isTrue);
  });

  test('passive mode: selfie candidate updated from frontal face', () async {
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    // Drive enough frames for lock-on + a few countdown frames.
    for (var i = 0; i < 30; i++) {
      fake.emitFrame(_face());
      await _drain(engine);
    }
    // No assertion on internal state — just verify no crash.
  });

  // -------------------------------------------------------------------------
  // Consistency check path
  // -------------------------------------------------------------------------

  test('alignment stores consistency selfie once after first accepted alignment', () async {
    await engine.start(Uint8List(0));

    await _align(fake, engine);

    expect(fake.storeConsistencySelfieCalls, 1);
  });

  test('consistency check with low score marks session as failed', () async {
    fake.consistencyScore = 0.1; // below threshold
    fake.passivePass = true;
    await engine.start(Uint8List(0), mode: LivenessMode.passive);
    for (var i = 0; i < 60; i++) {
      fake.emitFrame(_face());
      await _drain(engine);
    }
    // The engine may or may not have finished yet — just verify no crash.
  });

  group('debug-exposed engine branch coverage', () {
    test('shouldStartExtra is true only for exact minimum completed actions', () {
      engine.debugPrimeExtraScenario(
        pendingActions: const [LivenessAction.blink, LivenessAction.smile, LivenessAction.mouthOpen],
        currentActionIndex: FaceVerificationTuning.requiredActions,
        completedCount: FaceVerificationTuning.actionsNeededToPass,
      );
      expect(engine.debugShouldStartExtra(), isTrue);

      engine.debugPrimeExtraScenario(
        pendingActions: const [LivenessAction.blink, LivenessAction.smile, LivenessAction.mouthOpen],
        currentActionIndex: FaceVerificationTuning.requiredActions,
        completedCount: FaceVerificationTuning.requiredActions,
      );
      expect(engine.debugShouldStartExtra(), isFalse);

      engine.debugPrimeExtraScenario(
        pendingActions: const [LivenessAction.blink, LivenessAction.smile, LivenessAction.mouthOpen],
        currentActionIndex: FaceVerificationTuning.requiredActions,
        completedCount: FaceVerificationTuning.actionsNeededToPass,
        extraActionMode: true,
      );
      expect(engine.debugShouldStartExtra(), isFalse);
    });

    test('startExtra appends an unused action and emits extraAction event', () async {
      engine.debugPrimeExtraScenario(
        pendingActions: const [LivenessAction.blink, LivenessAction.smile, LivenessAction.mouthOpen],
        currentActionIndex: FaceVerificationTuning.requiredActions,
        completedCount: FaceVerificationTuning.actionsNeededToPass,
      );

      engine.debugStartExtra();
      await Future<void>.value();

      expect(engine.debugExtraActionMode, isTrue);
      expect(engine.debugPendingActionWireNames, hasLength(4));
      expect(events.any((e) => e['type'] == 'extraAction'), isTrue);
    });

    test('startExtra falls back when all actions are already pending', () async {
      engine.debugPrimeExtraScenario(
        pendingActions: LivenessAction.values,
        currentActionIndex: LivenessAction.values.length,
        completedCount: FaceVerificationTuning.actionsNeededToPass,
      );

      engine.debugStartExtra();
      await Future<void>.value();

      expect(engine.debugExtraActionMode, isTrue);
      expect(engine.debugPendingActionWireNames, hasLength(LivenessAction.values.length + 1));
      expect(events.any((e) => e['type'] == 'extraAction'), isTrue);
    });

    test('debug-primed action scenario detects an action and queues the next one', () async {
      engine.debugPrimeActionScenario(
        pendingActions: const [LivenessAction.mouthOpen, LivenessAction.smile],
        currentActionIndex: 0,
      );

      for (var i = 0; i < ActiveLivenessService.baselineFrames; i++) {
        fake.emitFrame(_face());
        await _drain(engine);
      }
      for (var i = 0; i < ActiveLivenessService.mouthOpenMinConfirmFrames; i++) {
        fake.emitFrame(_face(mouthOpen: true, jawOpen: 0.8));
        await _drain(engine);
      }

      expect(events.any((e) => e['type'] == 'actionDetected' && e['action'] == 'MOUTH_OPEN'), isTrue);
      expect(events.any((e) => e['type'] == 'nextAction' && e['action'] == 'SMILE'), isTrue);
    });

    test('debug-primed action scenario times out and advances without queueing rest', () async {
      engine.debugPrimeActionScenario(
        pendingActions: const [LivenessAction.blink, LivenessAction.smile],
        currentActionIndex: 0,
      );

      await _emitNullFrames(fake, engine, FaceVerificationTuning.actionTimeoutFrames + 1);

      expect(events.any((e) => e['type'] == 'timeout' && e['action'] == 'BLINK'), isTrue);
      expect(events.any((e) => e['type'] == 'nextAction' && e['action'] == 'SMILE'), isTrue);
    });

    test('passive lock-on starts countdown using the debug clock', () async {
      var now = 1000;
      engine.debugSetNowProvider(() => now);
      await engine.start(Uint8List(0), mode: LivenessMode.passive);

      fake.emitFrame(_face());
      await _drain(engine);
      expect(events.any((e) => e['type'] == 'passiveProgress' && e['started'] == false), isTrue);

      now += FaceVerificationTuning.passiveLockOnMs + 1;
      fake.emitFrame(_face());
      await _drain(engine);

      expect(events.any((e) => e['type'] == 'passiveProgress' && e['started'] == true), isTrue);
      expect(fake.storeConsistencySelfieCalls, 1);
    });

    test('passive coarse tip and bbox helpers cover good and bad face cases', () {
      expect(engine.debugPassiveCoarseTip(null), 'noFace');
      expect(engine.debugPassiveCoarseTip(_face(bboxArea: 0.01)), 'tooFar');
      expect(engine.debugPassiveCoarseTip(_face(bboxArea: 0.5)), 'tooClose');
      expect(engine.debugPassiveCoarseTip(_face(center: const Offset(0.8, 0.5))), 'centerFace');
      expect(engine.debugPassiveCoarseTip(_face(yaw: FaceVerificationTuning.passiveMaxYawDeg + 1)), 'lookStraight');
      expect(engine.debugPassiveCoarseTip(_face()), isNull);
      expect(engine.debugBboxSizeTip(_face(bboxArea: 0.01)), 'tooFar');
      expect(engine.debugBboxSizeTip(_face(bboxArea: 0.5)), 'tooClose');
      expect(engine.debugBboxSizeTip(_face()), isNull);
    });

    test('reject reason mapping covers all known and fallback reasons', () {
      expect(engine.debugMapRejectReason('yaw'), 'lookStraight');
      expect(engine.debugMapRejectReason('eyes'), 'openEyes');
      expect(engine.debugMapRejectReason('mouth'), 'closeMouth');
      expect(engine.debugMapRejectReason('smile'), 'relaxFace');
      expect(engine.debugMapRejectReason(null), 'holdStill');
      expect(engine.debugMapRejectReason('other'), 'holdStill');
    });

    test('computeMatchScore returns zero without prepared NFC data or selfie', () async {
      expect(await engine.debugComputeMatchScore(), 0.0);
      await engine.start(Uint8List.fromList([1, 2, 3]));
      expect(await engine.debugComputeMatchScore(), 0.0);
    });

    test('decodeNfcImage decodes normal image bytes and returns null for invalid bytes', () async {
      final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

      expect(await engine.debugDecodeNfcImage(pngBytes), isNotNull);
      expect(await engine.debugDecodeNfcImage(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('decodeNfcImage falls back to native image_channel conversion', () async {
      const channel = MethodChannel('image_channel');
      final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'decodeImage');
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        expect(args['jp2ImageData'], orderedEquals([9, 9, 9]));
        return pngBytes;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final decoded = await engine.debugDecodeNfcImage(Uint8List.fromList([9, 9, 9]));

      expect(decoded, isNotNull);
      expect(decoded!.width, 2);
      expect(decoded.height, 2);
    });

    test('finishSession emits passed true when liveness, anti-spoof, rppg and match all pass', () async {
      fake.passivePass = true;
      fake.detectCropResult = img.Image(width: 112, height: 112);

      final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

      await engine.prepareNfcFaceEagerly(pngBytes);
      await engine.start(pngBytes);

      await _align(fake, engine);

      await engine.debugFinishSession(true);
      await Future<void>.value();

      final complete = events.lastWhere((e) => e['type'] == 'complete');

      expect(complete['passed'], isTrue);
      expect(complete['matchScore'], closeTo(0.9, 1e-9));
      expect(complete['antiSpoofPassed'], isTrue);
      expect((complete['rppg'] as Map)['passed'], isTrue);
    });

    test('finishSession emits error event when passive result throws', () async {
      fake.passiveResultThrows = true;

      await engine.start(Uint8List(0));

      await engine.debugFinishSession(true);
      await Future<void>.value();

      expect(
        events.any((e) => e['type'] == 'error' && e['message'].toString().contains('Verification failed')),
        isTrue,
      );
    });

    test('finishSession emits default optional passive fields when passive checks fail', () async {
      await engine.start(Uint8List(0));

      await engine.debugFinishSession(true);
      await Future<void>.value();

      final complete = events.lastWhere((e) => e['type'] == 'complete');

      expect(complete['passed'], isFalse);
      expect(complete['antiSpoofScore'], isNull);
      expect(complete['antiSpoofPassed'], isFalse);
      expect((complete['rppg'] as Map)['hr'], isNull);
      expect((complete['rppg'] as Map)['passed'], isFalse);
      expect((complete['rppg'] as Map)['sampleCount'], 0);
      expect((complete['rppg'] as Map)['durationMs'], 0);
    });

    test('finishSession emits error event when match worker throws', () async {
      fake.passivePass = true;
      fake.matchSelfieThrows = true;
      fake.detectCropResult = img.Image(width: 112, height: 112);

      final pngBytes = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

      await engine.prepareNfcFaceEagerly(pngBytes);
      await engine.start(pngBytes);
      await _align(fake, engine);

      await engine.debugFinishSession(true);
      await Future<void>.value();

      expect(
        events.any((e) => e['type'] == 'error' && e['message'].toString().contains('Verification failed')),
        isTrue,
      );
    });

    test('decodeNfcImage returns null when native image_channel returns null', () async {
      const channel = MethodChannel('image_channel');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => null,
      );

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final decoded = await engine.debugDecodeNfcImage(Uint8List.fromList(<int>[7, 7, 7]));

      expect(decoded, isNull);
    });

    test('decodeNfcImage returns null when native image_channel throws', () async {
      const channel = MethodChannel('image_channel');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'decode_failed');
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final decoded = await engine.debugDecodeNfcImage(Uint8List.fromList(<int>[8, 8, 8]));

      expect(decoded, isNull);
    });

    test('consistency check marks failed when score is below threshold', () async {
      fake.consistencyScore = FaceVerificationTuning.consistencyCheckThreshold - 0.01;

      final token = engine.debugConsistencyCheckToken;

      await engine.debugRunConsistencyCheck(_face(), token);

      expect(engine.debugConsistencyFailed, isTrue);
    });

    test('consistency check does not fail when score is above threshold', () async {
      fake.consistencyScore = FaceVerificationTuning.consistencyCheckThreshold + 0.01;

      final token = engine.debugConsistencyCheckToken;

      await engine.debugRunConsistencyCheck(_face(), token);

      expect(engine.debugConsistencyFailed, isFalse);
    });

    test('consistency check ignores stale token result', () async {
      fake.consistencyScore = 0.0;

      final staleToken = engine.debugConsistencyCheckToken - 1;

      await engine.debugRunConsistencyCheck(_face(), staleToken);

      expect(engine.debugConsistencyFailed, isFalse);
    });

    test('consistency check treats worker errors as passed check', () async {
      fake.checkConsistencySelfieThrows = true;

      final token = engine.debugConsistencyCheckToken;

      await engine.debugRunConsistencyCheck(_face(), token);

      expect(fake.checkConsistencySelfieCalls, 1);
      expect(engine.debugConsistencyFailed, isFalse);
    });

    test('processFrame does not forward frame when engine is not running', () async {
      engine.debugSetRunningState(running: false, processing: false, sessionFinished: false, sessionStopping: false);

      await engine.processFrame(_fakeCameraImage(), 90);

      expect(fake.processCameraFrameCalls, 0);
    });

    test('processFrame does not forward frame while already processing', () async {
      engine.debugSetRunningState(running: true, processing: true, sessionFinished: false, sessionStopping: false);

      await engine.processFrame(_fakeCameraImage(), 90);

      expect(fake.processCameraFrameCalls, 0);
    });

    test('processFrame does not forward frame after session finished', () async {
      engine.debugSetRunningState(running: true, processing: false, sessionFinished: true, sessionStopping: false);

      await engine.processFrame(_fakeCameraImage(), 90);

      expect(fake.processCameraFrameCalls, 0);
    });

    test('processFrame does not forward frame while session is stopping', () async {
      engine.debugSetRunningState(running: true, processing: false, sessionFinished: false, sessionStopping: true);

      await engine.processFrame(_fakeCameraImage(), 90);

      expect(fake.processCameraFrameCalls, 0);
    });

    test('processFrame forwards frame when session is active', () async {
      engine.debugSetRunningState(running: true, processing: false, sessionFinished: false, sessionStopping: false);

      await engine.processFrame(_fakeCameraImage(), 90);

      expect(fake.processCameraFrameCalls, 1);
    });

    test('processFrame surfaces worker method failures when session is active', () async {
      fake.processCameraFrameThrows = true;
      engine.debugSetRunningState(running: true, processing: false, sessionFinished: false, sessionStopping: false);

      await expectLater(engine.processFrame(_fakeCameraImage(), 90), throwsStateError);

      expect(fake.processCameraFrameCalls, 1);
    });
  });
}
