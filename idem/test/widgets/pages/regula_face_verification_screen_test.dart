import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/regula_face_service.dart';
import 'package:idem/widgets/pages/regula_face_verification_screen.dart';
import 'package:vcmrtd/vcmrtd.dart' show FaceMatch;

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
const _issuerAnnouncement = ProofingFaceVerification(provider: 'regula', faceApiUrl: 'https://faceapi.test');

Future<List<FaceVerificationOutcome>> _pump(
  WidgetTester tester,
  _FakeRegula regula, {
  Future<FaceMatch?> Function(String)? matchFace,
  VoidCallback? onBack,
}) async {
  final verified = <FaceVerificationOutcome>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [regulaFaceServiceProvider.overrideWithValue(regula)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegulaFaceVerificationScreen(
          faceVerification: matchFace == null ? _announcement : _issuerAnnouncement,
          onBackPressed: onBack ?? () {},
          onVerified: verified.add,
          matchFace: matchFace,
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

    await tester.tap(find.text('Start Verification'));
    await tester.pump();
    expect(find.text('Liveness Confirmed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
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

    await tester.tap(find.text('Start Verification'));
    await tester.pump();
    expect(find.text('Verification Failed'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(verified.single.livenessTransactionId, 'tx-2');
  });

  testWidgets('cancelling shows the cancelled state', (tester) async {
    final verified = await _pump(tester, _FakeRegula([const RegulaLivenessCancelled()]));

    await tester.tap(find.text('Start Verification'));
    await tester.pump();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(verified, isEmpty);
  });

  group('standalone (passport issuer matches)', () {
    testWidgets('a match continues with the issuer\'s score, not a transaction id', (tester) async {
      final asked = <String>[];
      final regula = _FakeRegula([const RegulaLivenessResult(isLive: true, transactionId: 'tx-1')]);
      final verified = await _pump(
        tester,
        regula,
        matchFace: (tx) async {
          asked.add(tx);
          return FaceMatch(matched: true, similarity: 0.91);
        },
      );

      await tester.tap(find.text('Start Verification'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Identity Verified'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(asked, ['tx-1']);
      expect(regula.lastTag, isNull);
      expect(verified.single.matchScore, 0.91);
      expect(verified.single.livenessTransactionId, isNull);
    });

    testWidgets('no match sends the user back to scan again, since the issuer session is used up', (tester) async {
      var backs = 0;
      final verified = await _pump(
        tester,
        _FakeRegula([const RegulaLivenessResult(isLive: true, transactionId: 'tx-1')]),
        matchFace: (_) async => FaceMatch(matched: false, similarity: 0.4),
        onBack: () => backs++,
      );

      await tester.tap(find.text('Start Verification'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Verification Failed'), findsOneWidget);

      await tester.tap(find.text('Scan document again'));
      expect(backs, 1);
      expect(verified, isEmpty);
    });
  });
}
