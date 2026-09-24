import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_chip_evidence.dart';
import 'package:idem/services/proofing_session_client.dart';

import '../../common/issuance_result_dialogs.dart';
import 'submit_to_proofing_session.dart';

/// Shared by [PassportDataScreen]/[DrivingLicenceDataScreen]'s states: both
/// report a scanned document back to a pinned identity-proofing session the
/// same way, differing only in how [ProofingDocumentInfo]/[ProofingPhotoInfo]/
/// [ProofingMrtdEvidence] are built for their respective document type — see
/// each screen's `_submitToProofingSession`.
///
/// This is the single-shot `POST .../result`, for sessions without a flow.
/// A flow session sends each step as it completes instead (routing.dart's
/// _submitNfcStep/_submitFaceStep), and its last step submits the session
/// automatically (routing.dart's _submitProofingSession).
mixin ProofingResultSubmission<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool submittingToProofingSession = false;

  Future<void> submitProofingResult({
    required ActiveProofingSession session,
    // Null when the flow's steps don't include "document_capture" at all
    // (e.g. a selfie/face_match-only flow verifying against a supplied
    // referencePhoto, no document scan) - see DocumentCaptureOnlyResultScreen.
    ProofingDocumentInfo? document,
    // Null for a document_capture-only session (no chip read happened, so
    // there's no DG2 photo and no efSod/dataGroups to report as evidence) -
    // see DocumentCaptureOnlyResultScreen.
    ProofingPhotoInfo? photo,
    ProofingMrtdEvidence? mrtdEvidence,
    required FaceVerificationOutcome? faceVerification,
    required VoidCallback onBackPressed,
  }) async {
    setState(() => submittingToProofingSession = true);
    try {
      final device = await currentProofingDeviceInfo();
      final outcome = faceVerification;
      await ref
          .read(proofingSessionClientProvider)
          .submitResult(
            session.ref,
            status: 'approved',
            requestedAttributes: session.info.requestedAttributes,
            document: document,
            photo: photo,
            selfie: outcome?.selfieImageBytes != null ? ProofingPhotoInfo.fromSelfie(outcome!.selfieImageBytes!) : null,
            mrtdEvidence: mrtdEvidence,
            biometrics: ProofingBiometricsInfo(
              faceMatchScore: outcome?.matchScore,
              faceVerified: outcome != null ? true : null,
              livenessResult: outcome == null ? 'not_performed' : (outcome.livenessPassed ? 'passed' : 'failed'),
              engine: outcome?.engine,
            ),
            device: device,
          );
      ref.read(activeProofingSessionProvider.notifier).set(null);
      if (!mounted) return;
      DialogHelpers.showSuccessDialog(
        context: context,
        title: 'Submitted',
        message: faceVerification == null
            ? 'Your document identity was sent to ${session.info.relyingParty}.'
            : 'Your document identity and face verification result were sent to ${session.info.relyingParty}.',
        onContinue: () {
          Navigator.of(context).pop();
          onBackPressed();
        },
      );
    } catch (e) {
      // Refused because this device lost the session (handed over, expired,
      // already complete): the app ends the verification with that message.
      if (reportIfProofingAccessLost(ProviderScope.containerOf(context), session.ref, e)) return;
      if (!mounted) return;
      DialogHelpers.showErrorDialog(
        context: context,
        title: 'Submit Failed',
        message: 'Failed to submit the result to the relying party:',
        error: e.toString(),
        onRetry: () => submitProofingResult(
          session: session,
          document: document,
          photo: photo,
          mrtdEvidence: mrtdEvidence,
          faceVerification: faceVerification,
          onBackPressed: onBackPressed,
        ),
      );
    } finally {
      if (mounted) setState(() => submittingToProofingSession = false);
    }
  }
}

/// The mutually-exclusive "Add to Wallet" / "Submit to $relyingParty" action
/// shown at the end of a document data screen — see
/// [ProofingResultSubmission] for why this is mutually exclusive on
/// [activeProofingSession].
class DocumentWalletOrSubmitSection extends StatelessWidget {
  final ActiveProofingSession? activeProofingSession;
  final bool isSubmitting;
  final VoidCallback onAddToWallet;
  final VoidCallback onSubmit;

  /// The relying party every step was already sent to as it completed (see
  /// routing.dart's _submitNfcStep), in which case this only confirms that.
  final String? submittedTo;

  /// Whether the browser still does the face step after that.
  final bool browserFaceStep;
  final VoidCallback? onDone;

  const DocumentWalletOrSubmitSection({
    super.key,
    required this.activeProofingSession,
    required this.isSubmitting,
    required this.onAddToWallet,
    required this.onSubmit,
    this.submittedTo,
    this.browserFaceStep = false,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final session = activeProofingSession;
    final submittedTo = this.submittedTo;
    if (submittedTo != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SubmittedToProofingSessionSection(
          relyingParty: submittedTo,
          browserFaceStep: browserFaceStep,
          onDone: onDone,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: session == null
          ? ElevatedButton.icon(
              onPressed: onAddToWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Add to Wallet'),
            )
          : SubmitToProofingSessionSection(
              relyingParty: session.info.relyingParty,
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
            ),
    );
  }
}
