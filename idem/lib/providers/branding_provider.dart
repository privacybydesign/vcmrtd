import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:logging/logging.dart';

final _log = Logger('branding');

/// The branding the app is dressed in: that of the session being opened or
/// worked on, so the app looks like the requester's own, and Idem's own
/// otherwise.
final activeBrandingProvider = NotifierProvider<ActiveBrandingNotifier, AppBranding>(ActiveBrandingNotifier.new);

class ActiveBrandingNotifier extends Notifier<AppBranding> {
  /// What [state] was built from, so an unchanged session view keeps it
  /// (and its logo) instead of fetching the logo again.
  (String, ProofingBranding)? _source;

  @override
  AppBranding build() => AppBranding.idem;

  /// Dresses the app in [info]'s branding; a session without any gets Idem's.
  /// The logo comes from the session's own server through [sessionRef]'s
  /// device credential; one that can't be fetched shows the name instead.
  Future<void> useSession(ProofingSessionRef sessionRef, ProofingSessionInfo info) async {
    final branding = info.branding;
    if (branding == null) {
      reset();
      return;
    }
    final source = (sessionRef.token, branding);
    if (_source == source) return;
    Uint8List? logo;
    if (branding.hasLogo) {
      try {
        logo = await ref.read(proofingSessionClientProvider).fetchBrandingLogo(sessionRef);
      } catch (e) {
        _log.warning('branding logo unavailable: $e');
      }
    }
    _source = source;
    state = AppBranding.fromSession(branding, logo: logo);
  }

  /// Back to Idem's own look.
  void reset() {
    _source = null;
    state = AppBranding.idem;
  }
}
