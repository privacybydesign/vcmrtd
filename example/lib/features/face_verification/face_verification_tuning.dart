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

  static const bool emitDebugEvents = bool.fromEnvironment('FV_EMIT_DEBUG_EVENTS', defaultValue: false);

  static double _doubleEnv(String key, double fallback) {
    final raw = String.fromEnvironment(key, defaultValue: '');
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }
}
