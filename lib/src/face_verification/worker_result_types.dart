import 'package:vcmrtd/face_verification.dart';

// Result of one processed camera frame from the pipeline worker.
class WorkerFrameResult {
  const WorkerFrameResult({required this.face});

  final FaceObservation? face;
}

// Anti-spoof and rPPG results collected by the passive worker over the session.
class WorkerPassiveResult {
  const WorkerPassiveResult({
    required this.antiSpoofScore,
    required this.antiSpoofPassed,
    required this.rppgHr,
    required this.rppgPassed,
    required this.rppgSampleCount,
    required this.rppgDurationMs,
  });

  // Average MiniFASNet liveness confidence (0–1), or null when no frames were scored.
  final double? antiSpoofScore;

  // True when [antiSpoofScore] meets the minimum threshold and enough frames were sampled.
  final bool antiSpoofPassed;

  // Estimated heart rate in BPM derived from rPPG, or null when the signal was too short.
  final double? rppgHr;

  // True when [rppgHr] is within the physiologically plausible range (45–110 BPM).
  final bool rppgPassed;

  // Number of BVP samples used for heart rate estimation.
  final int rppgSampleCount;

  // Wall-clock duration covered by the rPPG samples in milliseconds.
  final int rppgDurationMs;
}

// Face-match result returned by the match worker.
class WorkerMatchResult {
  const WorkerMatchResult({required this.score});

  // Cosine similarity between the NFC embedding and the selfie embedding (0–1).
  final double score;
}
