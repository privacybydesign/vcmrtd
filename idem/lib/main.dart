// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:mrz_capture/mrz_capture.dart' show MrzCaptureLocalizations;
import 'package:vcmrtd/extensions.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/branding_provider.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/session_settings.dart';
import 'package:idem/routing.dart';
import 'package:idem/services/proofing_deeplink_channel.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:idem/services/proofing_session_coordinator.dart';
import 'package:idem/services/proofing_session_watcher.dart';
import 'package:idem/widgets/common/issuance_result_dialogs.dart';
import 'package:idem/widgets/common/proofing_session_check_overlay.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.logSensitiveData = true;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();
  await enableGuidedEdgeToEdge();
  _registerFontLicenses();
  runApp(ProviderScope(child: VcMrtdApp()));
}

/// The white-label fonts are OFL-licensed, which asks for the licence to
/// ship with them; this puts it on the platform licence page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, path) in const [
      (AppFonts.heading, 'assets/fonts/OFL-Montserrat.txt'),
      (AppFonts.body, 'assets/fonts/OFL-Nunito.txt'),
      ('Alexandria', 'assets/fonts/OFL-Alexandria.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(path));
    }
  });
}

class VcMrtdApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<VcMrtdApp> createState() => _VcMrtdAppState();
}

class _VcMrtdAppState extends ConsumerState<VcMrtdApp> {
  late final GoRouter _router = createRouter();
  late final ProofingSessionCoordinator _sessions = ref.read(proofingSessionCoordinatorProvider);
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<ProofingSessionEvent>? _sessionEvents;

  /// The settings from before the pinned session overwrote them.
  UserSettingsSnapshot? _userSettings;

  @override
  void initState() {
    super.initState();
    // Listen to every newly accepted session through the backend.
    // Unpinning (null) doesn't stop listening - see ProofingSessionWatcher.
    ref.listenManual(activeProofingSessionProvider, (previous, next) {
      final container = ProviderScope.containerOf(context);
      if (next == null) {
        // The session ended: the user's own settings and look apply again.
        _userSettings?.restore(container);
        _userSettings = null;
        if (previous != null) ref.read(activeBrandingProvider.notifier).reset();
        return;
      }
      // The requester's look, kept current as the session's view changes.
      ref.read(activeBrandingProvider.notifier).useSession(next.ref, next.info);
      _sessions.track(next.ref, next.info);
      // The session's language (see lib/l10n/l10n.dart) decides the UI's.
      ref.read(appLocaleProvider.notifier).useSessionLanguage(next.info.language);
      // The session's flow decides the checks, and Settings shows them -
      // only while it's pinned.
      _userSettings ??= UserSettingsSnapshot.capture(container);
      applyProofingSessionSettings(container, next.info);
    });
    _sessionEvents = _sessions.events.listen(_onProofingSessionEvent);
    _router.routerDelegate.addListener(_resetBrandingOutsideSession);
    // Tell the server when this device stops/resumes working on the
    // session, and re-check with it before continuing after a resume.
    _lifecycle = AppLifecycleListener(onStateChange: _sessions.appLifecycleChanged);
    // A tapped vcmrtd:// link while the app is already running.
    ProofingDeepLinkChannel.listen(_openProofingLink);
    // A tapped vcmrtd:// link that cold-started the app.
    ProofingDeepLinkChannel.getInitialLink().then((link) {
      if (link != null) _openProofingLink(link);
    });
  }

  BuildContext? get _navigatorContext => _router.routerDelegate.navigatorKey.currentContext;

  /// Back home or at the scanner without a session (a consent screen left
  /// with Back, say), the app wears its own look again.
  void _resetBrandingOutsideSession() {
    // The screen on top: a pushed one (the consent screen) leaves the uri
    // at the screen it was pushed from.
    final routes = _router.routerDelegate.currentConfiguration;
    if (routes.isEmpty) return;
    final path = routes.last.matchedLocation;
    if (sessionlessPaths.contains(path) && ref.read(activeProofingSessionProvider) == null) {
      ref.read(activeBrandingProvider.notifier).reset();
    }
  }

  /// Claims the session a vcmrtd:// deep link points at (a session link or a
  /// handover link) and pushes the consent screen — the deep-link
  /// counterpart of _handleScannedQr in routing.dart.
  Future<void> _openProofingLink(String value) async {
    final error = await openProofingSessionLink(_router, ProviderScope.containerOf(context), value);
    final navigatorContext = _navigatorContext;
    if (error == null || navigatorContext == null || !navigatorContext.mounted) return;
    DialogHelpers.showInfoDialog(
      context: navigatorContext,
      title: navigatorContext.l10n.sessionOpenFailedTitle,
      message: error,
    );
  }

  /// The listener (ProofingSessionWatcher, via the coordinator) or the
  /// resume check found something the app has to act on.
  void _onProofingSessionEvent(ProofingSessionEvent event) {
    switch (event) {
      case ProofingSessionUpdated(:final ref, :final info):
        this.ref.read(activeProofingSessionProvider.notifier).updateInfo(ref, info);
      case ProofingSessionWasReset(:final ref, :final info):
        _onProofingSessionReset(ref, info);
      case ProofingSessionAccessLost(:final ref, :final reason):
        _onProofingSessionAccessLost(ref, reason);
      case ProofingSessionCompleted(:final ref):
        _onProofingSessionCompleted(ref);
    }
  }

  /// Shows an info dialog, in the UI's current language, on top of whatever
  /// screen the router goes to next.
  void _showInfoAfterNavigation((String, String) Function(AppLocalizations l10n) content) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorContext;
      if (context == null) return;
      final (title, message) = content(context.l10n);
      DialogHelpers.showInfoDialog(context: context, title: title, message: message);
    });
  }

  /// Unpins [sessionRef] and returns to document selection when it is the
  /// pinned session; returns what was pinned, or null when it is not.
  ActiveProofingSession? _endPinnedSession(ProofingSessionRef sessionRef) {
    final pinned = ref.read(activeProofingSessionProvider);
    if (pinned == null || !pinned.ref.sameAccess(sessionRef)) {
      return null;
    }
    ref.read(activeProofingSessionProvider.notifier).set(null);
    _router.go(selectDocTypePath);
    return pinned;
  }

  /// Leaves the consent screen when it is on top and shows [sessionRef]:
  /// that session ended before the user accepted it (expired while the
  /// phone was away, say). Returns whether it did.
  bool _leaveConsentFor(ProofingSessionRef sessionRef) {
    final top = _router.routerDelegate.currentConfiguration.last;
    if (top is! ImperativeRouteMatch || top.matchedLocation != proofingConsentPath) return false;
    final extra = top.matches.extra;
    final shown = extra is Map<String, dynamic> ? extra['ref'] : null;
    if (shown is! ProofingSessionRef || !shown.sameAccess(sessionRef)) return false;
    _router.go(selectDocTypePath);
    return true;
  }

  /// The session was submitted and has its outcome - from this app's Submit
  /// button or on the other device, whichever came first: nothing is left
  /// to do here. A session the app already finished its part of (unpinned,
  /// e.g. face verification handed off to the browser) ends quietly.
  void _onProofingSessionCompleted(ProofingSessionRef sessionRef) {
    ref.read(activeBrandingProvider.notifier).endSession(sessionRef);
    final pinned = _endPinnedSession(sessionRef);
    if (pinned == null) {
      if (_leaveConsentFor(sessionRef)) {
        _showInfoAfterNavigation((l10n) => (l10n.sessionStoppedTitle, ProofingAccessDenial.complete.message));
      }
      return;
    }
    _showInfoAfterNavigation(
      (l10n) => (l10n.sessionCompleteTitle, l10n.sessionCompleteMessage(pinned.info.relyingParty)),
    );
  }

  /// The relying party reset the session: the server already dropped every
  /// step, so re-pin it with its fresh view, send the user back to where
  /// accepting the request leads (document selection for a document flow),
  /// and tell them why their progress just disappeared.
  void _onProofingSessionReset(ProofingSessionRef sessionRef, ProofingSessionInfo info) {
    final session = ActiveProofingSession(ref: sessionRef, info: info);
    ref.read(activeProofingSessionProvider.notifier).set(session);
    final context = _navigatorContext;
    if (context == null) return;
    restartProofingSessionFlow(context, session);
    _showInfoAfterNavigation((l10n) => (l10n.sessionRestartedTitle, l10n.sessionRestartedMessage(info.relyingParty)));
  }

  /// This device may no longer act on the session (handed over to another
  /// device, expired, ...): stop the local verification wherever it is and
  /// say why. A session the app already finished its part of (unpinned,
  /// e.g. face verification handed off to the browser) just ends quietly.
  void _onProofingSessionAccessLost(ProofingSessionRef sessionRef, ProofingAccessDenial reason) {
    ref.read(activeBrandingProvider.notifier).endSession(sessionRef);
    if (_endPinnedSession(sessionRef) == null && !_leaveConsentFor(sessionRef)) return;
    _showInfoAfterNavigation((l10n) => (l10n.sessionStoppedTitle, reason.message));
  }

  /// The user gave up waiting for the resume check (server unreachable).
  void _abandonProofingSession() {
    _sessions.release();
    ref.read(activeProofingSessionProvider.notifier).set(null);
    _router.go(selectDocTypePath);
  }

  @override
  void dispose() {
    _sessionEvents?.cancel();
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      builder: (context, child) => Stack(
        children: [
          ?child,
          ProofingSessionCheckOverlay(check: _sessions.check, onAbandon: _abandonProofingSession),
        ],
      ),
      localizationsDelegates: const [...AppLocalizations.localizationsDelegates, MrzCaptureLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(appLocaleProvider),
      theme: appTheme(ref.watch(activeBrandingProvider)),
    );
  }
}
