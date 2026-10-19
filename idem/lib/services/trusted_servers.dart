import 'package:flutter/foundation.dart';

/// The servers this app runs proofing sessions with, as origins, from
/// `--dart-define=PROOFING_TRUSTED_SERVERS=https://wallet.example,...`. A QR
/// code or deep link naming any other server is refused before it is
/// contacted, so no one can run a server of their own that shows the app in
/// somebody else's branding.
///
/// A debug build without the define trusts every server, so a dev backend on a
/// LAN address works; a release build without it trusts none.
class TrustedServers {
  const TrustedServers(this._origins) : _trustAll = false;

  /// Every server, as a debug build without the define has it.
  const TrustedServers.all() : _origins = const {}, _trustAll = true;

  static final current = TrustedServers.parse(
    const String.fromEnvironment('PROOFING_TRUSTED_SERVERS'),
    whenEmpty: kDebugMode ? EmptyListPolicy.trustAll : EmptyListPolicy.trustNone,
  );

  factory TrustedServers.parse(String define, {required EmptyListPolicy whenEmpty}) {
    final origins = define.split(',').map((s) => _origin(s.trim())).whereType<String>().toSet();
    return origins.isEmpty && whenEmpty == EmptyListPolicy.trustAll
        ? const TrustedServers.all()
        : TrustedServers(origins);
  }

  final Set<String> _origins;
  final bool _trustAll;

  bool isTrusted(String apiBase) {
    if (_trustAll) return true;
    final origin = _origin(apiBase);
    return origin != null && _origins.contains(origin);
  }

  /// scheme://host[:port], lower-cased; null for anything that isn't an http(s) URL.
  static String? _origin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }
}

/// What [TrustedServers.parse] makes of a define that names no server.
enum EmptyListPolicy { trustAll, trustNone }
