import 'package:flutter/services.dart';

/// Talks to the native ProofingDeepLinkPlugin (iOS Swift / Android Kotlin),
/// which forwards a tapped `vcmrtd://verify?token=...&api=...` link (see
/// identity-proofing-service's deepLink() in
/// backend/internal/api/sessions.go) to Dart. Kept separate from the
/// existing `deep_link_handler` channel, which is scoped to the unrelated
/// https passport-issuer.yivi.app flow and has no Dart-side listener of its
/// own today.
class ProofingDeepLinkChannel {
  static const _channel = MethodChannel('proofing_deeplink');

  /// The link that launched the app cold, if any. Only ever returns a value
  /// once per app start — the native side clears it after the first read.
  static Future<String?> getInitialLink() async {
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } on PlatformException {
      return null;
    }
  }

  /// Calls [onLink] for every vcmrtd:// link opened while the app is
  /// already running.
  static void listen(void Function(String link) onLink) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        onLink(call.arguments as String);
      }
    });
  }
}
