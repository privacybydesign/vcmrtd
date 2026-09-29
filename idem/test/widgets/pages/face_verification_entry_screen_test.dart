import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:face_verification/face_verification.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/face_verification_entry_screen.dart';
import 'package:idem/widgets/pages/face_verification_screen.dart';
import 'package:idem/widgets/pages/iris_face_verification_screen.dart';
import 'package:idem/widgets/pages/regula_face_verification_screen.dart';

class _FakeWorker implements FaceVerificationWorker {
  final StreamController<WorkerFrameResult> _frames = StreamController<WorkerFrameResult>.broadcast(sync: true);

  @override
  Stream<WorkerFrameResult> get frames => _frames.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async => _frames.close();
  @override
  Future<void> startSession() async {}
  @override
  Future<void> stop() async {}
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

void main() {
  testWidgets('onDevice choice opens the camera screen directly, in the given liveness mode', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FaceVerificationEntryScreen(
          testEngine: engine,
          nfcImageBytes: Uint8List.fromList([1]),
          onBackPressed: () {},
          onVerified: (_) {},
          engineChoice: FaceEngineChoice.onDevice,
          livenessMode: LivenessMode.active,
          photoIssueDate: DateTime(2024, 1, 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(IrisFaceVerificationScreen), findsNothing);
    final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
    expect(screen.mode, LivenessMode.active);
    expect(screen.photoIssueDate, DateTime(2024, 1, 1));
    expect(screen.nfcImageBytes, Uint8List.fromList([1]));
  });

  testWidgets('onDevice choice defaults to passive when that is the configured liveness mode', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FaceVerificationEntryScreen(
          testEngine: engine,
          nfcImageBytes: Uint8List(1),
          onBackPressed: () {},
          onVerified: (_) {},
          engineChoice: FaceEngineChoice.onDevice,
          livenessMode: LivenessMode.passive,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final screen = tester.widget<FlutterFaceVerificationScreen>(find.byType(FlutterFaceVerificationScreen));
    expect(screen.mode, LivenessMode.passive);
  });

  testWidgets('iris choice opens the Iris screen directly, not the on-device camera', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FaceVerificationEntryScreen(
          testEngine: engine,
          nfcImageBytes: Uint8List(1),
          onBackPressed: () {},
          onVerified: (_) {},
          engineChoice: FaceEngineChoice.iris,
          livenessMode: LivenessMode.passive,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(IrisFaceVerificationScreen), findsOneWidget);
    expect(find.byType(FlutterFaceVerificationScreen), findsNothing);
  });

  const regula = ProofingFaceVerification(provider: 'regula', faceApiUrl: 'https://faceapi.test', fromSession: true);

  test('Regula follows the session\'s flow, else the setting when a server offers it', () {
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.regula, regula), FaceEngineChoice.regula);
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.regula, null), FaceEngineChoice.onDevice);
    // A session's flow chose Regula: the setting can't override it.
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.iris, regula), FaceEngineChoice.regula);
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.onDevice, regula), FaceEngineChoice.regula);
    // The passport issuer's offer leaves the choice to the user.
    const issuer = ProofingFaceVerification(provider: 'regula', faceApiUrl: 'https://faceapi.test');
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.iris, issuer), FaceEngineChoice.iris);
    expect(FaceVerificationEntryScreen.effectiveEngine(FaceEngineChoice.regula, issuer), FaceEngineChoice.regula);
  });

  testWidgets('regula choice with an announcing session opens the Regula screen', (tester) async {
    final engine = FaceVerificationEngine.withWorker(_FakeWorker());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FaceVerificationEntryScreen(
            testEngine: engine,
            nfcImageBytes: Uint8List(1),
            onBackPressed: () {},
            onVerified: (_) {},
            engineChoice: FaceEngineChoice.regula,
            livenessMode: LivenessMode.passive,
            faceVerification: regula,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RegulaFaceVerificationScreen), findsOneWidget);
    expect(find.byType(FlutterFaceVerificationScreen), findsNothing);
  });
}
