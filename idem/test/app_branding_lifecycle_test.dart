import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:idem/l10n/app_localizations_en.dart';
import 'package:idem/main.dart';
import 'package:idem/providers/branding_provider.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/routing.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_coordinator.dart';
import 'package:idem/services/trusted_servers.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/pages/choose_document_screen.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/proofing_session_consent_screen.dart';

const _api = 'https://proof.example.com';
const _link = 'vcmrtd://verify?handover=h-1&api=$_api';
final _l10n = AppLocalizationsEn();
const _brandName = 'Acme Bank';
const _deepLinkChannel = MethodChannel('proofing_deeplink');

/// A proofing server holding one branded session, whose state a test moves
/// on: [update] is what the app's next request (or open long-poll) sees.
class _FakeServer extends ProofingSessionClient {
  Map<String, dynamic> _view = _session();
  int _changes = 0;

  /// When false, device state reports fail as a network error would.
  bool reachable = true;

  final _waits = <Completer<ProofingSessionInfo>>[];

  ProofingSessionInfo get _info => ProofingSessionInfo.fromJson(_view);

  /// Changes the session and answers every open long-poll with it.
  void update({String status = 'opened', String lifecycle = proofingLifecycleActive}) {
    _view = _session(status: status, lifecycle: lifecycle, changeKey: 'k${++_changes}');
    for (final wait in _waits) {
      wait.complete(_info);
    }
    _waits.clear();
  }

  static Map<String, dynamic> _session({
    String status = 'opened',
    String lifecycle = proofingLifecycleActive,
    String changeKey = 'k0',
  }) => {
    'id': 'sess-1',
    'relyingParty': 'Acme Bank',
    'requestedAttributes': ['dg1'],
    'expiresAt': '2030-01-01T00:00:00Z',
    'status': status,
    'lifecycle': lifecycle,
    'changeKey': changeKey,
    'currentStep': 'document_capture',
    'completedSteps': <String>[],
    'device': {'authorized': true, 'role': 'native', 'state': 'active'},
    'branding': {'name': _brandName, 'primaryColor': '#C2410C', 'secondaryColor': '#7C3AED'},
  };

  @override
  Future<ProofingSessionClaim> claimHandover(ProofingHandoverLink link) async => ProofingSessionClaim(
    ref: const ProofingSessionRef(apiBase: _api, token: 'tok-1', deviceToken: 'dev-1'),
    info: _info,
  );

  @override
  Future<ProofingSessionInfo> fetchSession(ProofingSessionRef ref) async => _info;

  @override
  Future<Uint8List?> fetchBrandingLogo(ProofingSessionRef ref) async => null;

  @override
  Future<ProofingSessionInfo> reportDeviceState(ProofingSessionRef ref, {required bool active}) async {
    if (!reachable) throw Exception('offline');
    return _info;
  }

  @override
  Future<ProofingSessionInfo> waitForChange(ProofingSessionRef ref, String since, {http.Client? httpClient}) {
    final wait = Completer<ProofingSessionInfo>();
    _waits.add(wait);
    return wait.future;
  }

  @override
  Future<void> markStepStarted(ProofingSessionRef ref, String step) async {}
}

enum _Launch { deepLink, home }

/// Starts the app the way a tapped handover link does, on the branded
/// consent screen; with [_Launch.home], just the app, on its home screen.
Future<_FakeServer> _openSession(WidgetTester tester, {_Launch launch = _Launch.deepLink}) async {
  final server = _FakeServer();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    _deepLinkChannel,
    (call) async => call.method == 'getInitialLink' && launch == _Launch.deepLink ? _link : null,
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _deepLinkChannel,
      null,
    ),
  );

  final coordinator = ProofingSessionCoordinator(
    client: server,
    retryDelay: const Duration(milliseconds: 10),
    trustedServers: const TrustedServers.all(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        proofingSessionClientProvider.overrideWithValue(server),
        proofingSessionCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: VcMrtdApp(),
    ),
  );
  await tester.pumpAndSettle();

  if (launch == _Launch.home) return server;
  expect(find.byType(ProofingSessionConsentScreen), findsOneWidget);
  _expectBranding(tester, _brandName);
  return server;
}

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.text(_l10n.proofingContinue));
  await tester.pumpAndSettle();
  expect(find.byType(ChooseDocumentScreen), findsOneWidget);
  _expectBranding(tester, _brandName);
}

/// The phone is put away, then picked up again.
Future<void> _background(WidgetTester tester) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

enum _Wait { settle, briefly }

Future<void> _foreground(WidgetTester tester, {_Wait wait = _Wait.settle}) async {
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  // An unreachable server is retried until the user gives up: never settles.
  wait == _Wait.settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 100));
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(VcMrtdApp)));

/// Both what the app holds and what the screen on top is drawn with.
void _expectBranding(WidgetTester tester, String name) {
  expect(_container(tester).read(activeBrandingProvider).name, name);
  final onTop = tester.element(find.byType(Scaffold).last);
  expect(Theme.of(onTop).extension<BrandTheme>()!.name, name);
}

/// Back home in Idem's own look, with nothing pinned and [message] shown.
void _expectEndedInIdemLook(WidgetTester tester, {String? message}) {
  expect(find.byType(DocumentTypeSelectionScreen), findsOneWidget);
  expect(find.byType(ProofingSessionConsentScreen), findsNothing);
  expect(_container(tester).read(activeProofingSessionProvider), isNull);
  _expectBranding(tester, AppBranding.idem.name);
  if (message != null) expect(find.text(message), findsOneWidget);
}

void main() {
  testWidgets('a scanned QR shows the consent screen in the requester\'s look', (tester) async {
    await _openSession(tester, launch: _Launch.home);
    final router = GoRouter.of(tester.element(find.byType(DocumentTypeSelectionScreen)));
    // A screen over home, popped right before the consent screen is pushed,
    // as the QR scanner is.
    router.push('/settings');
    await tester.pumpAndSettle();
    await openProofingSessionLink(router, _container(tester), _link, beforePush: router.pop);
    await tester.pumpAndSettle();
    expect(find.byType(ProofingSessionConsentScreen), findsOneWidget);
    _expectBranding(tester, _brandName);
  });

  group('the white-label comes off when the session ends', () {
    testWidgets('it expires while the phone is away during an accepted session', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      await _background(tester);
      server.update(status: 'expired', lifecycle: proofingLifecycleExpired);
      await _foreground(tester);
      _expectEndedInIdemLook(tester, message: _l10n.accessExpired);
    });

    testWidgets('it expires while the phone is away on the consent screen', (tester) async {
      final server = await _openSession(tester);
      await _background(tester);
      server.update(status: 'expired', lifecycle: proofingLifecycleExpired);
      await _foreground(tester);
      _expectEndedInIdemLook(tester, message: _l10n.accessExpired);
    });

    testWidgets('it expires while the app is open', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      server.update(status: 'expired', lifecycle: proofingLifecycleExpired);
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester, message: _l10n.accessExpired);
    });

    testWidgets('it is completed on the other device', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      server.update(status: 'completed', lifecycle: proofingLifecycleComplete);
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester, message: _l10n.sessionCompleteTitle);
    });

    testWidgets('it is completed while the phone is away', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      await _background(tester);
      server.update(status: 'completed', lifecycle: proofingLifecycleComplete);
      await _foreground(tester);
      _expectEndedInIdemLook(tester, message: _l10n.sessionCompleteTitle);
    });

    testWidgets('it is cancelled by the relying party', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      server.update(status: 'cancelled', lifecycle: proofingLifecycleCancelled);
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester, message: _l10n.accessCancelled);
    });

    testWidgets('the user gives up on an unreachable server after coming back', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      await _background(tester);
      server.reachable = false;
      await _foreground(tester, wait: _Wait.briefly);
      await tester.tap(find.text(_l10n.faceStopVerification));
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester);
    });

    testWidgets('the user declines it', (tester) async {
      await _openSession(tester);
      await tester.tap(find.text(_l10n.proofingDecline));
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester);
    });

    testWidgets('the user backs out of the consent screen', (tester) async {
      await _openSession(tester);
      // The system back gesture/button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _expectEndedInIdemLook(tester);
    });

    testWidgets('the app hands the rest to the browser, then the session completes there', (tester) async {
      final server = await _openSession(tester);
      await _accept(tester);
      // What the browser-run face step does once the chip is read.
      _container(tester).read(activeProofingSessionProvider.notifier).set(null);
      await tester.pumpAndSettle();
      _expectBranding(tester, AppBranding.idem.name);
      server.update(status: 'completed', lifecycle: proofingLifecycleComplete);
      await tester.pumpAndSettle();
      _expectBranding(tester, AppBranding.idem.name);
    });
  });
}
