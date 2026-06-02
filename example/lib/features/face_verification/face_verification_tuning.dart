/// Compile-time tuning parameters for face verification.
///
/// All values can be overridden at build time via `--dart-define=KEY=value`.
/// Integer fields use [int.fromEnvironment]; floating-point fields use the
/// private [_doubleEnv] helper which parses a string default.
///
/// Example override:
///   flutter run --dart-define=FV_REQUIRED_ACTIONS=2 --dart-define=FV_PASSIVE_TARGET_MS=3000
class FaceVerificationTuning {
  // ---------------------------------------------------------------------------
  // Active liveness — challenge count
  // ---------------------------------------------------------------------------

  /// Total number of liveness challenges presented per session.
  static const int requiredActions = int.fromEnvironment('FV_REQUIRED_ACTIONS', defaultValue: 3);

  /// Minimum challenges the user must complete to pass active liveness.
  /// Must be < [requiredActions]. The engine adds an extra challenge when
  /// the user hits exactly this count to avoid bare-minimum acceptance.
  static const int actionsNeededToPass = int.fromEnvironment('FV_ACTIONS_NEEDED_TO_PASS', defaultValue: 2);

  /// Frames without a detected gesture before the current challenge times out
  /// and the engine advances to the next one. At 30 fps this is 8 seconds.
  static const int actionTimeoutFrames = int.fromEnvironment('FV_ACTION_TIMEOUT_FRAMES', defaultValue: 240);

  // ---------------------------------------------------------------------------
  // Anti-spoof (MiniFASNet)
  // ---------------------------------------------------------------------------

  /// Fraction of frames sampled for anti-spoof inference (0–1). Lower values
  /// reduce CPU load; higher values improve score stability.
  static final double antiSpoofSampleRate = _doubleEnv('FV_ANTISPOOF_SAMPLE_RATE', 0.70);

  /// Yaw angle (°) beyond which a frame is skipped for anti-spoof sampling.
  /// Heavily turned faces produce unreliable scores.
  static final double antiSpoofMaxYawDeg = _doubleEnv('FV_ANTISPOOF_MAX_YAW_DEG', 20.0);

  /// Minimum average anti-spoof confidence required to pass.
  /// Values below this threshold indicate a likely printed photo or screen replay.
  static final double antiSpoofMinScore = _doubleEnv('FV_ANTISPOOF_MIN_SCORE', 0.65);

  /// Minimum number of sampled frames before the anti-spoof decision is made.
  static const int antiSpoofMinSamples = int.fromEnvironment('FV_ANTISPOOF_MIN_SAMPLES', defaultValue: 4);

  // ---------------------------------------------------------------------------
  // Gesture detection thresholds
  // ---------------------------------------------------------------------------

  /// Yaw delta (°) from neutral required to register a head turn.
  static final double turnYawThreshold = _doubleEnv('FV_TURN_YAW_THRESHOLD', 28.0);

  /// Mouth-open ratio (vertical gap / face height) required to register a mouth-open gesture.
  static final double mouthOpenThreshold = _doubleEnv('FV_MOUTH_OPEN_THRESHOLD', 0.028);

  // ---------------------------------------------------------------------------
  // Selfie quality gates (used during alignment for both active and passive)
  // ---------------------------------------------------------------------------

  /// Minimum face bounding-box area as a fraction of the frame.
  /// Below this the user is too far from the camera.
  static final double alignMinBboxArea = _doubleEnv('FV_ALIGN_MIN_BBOX_AREA', 0.04);

  /// Maximum face bounding-box area as a fraction of the frame.
  /// Above this the user is too close to the camera.
  static final double alignMaxBboxArea = _doubleEnv('FV_ALIGN_MAX_BBOX_AREA', 0.45);

  // ---------------------------------------------------------------------------
  // Passive liveness countdown
  // ---------------------------------------------------------------------------

  /// Wall-clock milliseconds the user must hold still in the oval to pass
  /// passive liveness. Sized to cover the rPPG window (~2 s) plus anti-spoof
  /// sampling with comfortable headroom.
  static const int passiveTargetMs = int.fromEnvironment('FV_PASSIVE_TARGET_MS', defaultValue: 5000);

  /// Milliseconds the face must stay in the oval before the countdown begins.
  /// Prevents the countdown firing on a single already-aligned frame (e.g. after a retry).
  static const int passiveLockOnMs = int.fromEnvironment('FV_PASSIVE_LOCK_ON_MS', defaultValue: 600);

  /// Maximum yaw (°) allowed during passive countdown. Deliberately lenient —
  /// we do not require eyes-open / mouth-closed because those would trip on blinks.
  static final double passiveMaxYawDeg = _doubleEnv('FV_PASSIVE_MAX_YAW_DEG', 22.0);

  /// Maximum X-axis offset of the face center from the frame center (0–1).
  static final double passiveCenterMaxOffsetX = _doubleEnv('FV_PASSIVE_CENTER_MAX_OFFSET_X', 0.18);

  /// Maximum Y-axis offset of the face center from the frame center (0–1).
  /// Slightly larger than X because the oval is taller than it is wide.
  static final double passiveCenterMaxOffsetY = _doubleEnv('FV_PASSIVE_CENTER_MAX_OFFSET_Y', 0.22);

  // ---------------------------------------------------------------------------
  // Mid-session consistency check
  // ---------------------------------------------------------------------------

  /// Minimum cosine similarity between two selfies taken within the same session
  /// for the session to pass. A face swap drops this well below 0.50 because the
  /// new face produces a completely different embedding.
  static final double consistencyCheckThreshold = _doubleEnv('FV_CONSISTENCY_THRESHOLD', 0.50);

  // ---------------------------------------------------------------------------
  // Debug
  // ---------------------------------------------------------------------------

  /// When true, the engine emits per-frame debug events with yaw, smile, and
  /// mouth ratio. Enable via `--dart-define=FV_EMIT_DEBUG_EVENTS=true`.
  static const bool emitDebugEvents = bool.fromEnvironment('FV_EMIT_DEBUG_EVENTS', defaultValue: false);

  // ---------------------------------------------------------------------------

  /// Parses a floating-point environment variable, falling back to [fallback]
  /// if the variable is absent or cannot be parsed. Silent on parse failure
  /// to avoid crashing on a misconfigured build flag — check the value in logs.
  static double _doubleEnv(String key, double fallback) {
    final raw = String.fromEnvironment(key, defaultValue: '');
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }
}
