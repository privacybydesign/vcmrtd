import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/data_screen_widgets/profile_picture.dart';
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
  /// Guided layout: keep the document after sharing it (see [GuidedSaveForNextTime]).
  bool _saveForNextTime = false;

  @override
  Widget build(BuildContext context) {
    final imageData = widget.drivingLicence.photoImageData;
    final activeProofingSession = ref.watch(activeProofingSessionProvider);
    final guided = context.guided;
    if (guided != null) return _buildGuided(guided, activeProofingSession);

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
                    _buildSection(context.l10n.docPersonalInformation, [
                      _buildDataRow(context.l10n.docSurname, widget.drivingLicence.holderSurname),
                      _buildDataRow(context.l10n.docOtherNames, widget.drivingLicence.holderOtherName),
                      _buildDataRow(context.l10n.docDateOfBirth, _formatDate(widget.drivingLicence.dateOfBirth)),
                      _buildDataRow(context.l10n.docPlaceOfBirth, widget.drivingLicence.placeOfBirth),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection(context.l10n.docDocumentInformation, [
                      _buildDataRow(context.l10n.docDocumentNumber, widget.drivingLicence.documentNumber),
                      _buildDataRow(context.l10n.docIssuingMemberState, widget.drivingLicence.issuingMemberState),
                      _buildDataRow(context.l10n.docIssuingAuthority, widget.drivingLicence.issuingAuthority),
                      _buildDataRow(context.l10n.docDateOfIssue, _formatDate(widget.drivingLicence.dateOfIssue)),
                      _buildDataRow(context.l10n.docDateOfExpiry, _formatDate(widget.drivingLicence.dateOfExpiry)),
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

  /// Guided layout, as for passports (see PassportDataScreen), plus the
  /// licence categories.
  Widget _buildGuided(GuidedStyle g, ActiveProofingSession? session) {
    final licence = widget.drivingLicence;
    final faceMatched = widget.faceVerification != null;
    final name = '${licence.holderOtherName} ${licence.holderSurname}'.trim();

    Widget detail(String label, String? value, {bool mono = false, bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: g.subtleBorder)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: g.bodyText)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value ?? '—',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: mono ? 14 : 15,
                fontWeight: FontWeight.w700,
                color: g.ink,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
    Widget badge(IconData icon, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: g.successTint, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: g.successText),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: g.successText),
              ),
            ),
          ],
        ),
      ),
    );

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.drivingLicenceDataResult.sessionId != null) ...[
                        WebBanner(sessionId: widget.drivingLicenceDataResult.sessionId!),
                        const SizedBox(height: 16),
                      ],
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: g.success,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: g.successBright.withValues(alpha: 0.2), spreadRadius: 9)],
                          ),
                          child: const Icon(Icons.check, size: 32, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        faceMatched ? 'Identity verified' : 'Driving licence read',
                        textAlign: TextAlign.center,
                        style: g.heading(24),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        faceMatched
                            ? 'We read your driving licence chip and your face matches the photo on it.'
                            : 'We read your driving licence chip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: g.subtleBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: g.ink,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 60,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: ProfilePictureWidget(
                                          imageData: licence.photoImageData,
                                          imageType: licence.photoImageType,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isEmpty ? 'Driving licence' : name,
                                          style: g.heading(17, color: Colors.white),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Driving licence · ${licence.issuingMemberState}',
                                          style: TextStyle(fontSize: 13, color: g.placeholder),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            detail('Date of birth', _formatDate(licence.dateOfBirth)),
                            detail('Place of birth', licence.placeOfBirth),
                            detail('Document number', licence.documentNumber, mono: true),
                            detail('Issued by', licence.issuingAuthority),
                            detail('Valid until', _formatDate(licence.dateOfExpiry), last: true),
                          ],
                        ),
                      ),
                      if (licence.categories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Categories',
                            style: g.heading(15, weight: FontWeight.w600, color: g.slate),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in licence.categories)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: g.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(category.category, style: g.heading(15)),
                                    Text(
                                      'until ${_formatDate(category.dateOfExpiry)}',
                                      style: TextStyle(fontSize: 12, color: g.bodyText),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          badge(Icons.memory, 'Chip read'),
                          if (faceMatched) ...[const SizedBox(width: 10), badge(Icons.person_outline, 'Face matched')],
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      if (session != null) ...[
                        GuidedSaveForNextTime(
                          value: _saveForNextTime,
                          onChanged: (value) => setState(() => _saveForNextTime = value),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (session != null)
                        GuidedButton(
                          label: submittingToProofingSession ? 'Sharing…' : 'Share with ${session.info.relyingParty}',
                          onPressed: submittingToProofingSession ? null : () => _submitToProofingSession(session),
                        )
                      else
                        GuidedButton(label: 'Add to wallet', onPressed: _addToWallet),
                      const SizedBox(height: 12),
                      GuidedButton(label: 'Done', secondary: true, onPressed: widget.onBackPressed),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => StepBadgeTopBar(
    icon: Icons.arrow_back,
    onBack: widget.onBackPressed,
    current: widget.stepNumber,
    total: widget.totalSteps,
    label: context.l10n.docDrivingLicenceDataTitle,
  );

  void _addToWallet() {
    ref
        .read(walletProvider.notifier)
        .add(
          WalletCard.fromDocument(
            widget.drivingLicence,
            DocumentType.drivingLicence,
            rawData: widget.drivingLicenceDataResult,
          ),
        );
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
      onBackPressed: () {
        if (_saveForNextTime) {
          ref
              .read(walletProvider.notifier)
              .add(
                WalletCard.fromDocument(
                  widget.drivingLicence,
                  DocumentType.drivingLicence,
                  rawData: widget.drivingLicenceDataResult,
                ),
              );
        }
        widget.onBackPressed();
      },
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.photo, size: 48, color: CupertinoColors.systemGrey),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.docUnableToLoadPhoto,
                        style: const TextStyle(color: CupertinoColors.systemGrey),
                      ),
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
        Text(context.l10n.docCategories, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              Text(
                context.l10n.docCategory,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(width: 8),
              Text(
                category.category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataRow(context.l10n.docCategoryDateOfIssue, category.dateOfIssue),
          _buildDataRow(context.l10n.docCategoryDateOfExpiry, category.dateOfExpiry),
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
          Expanded(child: Text(value ?? context.l10n.docNotAvailable, style: const TextStyle(fontSize: 16))),
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
