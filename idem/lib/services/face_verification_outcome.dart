import 'dart:typed_data';

/// What actually happened during face verification — which engine ran, which
/// liveness mode (when applicable), the DG2 match score, whether liveness
/// passed — carried from FlutterFaceVerificationScreen/IrisFaceVerificationScreen
/// through routing.dart to the document data screen, so it can be reported to
/// an identity-proofing session (see ProofingBiometricsInfo in
/// proofing_session_client.dart). Reaching the data screen already means this
/// outcome passed; there's no failed variant to represent.
class FaceVerificationOutcome {
  final String engine; // "on_device" | "iris"
  final String? livenessMode; // "passive" | "active"; null for the Iris SDK, which has no in-app mode choice
  final double? matchScore; // DG2 vs. live face, 0..1; null for the Iris SDK, which doesn't expose one
  final bool
  livenessPassed; // this will be passed or null, casue if failed user could retry, might add a retry count in the future
  // The live selfie captured during this verification (VerificationResult.liveFace
  // for the on-device engine, IrisVerificationResult.face for the Iris SDK), so
  // it can be submitted to the identity-proofing session alongside the DG2
  // photo — see ProofingPhotoInfo in proofing_session_client.dart. Null when
  // the engine didn't capture one.
  final Uint8List? selfieImageBytes;

  const FaceVerificationOutcome({
    required this.engine,
    required this.livenessPassed,
    this.livenessMode,
    this.matchScore,
    this.selfieImageBytes,
  });
}
