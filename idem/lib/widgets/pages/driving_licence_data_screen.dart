import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_chip_evidence.dart';
import '../../widgets/pages/data_screen_widgets/proofing_result_submission.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

class DrivingLicenceDataScreen extends ConsumerStatefulWidget {
  final DrivingLicenceData drivingLicence;
  final RawDocumentData drivingLicenceDataResult;
  final VoidCallback onBackPressed;

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

  const DrivingLicenceDataScreen({
    super.key,
    required this.drivingLicence,
    required this.drivingLicenceDataResult,
    required this.onBackPressed,
    this.faceVerification,
    this.submittedTo,
    this.browserFaceStep = false,
    this.stepNumber = 4,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<DrivingLicenceDataScreen> createState() => _DrivingLicenceDataScreenState();
}

class _DrivingLicenceDataScreenState extends ConsumerState<DrivingLicenceDataScreen>
    with ProofingResultSubmission<DrivingLicenceDataScreen> {
  @override
  Widget build(BuildContext context) {
    final imageData = widget.drivingLicence.photoImageData;
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
                    if (widget.drivingLicenceDataResult.sessionId != null)
                      WebBanner(sessionId: widget.drivingLicenceDataResult.sessionId!),
                    _buildPhotoSection(imageData),
                    const SizedBox(height: 24),
                    _buildSection('Personal Information', [
                      _buildDataRow('Surname', widget.drivingLicence.holderSurname),
                      _buildDataRow('Other Names', widget.drivingLicence.holderOtherName),
                      _buildDataRow('Date of Birth', _formatDate(widget.drivingLicence.dateOfBirth)),
                      _buildDataRow('Place of Birth', widget.drivingLicence.placeOfBirth),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Document Information', [
                      _buildDataRow('Document Number', widget.drivingLicence.documentNumber),
                      _buildDataRow('Issuing Member State', widget.drivingLicence.issuingMemberState),
                      _buildDataRow('Issuing Authority', widget.drivingLicence.issuingAuthority),
                      _buildDataRow('Date of Issue', _formatDate(widget.drivingLicence.dateOfIssue)),
                      _buildDataRow('Date of Expiry', _formatDate(widget.drivingLicence.dateOfExpiry)),
                    ]),
                    if (widget.drivingLicence.categories.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildCategoriesSection(widget.drivingLicence.categories),
                    ],
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
    label: 'Driving Licence Data',
  );

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.drivingLicence, DocumentType.drivingLicence));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) {
    final evidence = ProofingChipEvidence.from(
      widget.drivingLicence,
      widget.drivingLicenceDataResult,
      DocumentType.drivingLicence,
    );
    return submitProofingResult(
      session: session,
      document: evidence.document,
      photo: evidence.photo,
      mrtdEvidence: evidence.mrtdEvidence,
      faceVerification: widget.faceVerification,
      onBackPressed: widget.onBackPressed,
    );
  }

  Widget _buildPhotoSection(Uint8List imageData) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.systemGrey4, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            imageData,
            width: 200,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 250,
                color: CupertinoColors.systemGrey6,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.photo, size: 48, color: CupertinoColors.systemGrey),
                      SizedBox(height: 8),
                      Text('Unable to load photo', style: TextStyle(color: CupertinoColors.systemGrey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCategoriesSection(List<DrivingLicenceCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...categories.map((cat) => _buildCategoryCard(cat)),
      ],
    );
  }

  Widget _buildCategoryCard(DrivingLicenceCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(width: 8),
              Text(
                category.category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataRow('Date of issue', category.dateOfIssue),
          _buildDataRow('Date of expiry', category.dateOfExpiry),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
            ),
          ),
          Expanded(child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  String? _formatDate(String? date) {
    if (date == null || date.length != 8) return date;
    final day = date.substring(0, 2);
    final month = date.substring(2, 4);
    final year = date.substring(4, 8);
    return '$day/$month/$year';
  }
}
