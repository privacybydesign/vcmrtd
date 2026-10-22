import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/proofing_session_consent_screen.dart';

ProofingSessionInfo _info({
  List<String> requestedAttributes = const [],
  int? ageOver,
  Duration expiresIn = const Duration(minutes: 10),
}) {
  return ProofingSessionInfo(
    id: 'sess1',
    relyingParty: 'acme-tenant',
    requestedAttributes: requestedAttributes,
    ageOver: ageOver,
    expiresAt: DateTime.now().add(expiresIn),
  );
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  group('ProofingSessionConsentScreen', () {
    testWidgets('shows the relying party name and a catch-all label when nothing was restricted', (tester) async {
      await tester.pumpWidget(_app(ProofingSessionConsentScreen(info: _info(), onConsent: () {}, onDecline: () {})));

      expect(find.text('acme-tenant wants to verify your identity'), findsOneWidget);
      expect(find.text('Everything the app reads from your document'), findsOneWidget);
    });

    testWidgets('says the details go step by step and reach the party only on finishing', (tester) async {
      await tester.pumpWidget(_app(ProofingSessionConsentScreen(info: _info(), onConsent: () {}, onDecline: () {})));

      expect(find.textContaining('acme-tenant only receives them when you finish'), findsOneWidget);
    });

    testWidgets('shows a human-readable label per requested attribute, deduplicating dg2/face_image', (tester) async {
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(requestedAttributes: const ['dg1', 'dg2', 'face_image', 'biometrics']),
            onConsent: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.text('Document identity (name, date of birth, document number, expiry)'), findsOneWidget);
      expect(find.text('Your face photo from the document chip'), findsOneWidget);
      expect(find.text('Face verification result'), findsOneWidget);
    });

    testWidgets('names the age an age check answers for', (tester) async {
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(requestedAttributes: const ['age_over', 'chip_checks'], ageOver: 18),
            onConsent: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.text('Whether you are 18 or older'), findsOneWidget);
      expect(find.text('age_over'), findsNothing);
    });

    testWidgets('names the age the session view carries in ageOver', (tester) async {
      final info = ProofingSessionInfo.fromJson({
        'id': 'sess1',
        'relyingParty': 'acme-tenant',
        'requestedAttributes': ['age_over'],
        'ageOver': 21,
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
      });
      await tester.pumpWidget(_app(ProofingSessionConsentScreen(info: info, onConsent: () {}, onDecline: () {})));

      expect(find.text('Whether you are 21 or older'), findsOneWidget);
    });

    testWidgets('says "old enough" for an age check when the server sent no age', (tester) async {
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(requestedAttributes: const ['age_over']),
            onConsent: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.text('Whether you are old enough'), findsOneWidget);
      expect(find.text('age_over'), findsNothing);
    });

    testWidgets('falls back to the raw key for an attribute it does not recognise', (tester) async {
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(requestedAttributes: const ['some_future_attribute']),
            onConsent: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.text('some_future_attribute'), findsOneWidget);
    });

    testWidgets('Continue calls onConsent, Decline calls onDecline', (tester) async {
      var consented = false;
      var declined = false;
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(),
            onConsent: () => consented = true,
            onDecline: () => declined = true,
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      expect(consented, isTrue);
      expect(declined, isFalse);

      await tester.tap(find.text('Decline'));
      expect(declined, isTrue);
    });

    testWidgets('disables Continue and shows an expired message once expiresAt has passed', (tester) async {
      var consented = false;
      await tester.pumpWidget(
        _app(
          ProofingSessionConsentScreen(
            info: _info(expiresIn: const Duration(minutes: -1)),
            onConsent: () => consented = true,
            onDecline: () {},
          ),
        ),
      );

      expect(find.text('This request has expired.'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(consented, isFalse);
    });
  });
}
