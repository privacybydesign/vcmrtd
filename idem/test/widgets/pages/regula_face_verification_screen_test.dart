import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/regula_face_service.dart';
import 'package:idem/widgets/common/face_verification_views.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/regula_face_verification_screen.dart';
import 'package:mrz_capture/mrz_capture.dart' show StepBadge;

class _FakeRegula implements RegulaFaceService {
  _FakeRegula(this.results);

  /// Each call pops the next result; an Exception is thrown instead.
  final List<Object> results;
  String? lastTag;
  String? lastServiceUrl;

  @override
  Future<void> initialize() async {}

  @override
  Future<RegulaLivenessResult> captureLiveness({String? tag, String? serviceUrl}) async {
    lastTag = tag;
    lastServiceUrl = serviceUrl;
    final next = results.removeAt(0);
    if (next is Exception) throw next;
    return next as RegulaLivenessResult;
  }
}

const _announcement = ProofingFaceVerification(
  provider: 'regula',
  faceApiUrl: 'https://faceapi.test',
  tag: 'ips-tref_s1',
  fromSession: true,
);

Future<List<FaceVerificationOutcome>> _pump(WidgetTester tester, _FakeRegula regula) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final verified = <FaceVerificationOutcome>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [regulaFaceServiceProvider.overrideWithValue(regula)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegulaFaceVerificationScreen(
          faceVerification: _announcement,
          onBackPressed: () {},
          onVerified: verified.add,
        ),
      ),
    ),
  );
  return verified;
}

void main() {
  testWidgets('a live result continues with the transaction id, bound to the session tag', (tester) async {
    final regula = _FakeRegula([const RegulaLivenessResult(isLive: true, transactionId: 'tx-1')]);
    final verified = await _pump(tester, regula);

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();
    expect(find.text('Continuing…'), findsOneWidget);
    expect(regula.lastTag, 'ips-tref_s1');
    expect(regula.lastServiceUrl, 'https://faceapi.test');
    expect(verified.single.engine, 'regula');
    expect(verified.single.livenessTransactionId, 'tx-1');
    expect(verified.single.selfieImageBytes, isNull);
  });

  testWidgets('a non-live result offers a retry instead of continuing', (tester) async {
    final regula = _FakeRegula([
      const RegulaLivenessResult(isLive: false, transactionId: 'tx-1'),
      const RegulaLivenessResult(isLive: true, transactionId: 'tx-2'),
    ]);
    final verified = await _pump(tester, regula);

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();
    expect(find.text('Verification Failed'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(verified.single.livenessTransactionId, 'tx-2');
  });

  testWidgets('the result and busy views after the intro keep the guided layout', (tester) async {
    final regula = _FakeRegula([
      const RegulaLivenessResult(isLive: false, transactionId: 'tx-1'),
      const RegulaLivenessResult(isLive: true, transactionId: 'tx-2'),
    ]);
    await _pump(tester, regula);

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();
    expect(find.descendant(of: find.byType(FaceStepScaffold), matching: find.byType(FaceResultView)), findsOneWidget);
    expect(find.byType(GuidedStepBar), findsOneWidget);
    expect(find.byType(StepBadge), findsNothing);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(find.descendant(of: find.byType(FaceStepScaffold), matching: find.byType(FaceBusyView)), findsOneWidget);
    expect(find.byType(GuidedStepBar), findsOneWidget);
    expect(find.byType(StepBadge), findsNothing);
  });

  testWidgets('cancelling shows the cancelled state', (tester) async {
    final verified = await _pump(tester, _FakeRegula([const RegulaLivenessCancelled()]));

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(verified, isEmpty);
  });

  testWidgets('opens on the selfie intro, whose button starts the scan', (tester) async {
    final regula = _FakeRegula([const RegulaLivenessResult(isLive: true, transactionId: 'tx-1')]);
    final verified = await _pump(tester, regula);

    expect(find.text('Take a quick selfie'), findsOneWidget);

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();
    expect(verified.single.livenessTransactionId, 'tx-1');
  });

  testWidgets('a capture that fails retries right here', (tester) async {
    final regula = _FakeRegula([
      Exception('camera unavailable'),
      const RegulaLivenessResult(isLive: true, transactionId: 'tx-2'),
    ]);
    final verified = await _pump(tester, regula);

    await tester.tap(find.text('Start selfie check'));
    await tester.pump();
    expect(find.text('Something Went Wrong'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(verified.single.livenessTransactionId, 'tx-2');
  });
}
