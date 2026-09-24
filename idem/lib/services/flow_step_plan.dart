import 'proofing_session_client.dart';

/// How many "X of N" screens a session will actually show, and which number
/// each stage gets — computed once from [ProofingSessionInfo.steps] so every
/// screen's step badge reflects what THIS session's flow actually does,
/// rather than vcmrtd's fixed default sequence.
///
/// Steps are treated as an unordered "which capabilities this flow needs"
/// set, not a literal display order — identity-proofing-service's own
/// flow.Validate doesn't check array order either, only presence/absence
/// (confirmed with that service directly). Numbering always follows the
/// fixed technical precedence document_capture -> nfc_read ->
/// face_verification -> result, since that's the order the underlying data
/// dependencies actually require (nfc_read needs document_capture's MRZ;
/// face_match needs either nfc_read's DG2 or a supplied referencePhoto).
///
/// document_capture is NOT guaranteed present — a flow can be e.g.
/// `["selfie", "face_match"]` alone (pure biometric verification against a
/// relying-party-supplied reference photo, no document scan at all). The
/// only hard dependency the server enforces is nfc_read requiring
/// document_capture; every other combination, including document_capture's
/// own absence, is legitimate.
///
/// A flow has no separate result step: its last capture step also submits
/// the session (routing.dart's _submitProofingSession), so a flow where this
/// app does one step shows "1 of 1". The document data screen still shown
/// after a chip read when the browser does the face step reuses the last
/// step's number ([resultStepNumber] == [totalSteps]).
///
/// Null steps (no pinned session, or one created without a flow) always
/// produces the unchanged 4-step default: document_capture, nfc_read,
/// face_verification, result — matching every screen's previous hard-coded
/// numbering exactly, so normal (non-QR) app usage is unaffected.
class FlowStepPlan {
  final int totalSteps;
  final int? documentCaptureStepNumber;
  final int? nfcReadStepNumber;
  final int? faceVerificationStepNumber;
  final int resultStepNumber;

  const FlowStepPlan._({
    required this.totalSteps,
    required this.documentCaptureStepNumber,
    required this.nfcReadStepNumber,
    required this.faceVerificationStepNumber,
    required this.resultStepNumber,
  });

  static const FlowStepPlan defaultPlan = FlowStepPlan._(
    totalSteps: 4,
    documentCaptureStepNumber: 1,
    nfcReadStepNumber: 2,
    faceVerificationStepNumber: 3,
    resultStepNumber: 4,
  );

  /// [selfieLocation] mirrors [ProofingSessionInfo.selfieLocation] — when
  /// it's "browser", the face-verification stage doesn't count as one of
  /// THIS APP's own steps at all, even if [steps] lists it: vcmrtd never
  /// shows a screen for it in that case (see [nativeFaceVerificationRequested],
  /// routing.dart's /nfc_reading), so counting it would show e.g. "step 3 of
  /// 4" with no screen ever reaching step 3 - the badge would promise a step
  /// that never happens. Defaults to "native" so every existing caller that
  /// doesn't pass this (i.e. every call site before this parameter existed)
  /// keeps counting it, matching vcmrtd's own default performer.
  factory FlowStepPlan.fromSteps(List<String>? steps, {String selfieLocation = 'native'}) {
    if (steps == null) return defaultPlan;

    var next = 1;
    final documentCaptureStepNumber = steps.contains(stepDocumentCapture) ? next++ : null;
    final nfcReadStepNumber = steps.contains(stepNfcRead) ? next++ : null;
    final faceVerificationStepNumber = nativeFaceVerificationRequested(steps, selfieLocation) ? next++ : null;
    // The last step submits; a degenerate flow with none still counts one.
    final resultStepNumber = next > 1 ? next - 1 : 1;

    return FlowStepPlan._(
      totalSteps: resultStepNumber,
      documentCaptureStepNumber: documentCaptureStepNumber,
      nfcReadStepNumber: nfcReadStepNumber,
      faceVerificationStepNumber: faceVerificationStepNumber,
      resultStepNumber: resultStepNumber,
    );
  }
}
