import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/proofing_session_provider.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/services/face_verification_outcome.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

import '../common/issuance_result_dialogs.dart';

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

class _PassportDataScreenState extends ConsumerState<PassportDataScreen> {
  bool _submittingToProofingSession = false;

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
                    // A document scanned to fulfil a relying party's proofing
                    // session is reported back to them, not kept in the
                    // local wallet — so this and the submit section below
                    // are mutually exclusive on activeProofingSession.
                    if (activeProofingSession == null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _addToWallet,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Add to Wallet'),
                      ),
                    ],
                    if (activeProofingSession != null) ...[
                      const SizedBox(height: 20),
                      SubmitToProofingSessionSection(
                        relyingParty: activeProofingSession.info.relyingParty,
                        isSubmitting: _submittingToProofingSession,
                        onSubmit: () => _submitToProofingSession(activeProofingSession),
                      ),
                    ],
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
    current: 4,
    total: 4,
    label: '${widget.documentType.displayName} Data',
  );

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.document, widget.documentType));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) async {
    setState(() => _submittingToProofingSession = true);
    try {
      final passport = widget.document as PassportData;
      final outcome = widget.faceVerification;
      final packageInfo = await PackageInfo.fromPlatform();
      await const ProofingSessionClient().submitResult(
        session.ref,
        status: 'approved',
        requestedAttributes: session.info.requestedAttributes,
        document: ProofingDocumentInfo.fromPassportData(passport),
        photo: ProofingPhotoInfo.fromImage(passport.photoImageData, passport.photoImageType),
        selfie: outcome?.selfieImageBytes != null ? ProofingPhotoInfo.fromSelfie(outcome!.selfieImageBytes!) : null,
        mrtdEvidence: ProofingMrtdEvidence.fromRawDocumentData(
          widget.passportDataResult,
          aaKeyDataGroup: 'DG15',
          documentType: 'icao',
        ),
        biometrics: ProofingBiometricsInfo(
          faceMatchScore: outcome?.matchScore,
          faceVerified: outcome != null ? true : null,
          livenessResult: outcome == null ? 'not_performed' : (outcome.livenessPassed ? 'passed' : 'failed'),
          engine: outcome?.engine,
        ),
        device: ProofingDeviceInfo(
          appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
          devicePlatform: Platform.operatingSystem,
        ),
      );
      ref.read(activeProofingSessionProvider.notifier).set(null);
      if (!mounted) return;
      DialogHelpers.showSuccessDialog(
        context: context,
        title: 'Submitted',
        message: 'Your document identity and face verification result were sent to ${session.info.relyingParty}.',
        onContinue: () {
          Navigator.of(context).pop();
          widget.onBackPressed();
        },
      );
    } catch (e) {
      if (!mounted) return;
      DialogHelpers.showErrorDialog(
        context: context,
        title: 'Submit Failed',
        message: 'Failed to submit the result to the relying party:',
        error: e.toString(),
        onRetry: () => _submitToProofingSession(session),
      );
    } finally {
      if (mounted) setState(() => _submittingToProofingSession = false);
    }
  }
}
