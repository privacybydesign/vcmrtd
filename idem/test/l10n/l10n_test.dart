import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/proofing_session_client.dart';

Set<String> _keys(String path) =>
    (json.decode(File(path).readAsStringSync()) as Map<String, dynamic>).keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nl carries exactly the en keys', () {
    expect(_keys('lib/l10n/app_nl.arb'), _keys('lib/l10n/app_en.arb'));
  });

  test('supportedLocaleFor matches on the language subtag', () {
    expect(supportedLocaleFor('nl'), const Locale('nl'));
    expect(supportedLocaleFor('nl-NL'), const Locale('nl'));
    expect(supportedLocaleFor('en_GB'), const Locale('en'));
    expect(supportedLocaleFor('NL'), const Locale('nl'));
    expect(supportedLocaleFor('de'), isNull);
    expect(supportedLocaleFor(''), isNull);
    expect(supportedLocaleFor(null), isNull);
  });

  test('deviceAcceptLanguage lists the device locales by preference', () {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.localesTestValue = const [Locale('nl', 'NL'), Locale('en', 'US')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
    expect(deviceAcceptLanguage(), 'nl-NL, en-US;q=0.9');
  });

  test('the session language switches the app locale; unshipped ones leave it alone', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appLocaleProvider.notifier);
    expect(container.read(appLocaleProvider), isNull);
    notifier.useSessionLanguage('nl');
    expect(container.read(appLocaleProvider), const Locale('nl'));
    expect(currentL10n.localeName, 'nl');
    notifier.useSessionLanguage('fr');
    expect(container.read(appLocaleProvider), const Locale('nl'));
    notifier.useSessionLanguage('en');
    expect(currentL10n.localeName, 'en');
  });

  test('ProofingSessionInfo parses language', () {
    final view = {'id': 's1', 'relyingParty': 'RP', 'expiresAt': '2026-09-24T12:00:00Z', 'language': 'nl'};
    expect(ProofingSessionInfo.fromJson(view).language, 'nl');
    expect(ProofingSessionInfo.fromJson({...view}..remove('language')).language, isNull);
  });
}
