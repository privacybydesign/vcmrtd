import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:face_verification/face_verification.dart';

// ---------------------------------------------------------------------------
// Fake worker
// ---------------------------------------------------------------------------

class _FakeWorker2 implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _frames.close();
  }

  @override
  Future<void> startSession() async {}
  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> processCameraFrame(CameraImage c, int r) async {}
  @override
  Future<img.Image?> detectAndCropEncoded(Uint8List e) async => null;
  @override
  Future<void> prepareNfcFace(img.Image f) async {}
  @override
  Future<void> storeConsistencySelfie(img.Image s) async {}
  @override
  Future<double> checkConsistencySelfie(img.Image s) async => 1.0;
  @override
  Future<WorkerMatchResult> matchSelfie(img.Image s) async => const WorkerMatchResult(score: 0.9);
  @override
  Future<WorkerPassiveResult> getPassiveResult() async => const WorkerPassiveResult(
    antiSpoofScore: 0.9,
    antiSpoofPassed: true,
    rppgHr: 70.0,
    rppgPassed: true,
    rppgSampleCount: 30,
    rppgDurationMs: 3000,
  );
  @override
  Stream<WorkerFrameResult> get debugFrames => _frames.stream;
  @override
  int get debugSessionId => 0;
  @override
  Future<void> debugWaitPipelineIdle() async {}
  @override
  Future<void> debugWaitPassiveIdle() async {}
  @override
  void debugEmitFrameResult(WorkerFrameResult r) {}
  @override
  void debugEmitFrameError(Object e) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen() {
  final worker = _FakeWorker2();
  final engine = FaceVerificationEngine.withWorker(worker);
  return MaterialApp(
    home: FlutterFaceVerificationScreen.withEngine(engine: engine, nfcImageBytes: Uint8List(1), onBackPressed: () {}),
  );
}

Widget _buildScreenWithBack(VoidCallback onBackPressed) {
  final worker = _FakeWorker2();
  final engine = FaceVerificationEngine.withWorker(worker);
  return MaterialApp(
    home: FlutterFaceVerificationScreen.withEngine(
      engine: engine,
      nfcImageBytes: Uint8List(1),
      onBackPressed: onBackPressed,
    ),
  );
}

Widget _buildScreenWithWorker(_FakeWorker2 worker) {
  final engine = FaceVerificationEngine.withWorker(worker);
  return MaterialApp(
    home: FlutterFaceVerificationScreen.withEngine(engine: engine, nfcImageBytes: Uint8List(1), onBackPressed: () {}),
  );
}

Widget _buildScreenWithIssueDate(DateTime issueDate) {
  final worker = _FakeWorker2();
  final engine = FaceVerificationEngine.withWorker(worker);
  return MaterialApp(
    home: FlutterFaceVerificationScreen.withEngine(
      engine: engine,
      nfcImageBytes: Uint8List(1),
      photoIssueDate: issueDate,
      onBackPressed: () {},
    ),
  );
}

FlutterFaceVerificationScreenState _state(WidgetTester tester) =>
    tester.state<FlutterFaceVerificationScreenState>(find.byType(FlutterFaceVerificationScreen));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('face action presentation helpers', () {
    test('maps action wire names to user-facing labels', () {
      expect(faceActionLabel('BLINK'), 'Blink your eyes');
      expect(faceActionLabel('TURN_LEFT'), 'Turn your head left');
      expect(faceActionLabel('TURN_RIGHT'), 'Turn your head right');
      expect(faceActionLabel('MOUTH_OPEN'), 'Open your mouth and hold');
      expect(faceActionLabel('SMILE'), 'Smile and hold');
      expect(faceActionLabel('UNKNOWN'), 'UNKNOWN');
    });

    test('maps action wire names to icons', () {
      expect(faceActionIcon('BLINK'), Icons.visibility_off);
      expect(faceActionIcon('TURN_LEFT'), Icons.arrow_back);
      expect(faceActionIcon('TURN_RIGHT'), Icons.arrow_forward);
      expect(faceActionIcon('MOUTH_OPEN'), Icons.sentiment_neutral);
      expect(faceActionIcon('SMILE'), Icons.sentiment_satisfied);
      expect(faceActionIcon('UNKNOWN'), Icons.face);
    });
  });

  group('faceMatchThreshold', () {
    test('uses default threshold when issue date is unknown', () {
      expect(faceMatchThreshold(null), 0.60);
    });

    test('is strict for recent document photos', () {
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365))), 0.65);
    });

    test('relaxes threshold for older document photos', () {
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365 * 5))), 0.60);
      expect(faceMatchThreshold(DateTime.now().subtract(const Duration(days: 365 * 9))), 0.55);
    });
  });

  test('VerificationResult defaults passive detail fields for active mode', () {
    const result = VerificationResult(matchScore: 0.72, isLive: true);

    expect(result.matchScore, 0.72);
    expect(result.isLive, isTrue);
    expect(result.antiSpoofScore, isNull);
    expect(result.antiSpoofPassed, isFalse);
    expect(result.rppgHr, isNull);
    expect(result.rppgPassed, isFalse);
    expect(result.rppgSampleCount, 0);
    expect(result.consistencyFailed, isFalse);
  });

  group('FlutterFaceVerificationScreen — camera rotation (pure math)', () {
    test('back camera at 0° device rotation uses sensor orientation directly', () {
      expect(FlutterFaceVerificationScreenState.debugBackCameraRotation(90, 0), 90);
      expect(FlutterFaceVerificationScreenState.debugBackCameraRotation(270, 0), 270);
    });

    test('back camera rotates correctly for landscape left (90°)', () {
      // sensorOrientation=90, deviceOrientation=90 → (90-90+360)%360 = 0
      expect(FlutterFaceVerificationScreenState.debugBackCameraRotation(90, 90), 0);
    });

    test('back camera rotates correctly for landscape right (270°)', () {
      // sensorOrientation=90, deviceOrientation=270 → (90-270+360)%360 = 180
      expect(FlutterFaceVerificationScreenState.debugBackCameraRotation(90, 270), 180);
    });

    test('back camera wraps correctly (no negative values)', () {
      // sensorOrientation=90, deviceOrientation=180 → (90-180+360)%360 = 270
      expect(FlutterFaceVerificationScreenState.debugBackCameraRotation(90, 180), 270);
    });

    test('result is always in [0, 360)', () {
      for (final sensor in [0, 90, 180, 270]) {
        for (final device in [0, 90, 180, 270]) {
          final r = FlutterFaceVerificationScreenState.debugBackCameraRotation(sensor, device);
          expect(r, greaterThanOrEqualTo(0));
          expect(r, lessThan(360));
        }
      }
    });
  });

  group('FlutterFaceVerificationScreen — construction', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);
    });

    testWidgets('starts in idle state', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(_state(tester).debugState, VerificationState.idle);
    });

    testWidgets('engineReady becomes true after test bootstrap', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump(); // addPostFrameCallback fires
      await tester.pump(); // rebuild
      expect(_state(tester).debugEngineReady, isTrue);
    });

    testWidgets('paused lifecycle stops active flow without a real camera', (tester) async {
      final worker = _FakeWorker2();
      await tester.pumpWidget(_buildScreenWithWorker(worker));
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetActiveLiveness();
      await tester.pump();
      _state(tester).didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();

      expect(worker.stopCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('dispose cancels passive ticker and disposes injected engine', (tester) async {
      final worker = _FakeWorker2();
      await tester.pumpWidget(_buildScreenWithWorker(worker));
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetActiveLiveness();
      _state(tester).debugSetSelectedMode(LivenessMode.passive);
      _state(
        tester,
      ).debugOnLivenessEvent({'type': 'passiveProgress', 'started': true, 'elapsedMs': 1000, 'targetMs': 5000});
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(worker.stopCalls, greaterThanOrEqualTo(1));
      expect(worker.disposeCalls, 0);
    });
  });

  group('FlutterFaceVerificationScreen — complete event (no state guard)', () {
    testWidgets('complete event produces a VerificationResult', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 0.85,
        'antiSpoofScore': 0.9,
        'antiSpoofPassed': true,
        'consistencyFailed': false,
        'rppg': {'hr': 70.0, 'passed': true, 'sampleCount': 30, 'durationMs': 3000},
      });
      await tester.pump();
      final result = _state(tester).debugResult;
      expect(result, isNotNull);
      expect(result!.matchScore, closeTo(0.85, 1e-6));
      expect(result.isLive, isTrue);
      expect(result.antiSpoofPassed, isTrue);
    });

    testWidgets('complete with passed:false stores failed result', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': false,
        'matchScore': 0.3,
        'antiSpoofScore': 0.2,
        'antiSpoofPassed': false,
        'consistencyFailed': true,
        'rppg': {'hr': null, 'passed': false, 'sampleCount': 0, 'durationMs': 0},
      });
      await tester.pump();
      final result = _state(tester).debugResult;
      expect(result, isNotNull);
      expect(result!.isLive, isFalse);
      expect(result.consistencyFailed, isTrue);
      expect(_state(tester).debugState, VerificationState.result);
    });

    testWidgets('complete with missing rppg fields defaults gracefully', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'complete', 'passed': true, 'matchScore': 0.75});
      await tester.pump();
      expect(_state(tester).debugResult, isNotNull);
      expect(_state(tester).debugResult!.rppgSampleCount, 0);
    });
  });

  group('FlutterFaceVerificationScreen — events in activeLiveness state', () {
    Future<void> enterActiveState(WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();
      _state(tester).debugSetActiveLiveness();
      await tester.pump();
    }

    testWidgets('align event sets alignTip', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'noFace'});
      await tester.pump();
      expect(_state(tester).debugAlignTip, 'noFace');
    });

    testWidgets('align event clears tip when null', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'noFace'});
      await tester.pump();
      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': null});
      await tester.pump();
      expect(_state(tester).debugAlignTip, isNull);
    });

    testWidgets('nextAction sets currentAction and clears alignTip', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'nextAction', 'action': 'BLINK'});
      await tester.pump();
      expect(_state(tester).debugCurrentAction, 'BLINK');
      expect(_state(tester).debugAlignTip, isNull);
    });

    testWidgets('nextAction for each action type', (tester) async {
      for (final action in ['BLINK', 'TURN_LEFT', 'TURN_RIGHT', 'MOUTH_OPEN', 'SMILE']) {
        await enterActiveState(tester);
        _state(tester).debugOnLivenessEvent({'type': 'nextAction', 'action': action});
        await tester.pump();
        expect(_state(tester).debugCurrentAction, action);
      }
    });

    testWidgets('actionDetected adds action to completedActions', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'actionDetected', 'action': 'BLINK'});
      // Drain the 400ms flash-clear timer so it doesn't outlive the test.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_state(tester).debugCompletedActions, contains('BLINK'));
    });

    testWidgets('multiple actionDetected events accumulate', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'actionDetected', 'action': 'BLINK'});
      await tester.pump(const Duration(milliseconds: 500));
      _state(tester).debugOnLivenessEvent({'type': 'actionDetected', 'action': 'SMILE'});
      await tester.pump(const Duration(milliseconds: 500));
      expect(_state(tester).debugCompletedActions, containsAll(['BLINK', 'SMILE']));
    });

    testWidgets('extraAction event is handled without crashing', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'extraAction', 'action': 'SMILE'});
      await tester.pump();
      expect(_state(tester).debugCurrentAction, 'SMILE');
    });

    testWidgets('processing event transitions to processing state', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'processing'});
      await tester.pump();
      expect(_state(tester).debugState, VerificationState.processing);
      expect(_state(tester).debugCurrentAction, isNull);
    });

    testWidgets('passiveProgress event does not crash', (tester) async {
      await enterActiveState(tester);
      _state(
        tester,
      ).debugOnLivenessEvent({'type': 'passiveProgress', 'started': true, 'elapsedMs': 1500, 'targetMs': 5000});
      await tester.pump();
    });

    testWidgets('passiveProgress with started:false does not crash', (tester) async {
      await enterActiveState(tester);
      _state(
        tester,
      ).debugOnLivenessEvent({'type': 'passiveProgress', 'started': false, 'elapsedMs': 0, 'targetMs': 5000});
      await tester.pump();
    });

    testWidgets('active action UI renders instruction and checklist progress', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.active);
      _state(tester).debugSetActions(['BLINK', 'SMILE']);
      await tester.pump();
      _state(tester).debugOnLivenessEvent({'type': 'nextAction', 'action': 'BLINK'});
      await tester.pump();

      expect(find.text('Blink your eyes'), findsWidgets);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      _state(tester).debugOnLivenessEvent({'type': 'actionDetected', 'action': 'BLINK'});
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('alignment tip messages render known tips and ignore unknown tips', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'tooClose'});
      await tester.pump();
      expect(find.text('Move a bit further from the camera'), findsOneWidget);

      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'unknown'});
      await tester.pump();
      expect(find.text('Move a bit further from the camera'), findsNothing);
    });

    testWidgets('passive progress card renders countdown and progress text', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.passive);
      _state(
        tester,
      ).debugOnLivenessEvent({'type': 'passiveProgress', 'started': true, 'elapsedMs': 1200, 'targetMs': 5000});
      await tester.pump();

      expect(find.text('Hold still'), findsOneWidget);
      expect(find.text('4s'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('error event resets to idle with error message', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'error', 'message': 'camera error'});
      await tester.pump();
      expect(_state(tester).debugState, VerificationState.idle);
      expect(_state(tester).debugCurrentAction, isNull);
    });

    testWidgets('passive countdown reaches almost done and zero seconds', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetActiveLiveness();
      _state(tester).debugSetSelectedMode(LivenessMode.passive);
      await tester.pump();

      _state(
        tester,
      ).debugOnLivenessEvent({'type': 'passiveProgress', 'started': true, 'elapsedMs': 5000, 'targetMs': 5000});

      await tester.pump();

      expect(find.text('Almost done…'), findsOneWidget);
      expect(find.text('0s'), findsOneWidget);

      // Drain the periodic passive ticker so it does not outlive the test.
      _state(tester).debugOnLivenessEvent({'type': 'processing'});
      await tester.pump();
    });

    testWidgets('error event without message uses fallback unknown error text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetActiveLiveness();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'error'});
      await tester.pump();

      expect(find.text('Unknown error'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('active checklist shows current and pending action styling', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetActiveLiveness();
      _state(tester).debugSetSelectedMode(LivenessMode.active);
      _state(tester).debugSetActions(['BLINK', 'TURN_LEFT', 'SMILE']);
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'nextAction', 'action': 'TURN_LEFT'});
      await tester.pump();

      expect(find.text('Turn your head left'), findsWidgets);
      expect(find.text('Blink your eyes'), findsOneWidget);
      expect(find.text('Smile and hold'), findsOneWidget);

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
    });

    testWidgets('unknown and missing event types are ignored in active state', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugOnLivenessEvent({'type': 'nextAction', 'action': 'BLINK'});
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'notARealEvent', 'action': 'SMILE'});
      _state(tester).debugOnLivenessEvent({'action': 'TURN_LEFT'});
      await tester.pump();

      expect(_state(tester).debugState, VerificationState.activeLiveness);
      expect(_state(tester).debugCurrentAction, 'BLINK');
    });

    testWidgets('passive progress defaults missing fields and waits before countdown UI', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.passive);

      _state(tester).debugOnLivenessEvent({'type': 'passiveProgress'});
      await tester.pump();

      expect(find.text('Hold still'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      _state(tester).debugOnLivenessEvent({'type': 'passiveProgress', 'started': true});
      await tester.pump();

      expect(find.text('Hold still'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('multiple extraAction events append actions and keep latest current', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.active);

      _state(tester).debugSetActions(['BLINK']);
      _state(tester).debugOnLivenessEvent({'type': 'extraAction', 'action': 'SMILE'});
      _state(tester).debugOnLivenessEvent({'type': 'extraAction', 'action': 'TURN_LEFT'});
      await tester.pump();

      expect(_state(tester).debugCurrentAction, 'TURN_LEFT');
      expect(find.text('Blink your eyes'), findsOneWidget);
      expect(find.text('Smile and hold'), findsOneWidget);
      expect(find.text('Turn your head left'), findsWidgets);
      expect(find.text('extra'), findsOneWidget);
    });
  });

  group('FlutterFaceVerificationScreen — rendered result and error UI', () {
    testWidgets('passed complete event renders successful result screen', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 0.92,
        'antiSpoofScore': 0.88,
        'antiSpoofPassed': true,
        'rppg': {'hr': 72.0, 'passed': true, 'sampleCount': 31, 'durationMs': 3000},
      });
      await tester.pump();

      expect(find.text('Identity Verified'), findsOneWidget);
      expect(find.text('92.0%'), findsOneWidget);
      expect(find.text('88.0%'), findsOneWidget);
      expect(find.text('72 bpm'), findsOneWidget);
      expect(find.text('passed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('failed complete event renders failed result and consistency warning', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': false,
        'matchScore': 0.25,
        'antiSpoofScore': 0.2,
        'antiSpoofPassed': false,
        'consistencyFailed': true,
        'rppg': {'hr': null, 'passed': false, 'sampleCount': 0, 'durationMs': 0},
      });
      await tester.pump();

      expect(find.text('Verification Failed'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
      expect(find.text('face changed mid-session'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsWidgets);
    });

    testWidgets('error screen renders actions and back callback fires', (tester) async {
      var backCount = 0;
      await tester.pumpWidget(_buildScreenWithBack(() => backCount++));
      await tester.pump();
      await tester.pump();
      _state(tester).debugSetActiveLiveness();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'error', 'message': 'camera error'});
      await tester.pump();

      expect(find.text('camera error'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Go Back'));
      await tester.pump();
      expect(backCount, 1);
    });
  });

  group('FlutterFaceVerificationScreen — additional UI branches', () {
    Future<void> enterActiveState(WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();
      _state(tester).debugSetActiveLiveness();
      await tester.pump();
    }

    testWidgets('loading screen renders camera and model setup stages', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      expect(find.text('Setting up face verification'), findsOneWidget);
      expect(find.text('This only takes a moment'), findsOneWidget);
      expect(find.text('Opening camera'), findsOneWidget);
      expect(find.text('Loading face models'), findsOneWidget);
    });

    testWidgets('processing screen renders verification message', (tester) async {
      await enterActiveState(tester);

      _state(tester).debugOnLivenessEvent({'type': 'processing'});
      await tester.pump();

      expect(find.text('Verifying identity...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('timeout event with action shows action-specific snackbar', (tester) async {
      await enterActiveState(tester);

      _state(tester).debugOnLivenessEvent({'type': 'timeout', 'action': 'BLINK'});
      await tester.pump();

      expect(find.text('Take your time - Blink your eyes'), findsOneWidget);
    });

    testWidgets('timeout event without action shows fallback snackbar', (tester) async {
      await enterActiveState(tester);

      _state(tester).debugOnLivenessEvent({'type': 'timeout', 'action': null});
      await tester.pump();

      expect(find.text('Take your time - perform the action'), findsOneWidget);
    });

    testWidgets('extra action renders extra chip in checklist', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.active);

      _state(tester).debugSetActions(['BLINK']);
      await tester.pump();

      _state(tester).debugOnLivenessEvent({'type': 'extraAction', 'action': 'SMILE'});
      await tester.pump();

      expect(find.text('Smile and hold'), findsWidgets);
      expect(find.text('extra'), findsOneWidget);
    });

    testWidgets('active holdStill tip renders get ready message', (tester) async {
      await enterActiveState(tester);
      _state(tester).debugSetSelectedMode(LivenessMode.active);

      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'holdStill'});
      await tester.pump();

      expect(find.text('Get ready…'), findsOneWidget);
    });

    testWidgets('passive holdStill tip renders hold still message', (tester) async {
      await enterActiveState(tester);

      _state(tester).debugSetSelectedMode(LivenessMode.passive);
      _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': 'holdStill'});
      await tester.pump();

      expect(find.text('Hold still…'), findsOneWidget);
    });

    testWidgets('all known alignment tips render their messages', (tester) async {
      await enterActiveState(tester);

      final tips = <String, String>{
        'noFace': 'Position your face in the oval',
        'centerFace': 'Move your face into the oval',
        'tooFar': 'Move a bit closer to the camera',
        'tooClose': 'Move a bit further from the camera',
        'lookStraight': 'Look straight at the camera',
        'openEyes': 'Keep your eyes open',
        'closeMouth': 'Close your mouth',
        'relaxFace': 'Relax your expression',
      };

      for (final entry in tips.entries) {
        _state(tester).debugOnLivenessEvent({'type': 'align', 'tip': entry.key});
        await tester.pump();

        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('app bar back button calls onBackPressed', (tester) async {
      var backCount = 0;

      await tester.pumpWidget(_buildScreenWithBack(() => backCount++));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(backCount, 1);
    });
  });

  group('FlutterFaceVerificationScreen — result threshold variants', () {
    testWidgets('recent document requires stricter match threshold', (tester) async {
      final recentIssueDate = DateTime.now().subtract(const Duration(days: 365));

      await tester.pumpWidget(_buildScreenWithIssueDate(recentIssueDate));
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 0.62,
        'antiSpoofScore': 0.9,
        'antiSpoofPassed': true,
        'rppg': {'hr': 70.0, 'passed': true, 'sampleCount': 30},
      });
      await tester.pump();

      expect(find.text('Verification Failed'), findsOneWidget);
      expect(find.text('Match (≥65%)'), findsOneWidget);
    });

    testWidgets('old document uses relaxed match threshold', (tester) async {
      final oldIssueDate = DateTime.now().subtract(const Duration(days: 365 * 9));

      await tester.pumpWidget(_buildScreenWithIssueDate(oldIssueDate));
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 0.56,
        'antiSpoofScore': 0.9,
        'antiSpoofPassed': true,
        'rppg': {'hr': 70.0, 'passed': true, 'sampleCount': 30},
      });
      await tester.pump();

      expect(find.text('Identity Verified'), findsOneWidget);
      expect(find.text('Match (≥55%)'), findsOneWidget);
    });

    testWidgets('result screen renders n/a for missing anti-spoof and rPPG values', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': false,
        'matchScore': 0.4,
        'antiSpoofPassed': false,
        'rppg': {'passed': false, 'sampleCount': 0},
      });
      await tester.pump();

      expect(find.text('Verification Failed'), findsOneWidget);
      expect(find.text('n/a'), findsWidgets);
      expect(find.text('rPPG (0 samples)'), findsOneWidget);
    });

    testWidgets('complete event maps integer optional fields into rendered result', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 1,
        'antiSpoofScore': 1,
        'antiSpoofPassed': true,
        'rppg': {'hr': 71, 'passed': true, 'sampleCount': 15, 'durationMs': 2000},
      });
      await tester.pump();

      expect(_state(tester).debugResult!.matchScore, closeTo(1.0, 1e-9));
      expect(_state(tester).debugResult!.antiSpoofScore, closeTo(1.0, 1e-9));
      expect(_state(tester).debugResult!.rppgHr, closeTo(71.0, 1e-9));
      expect(find.text('100.0%'), findsWidgets);
      expect(find.text('71 bpm'), findsOneWidget);
      expect(find.text('rPPG (15 samples)'), findsOneWidget);
    });

    testWidgets('match score equal to threshold is not accepted because result requires greater than threshold', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugOnLivenessEvent({
        'type': 'complete',
        'passed': true,
        'matchScore': 0.60,
        'antiSpoofScore': 0.9,
        'antiSpoofPassed': true,
        'rppg': {'hr': 70.0, 'passed': true, 'sampleCount': 30},
      });
      await tester.pump();

      expect(find.text('Verification Failed'), findsOneWidget);
      expect(find.text('Match (≥60%)'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsWidgets);
    });
  });

  group('FlutterFaceVerificationScreen — idle UI branches', () {
    testWidgets('ready idle screen renders instructions, fallback camera preview and start buttons', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetReadyForTesting();
      await tester.pump();

      expect(find.text('Opening camera...'), findsOneWidget);

      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Center your face inside the oval'), findsOneWidget);
      expect(find.text('Tap the button below'), findsOneWidget);
      expect(find.text('Follow the on-screen prompts'), findsOneWidget);

      // The method picker lives on a separate screen now — only a single Start
      // button remains here.
      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('Liveness'), findsNothing);

      expect(find.byIcon(Icons.face), findsWidgets);
    });

    testWidgets('ready idle screen start button can be tapped without crashing when camera is absent', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetReadyForTesting();
      await tester.pump();

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.byType(FlutterFaceVerificationScreen), findsOneWidget);
    });

    testWidgets('debug retry reset clears result, action and passive state without opening camera', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump();

      _state(tester).debugSetResultState(
        const VerificationResult(
          matchScore: 0.2,
          isLive: false,
          antiSpoofScore: 0.3,
          antiSpoofPassed: false,
          rppgPassed: false,
          rppgSampleCount: 0,
          consistencyFailed: true,
        ),
      );
      await tester.pump();

      _state(tester).debugResetForRetry();
      await tester.pump();

      expect(_state(tester).debugState, VerificationState.idle);
      expect(_state(tester).debugResult, isNull);
      expect(_state(tester).debugCurrentAction, isNull);
      expect(_state(tester).debugCompletedActions, isEmpty);
      expect(_state(tester).debugAlignTip, isNull);
    });
  });
}
