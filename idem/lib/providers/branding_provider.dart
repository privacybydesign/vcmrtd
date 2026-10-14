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

  /// The last session look built, kept across a [reset] so wearing it again
  /// (once the QR scanner is popped, say) doesn't fetch its logo twice.
  ((String, ProofingBranding), AppBranding)? _built;

  /// Bumped by every [reset], so a [useSession] still fetching its logo
  /// when the session ends doesn't dress the app again afterwards.
  int _generation = 0;

  /// The session whose branding the app wears, or is loading.
  String? _sessionToken;

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
    _sessionToken = sessionRef.token;
    final built = _built;
    if (built != null && built.$1 == source) {
      _source = source;
      state = built.$2;
      return;
    }
    final generation = _generation;
    Uint8List? logo;
    if (branding.hasLogo) {
      try {
        logo = await ref.read(proofingSessionClientProvider).fetchBrandingLogo(sessionRef);
      } catch (e) {
        _log.warning('branding logo unavailable: $e');
      }
    }
    if (generation != _generation) return;
    _source = source;
    state = AppBranding.fromSession(branding, logo: logo);
    _built = (source, state);
  }

  /// The session [sessionRef] completed or this device lost it (expired,
  /// handed over, ...): back to Idem's own look if the app wears its branding,
  /// pinned or not.
  void endSession(ProofingSessionRef sessionRef) {
    if (_sessionToken == sessionRef.token) reset();
  }

  /// Back to Idem's own look. A no-op when the app already wears it, so
  /// calling it from a navigation during a build changes nothing.
  void reset() {
    if (_sessionToken == null && identical(state, AppBranding.idem)) return;
    _generation++;
    _source = null;
    _sessionToken = null;
    state = AppBranding.idem;
  }
}
