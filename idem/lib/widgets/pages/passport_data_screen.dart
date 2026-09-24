import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_chip_evidence.dart';

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/proofing_result_submission.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

class PassportDataScreen extends ConsumerStatefulWidget {
  final DocumentData document;
  final RawDocumentData passportDataResult;
  final VoidCallback onBackPressed;
  final DocumentType documentType;
  final FaceVerificationOutcome? faceVerification;

  /// Set when every step was already sent to the session as it completed -
  /// see [DocumentWalletOrSubmitSection.submittedTo].
  final String? submittedTo;
  final bool browserFaceStep;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always the last, step 4, there) so any caller not passing
  /// these explicitly keeps today's behaviour; routing.dart passes a
  /// session's actual FlowStepPlan values when a QR/deep-link flow governs
  /// the numbering.
  final int stepNumber;
  final int totalSteps;

  const PassportDataScreen({
    super.key,
    required this.document,
    required this.onBackPressed,
    required this.passportDataResult,
    this.documentType = DocumentType.passport,
    this.faceVerification,
    this.submittedTo,
    this.browserFaceStep = false,
    this.stepNumber = 4,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<PassportDataScreen> createState() => _PassportDataScreenState();
}

class _PassportDataScreenState extends ConsumerState<PassportDataScreen>
    with ProofingResultSubmission<PassportDataScreen> {
  @override
  Widget build(BuildContext context) {
    final activeProofingSession = ref.watch(activeProofingSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.passportDataResult.sessionId != null)
                      WebBanner(sessionId: widget.passportDataResult.sessionId!),
                    PersonalDataSection(passport: widget.document as PassportData),
                    const SizedBox(height: 20),
                    SecurityContent(passport: widget.document as PassportData),
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

  Widget _buildTopBar(BuildContext context) => StepBadgeTopBar(
    icon: Icons.arrow_back,
    onBack: widget.onBackPressed,
    current: widget.stepNumber,
    total: widget.totalSteps,
    label: '${widget.documentType.displayName} Data',
  );

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.document, widget.documentType));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) {
    final evidence = ProofingChipEvidence.from(widget.document, widget.passportDataResult, widget.documentType);
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
