class FaceVerificationTuning {
  static const int requiredActions = int.fromEnvironment('FV_REQUIRED_ACTIONS', defaultValue: 3);
  static const int actionsNeededToPass = int.fromEnvironment('FV_ACTIONS_NEEDED_TO_PASS', defaultValue: 2);
  static const int actionTimeoutFrames = int.fromEnvironment('FV_ACTION_TIMEOUT_FRAMES', defaultValue: 240);

  static final double antiSpoofSampleRate = _doubleEnv('FV_ANTISPOOF_SAMPLE_RATE', 0.70);
  static final double antiSpoofMaxYawDeg = _doubleEnv('FV_ANTISPOOF_MAX_YAW_DEG', 20.0);

  static final double antiSpoofMinScore = _doubleEnv('FV_ANTISPOOF_MIN_SCORE', 0.65);
  static const int antiSpoofMinSamples = int.fromEnvironment('FV_ANTISPOOF_MIN_SAMPLES', defaultValue: 4);

  static final double turnYawThreshold = _doubleEnv('FV_TURN_YAW_THRESHOLD', 28.0);
  static final double mouthOpenThreshold = _doubleEnv('FV_MOUTH_OPEN_THRESHOLD', 0.028);

  // Selfie quality gates used during alignment for both active and passive flows.
  static final double alignMinBboxArea = _doubleEnv('FV_ALIGN_MIN_BBOX_AREA', 0.04);
  static final double alignMaxBboxArea = _doubleEnv('FV_ALIGN_MAX_BBOX_AREA', 0.45);

  // Passive liveness: once the face is well-aligned, a fixed countdown of this
  // many milliseconds runs to completion (it does not pause). Sized to
  // comfortably cover the rPPG window (~2s) plus anti-spoof sampling.
  static const int passiveTargetMs = int.fromEnvironment('FV_PASSIVE_TARGET_MS', defaultValue: 5000);

  // The face must be held continuously in the oval for this long before the
  // countdown begins, so it never fires on a single already-aligned frame
  // (e.g. when the user is still positioned after a retry).
  static const int passiveLockOnMs = int.fromEnvironment('FV_PASSIVE_LOCK_ON_MS', defaultValue: 600);

  // Passive alignment is intentionally lenient: we only need a present,
  // reasonably frontal face at a sensible distance. We deliberately do NOT
  // require eyes-open / mouth-closed / no-smile (that strict "at rest" gate is
  // for grabbing a single baseline frame in active mode) — held continuously it
  // would trip on every blink. Liveness itself is covered by anti-spoof + rPPG.
  static final double passiveMaxYawDeg = _doubleEnv('FV_PASSIVE_MAX_YAW_DEG', 22.0);

  // "Inside the oval" gate: how far the face bbox center may sit from the frame
  // center (normalized 0..1 per axis) before the countdown will start. The oval
  // is taller than wide, so the vertical tolerance is a touch larger.
  static final double passiveCenterMaxOffsetX = _doubleEnv('FV_PASSIVE_CENTER_MAX_OFFSET_X', 0.18);
  static final double passiveCenterMaxOffsetY = _doubleEnv('FV_PASSIVE_CENTER_MAX_OFFSET_Y', 0.22);

  // Mid-liveness selfie-to-selfie consistency check threshold.
  // Same session, same lighting — a face swap drops this well below 0.50.
  static final double consistencyCheckThreshold = _doubleEnv('FV_CONSISTENCY_THRESHOLD', 0.50);

  static const bool emitDebugEvents = bool.fromEnvironment('FV_EMIT_DEBUG_EVENTS', defaultValue: false);

  static double _doubleEnv(String key, double fallback) {
    final raw = String.fromEnvironment(key, defaultValue: '');
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }
}
