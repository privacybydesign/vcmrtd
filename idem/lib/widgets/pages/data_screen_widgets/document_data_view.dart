import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_chip_evidence.dart';

import 'proofing_result_submission.dart';
import 'web_banner.dart';

/// The page every document data screen (passport, driving licence) shares:
/// the step badge, the document's own [children], and adding the chip read
/// to the wallet or submitting it to the pinned proofing session.
class DocumentDataView extends ConsumerStatefulWidget {
  final String title;
  final DocumentData document;
  final RawDocumentData rawDocument;
  final DocumentType documentType;
  final FaceVerificationOutcome? faceVerification;

  /// Set when every step was already sent to the session as it completed -
  /// see [DocumentWalletOrSubmitSection.submittedTo].
  final String? submittedTo;
  final bool browserFaceStep;
  final VoidCallback onBackPressed;
  final int stepNumber;
  final int totalSteps;
  final List<Widget> children;

  const DocumentDataView({
    super.key,
    required this.title,
    required this.document,
    required this.rawDocument,
    required this.documentType,
    required this.faceVerification,
    required this.submittedTo,
    required this.browserFaceStep,
    required this.onBackPressed,
    required this.stepNumber,
    required this.totalSteps,
    required this.children,
  });

  @override
  ConsumerState<DocumentDataView> createState() => _DocumentDataViewState();
}

class _DocumentDataViewState extends ConsumerState<DocumentDataView> with ProofingResultSubmission<DocumentDataView> {
  @override
  Widget build(BuildContext context) {
    final activeProofingSession = ref.watch(activeProofingSessionProvider);
    final sessionId = widget.rawDocument.sessionId;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepBadgeTopBar(
              icon: Icons.arrow_back,
              onBack: widget.onBackPressed,
              current: widget.stepNumber,
              total: widget.totalSteps,
              label: widget.title,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sessionId != null) WebBanner(sessionId: sessionId),
                    ...widget.children,
                    DocumentWalletOrSubmitSection(
                      activeProofingSession: activeProofingSession,
                      isSubmitting: submittingToProofingSession,
                      onAddToWallet: _addToWallet,
                      onSubmit: () => _submitToProofingSession(activeProofingSession!),
                      submittedTo: widget.submittedTo,
                      browserFaceStep: widget.browserFaceStep,
                      onDone: widget.onBackPressed,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.document, widget.documentType));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) {
    final evidence = ProofingChipEvidence.from(widget.document, widget.rawDocument, widget.documentType);
    return submitProofingResult(
      session: session,
      document: evidence.document,
      photo: evidence.photo,
      mrtdEvidence: evidence.mrtdEvidence,
      faceVerification: widget.faceVerification,
      onBackPressed: widget.onBackPressed,
    );
  }
}
