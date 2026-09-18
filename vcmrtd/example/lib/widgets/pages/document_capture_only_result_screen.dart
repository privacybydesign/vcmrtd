import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/providers/proofing_session_provider.dart';
import 'package:vcmrtdapp/services/face_verification_outcome.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';

import 'data_screen_widgets/proofing_result_submission.dart';

/// Terminal screen for a flow whose steps don't include "nfc_read" - see
/// routing.dart's _afterDocumentCaptured/_afterConsent. There's no chip read
/// (no DocumentData/RawDocumentData) to show a data-review screen for, so
/// this submits immediately instead of waiting for a "Submit" tap - matching
/// "a flow with only one step should work and return its result on its own"
/// rather than dead-ending on a screen with nothing to review.
///
/// [scannedMrz] is null when the flow's steps don't include "document_capture"
/// either — a real, supported case (e.g. `["selfie", "face_match"]` alone,
/// verifying a live selfie against a relying-party-supplied referencePhoto
/// with no document scan at all) — in which case [ProofingDocumentInfo] isn't
/// built at all, matching the server's own attrRequested "nothing means
/// nothing" rule for `document`. See [ProofingDocumentInfo.fromScannedMrz]
/// for exactly what's sent when it is present.
class DocumentCaptureOnlyResultScreen extends ConsumerStatefulWidget {
  final ActiveProofingSession session;
  final ScannedMRZ? scannedMrz;
  final FaceVerificationOutcome? faceVerification;
  final VoidCallback onBackPressed;

  const DocumentCaptureOnlyResultScreen({
    super.key,
    required this.session,
    required this.onBackPressed,
    this.scannedMrz,
    this.faceVerification,
  });

  @override
  ConsumerState<DocumentCaptureOnlyResultScreen> createState() => _DocumentCaptureOnlyResultScreenState();
}

class _DocumentCaptureOnlyResultScreenState extends ConsumerState<DocumentCaptureOnlyResultScreen>
    with ProofingResultSubmission<DocumentCaptureOnlyResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
  }

  Future<void> _submit() {
    // Guards against the (narrow but real) case where this screen is popped
    // before its first frame's post-frame callback fires - unlike every
    // other caller of submitProofingResult, which only ever fires from a
    // user's own button tap on a screen they're actively looking at, this
    // one fires automatically.
    if (!mounted) return Future.value();
    final scannedMrz = widget.scannedMrz;
    return submitProofingResult(
      session: widget.session,
      document: scannedMrz != null ? ProofingDocumentInfo.fromScannedMrz(scannedMrz) : null,
      faceVerification: widget.faceVerification,
      onBackPressed: widget.onBackPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only animates while the request is actually in flight - once it's
    // done (success dialog, or a failed-submit dialog with Retry), nothing
    // behind those dialogs should keep spinning.
    return Scaffold(
      body: Center(child: submittingToProofingSession ? const CircularProgressIndicator() : const SizedBox.shrink()),
    );
  }
}
