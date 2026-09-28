import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/data_screen_widgets/profile_picture.dart';

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

  const PassportDataScreen({
    super.key,
    required this.document,
    required this.onBackPressed,
    required this.passportDataResult,
    this.documentType = DocumentType.passport,
    this.faceVerification,
  });

  @override
  ConsumerState<PassportDataScreen> createState() => _PassportDataScreenState();
}

class _PassportDataScreenState extends ConsumerState<PassportDataScreen>
    with ProofingResultSubmission<PassportDataScreen> {
  @override
  Widget build(BuildContext context) {
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

  /// Guided layout: a success header, the key details in one card, and the
  /// share or add-to-wallet action. Says the chip was read rather than that
  /// it's genuine: authenticity is checked by the backend, not on the phone.
  Widget _buildGuided(GuidedStyle g, ActiveProofingSession? session) {
    final passport = widget.document as PassportData;
    final mrz = passport.mrz;
    final docName = widget.documentType == DocumentType.identityCard ? 'ID card' : 'passport';
    final faceMatched = widget.faceVerification != null;
    final date = DateFormat('d MMM y');

    Widget detail(String label, String value, {bool mono = false, bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: g.subtleBorder)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: g.bodyText)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
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
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.passportDataResult.sessionId != null) ...[
                        WebBanner(sessionId: widget.passportDataResult.sessionId!),
                        const SizedBox(height: 16),
                      ],
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: g.success,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: g.successBright.withValues(alpha: 0.2), spreadRadius: 10)],
                          ),
                          child: const Icon(Icons.check, size: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        faceMatched ? 'Identity verified' : 'Document read',
                        textAlign: TextAlign.center,
                        style: g.heading(26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        faceMatched
                            ? 'We read your $docName chip and your face matches the photo on it.'
                            : 'We read your $docName chip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
                      ),
                      const SizedBox(height: 28),
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
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 56,
                                      height: 70,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: ProfilePictureWidget(
                                          imageData: passport.photoImageData,
                                          imageType: passport.photoImageType,
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
                                          _titleCase(passport.displayName),
                                          style: g.heading(17, color: Colors.white),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${widget.documentType == DocumentType.identityCard ? 'ID card' : 'Passport'} · ${mrz.country}',
                                          style: TextStyle(fontSize: 13, color: g.placeholder),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            detail('Date of birth', date.format(mrz.dateOfBirth)),
                            detail('Nationality', mrz.nationality),
                            detail('Document number', mrz.documentNumber, mono: true),
                            detail('Valid until', date.format(mrz.dateOfExpiry), last: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          badge(Icons.memory, 'Chip read'),
                          if (faceMatched) ...[const SizedBox(width: 10), badge(Icons.person_outline, 'Face matched')],
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
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
    current: 4,
    total: 4,
    label: '${widget.documentType.displayName} Data',
  );

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.document, widget.documentType));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) {
    final passport = widget.document as PassportData;
    return submitProofingResult(
      session: session,
      document: ProofingDocumentInfo.fromPassportData(passport),
      photo: ProofingPhotoInfo.fromImage(passport.photoImageData, passport.photoImageType),
      mrtdEvidence: ProofingMrtdEvidence.fromRawDocumentData(
        widget.passportDataResult,
        aaKeyDataGroup: 'DG15',
        documentType: 'icao',
      ),
      faceVerification: widget.faceVerification,
      onBackPressed: widget.onBackPressed,
    );
  }
}

/// "ANNA MARIA ERIKSSON" → "Anna Maria Eriksson"; chips store names in capitals.
String _titleCase(String name) =>
    name.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
