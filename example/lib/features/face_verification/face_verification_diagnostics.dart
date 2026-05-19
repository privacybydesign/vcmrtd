import 'package:flutter/foundation.dart' show debugPrint;

class FaceVerificationDiagnostics {
  static const bool enabled = bool.fromEnvironment('FV_DIAGNOSTICS', defaultValue: false);

  static int _sessionId = 0;
  static int _sessionStartMs = 0;

  static void startSession(String message) {
    if (!enabled) return;
    _sessionId++;
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    log(message);
  }

  static void log(String message) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = _sessionStartMs == 0 ? 0 : now - _sessionStartMs;
    debugPrint('[FaceVerification][diag][s$_sessionId +${elapsed}ms] $message');
  }
}
