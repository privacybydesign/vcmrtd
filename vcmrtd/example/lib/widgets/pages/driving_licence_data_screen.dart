import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/proofing_session_provider.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/services/face_verification_outcome.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';
import '../../widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import '../common/issuance_result_dialogs.dart';

class DrivingLicenceDataScreen extends ConsumerStatefulWidget {
  final DrivingLicenceData drivingLicence;
  final RawDocumentData drivingLicenceDataResult;
  final VoidCallback onBackPressed;

  final FaceVerificationOutcome? faceVerification;

  const DrivingLicenceDataScreen({
    super.key,
    required this.drivingLicence,
    required this.drivingLicenceDataResult,
    required this.onBackPressed,
    this.faceVerification,
  });

  @override
  ConsumerState<DrivingLicenceDataScreen> createState() => _DrivingLicenceDataScreenState();
}

class _DrivingLicenceDataScreenState extends ConsumerState<DrivingLicenceDataScreen> {
  bool _submittingToProofingSession = false;

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
    label: 'Driving Licence Data',
  );

  void _addToWallet() {
    ref.read(walletProvider.notifier).add(WalletCard.fromDocument(widget.drivingLicence, DocumentType.drivingLicence));
    widget.onBackPressed();
  }

  Future<void> _submitToProofingSession(ActiveProofingSession session) async {
    setState(() => _submittingToProofingSession = true);
    try {
      final outcome = widget.faceVerification;
      final packageInfo = await PackageInfo.fromPlatform();
      await const ProofingSessionClient().submitResult(
        session.ref,
        status: 'approved',
        requestedAttributes: session.info.requestedAttributes,
        document: ProofingDocumentInfo.fromDrivingLicenceData(widget.drivingLicence),
        photo: ProofingPhotoInfo.fromImage(widget.drivingLicence.photoImageData, widget.drivingLicence.photoImageType),
        selfie: outcome?.selfieImageBytes != null ? ProofingPhotoInfo.fromSelfie(outcome!.selfieImageBytes!) : null,
        mrtdEvidence: ProofingMrtdEvidence.fromRawDocumentData(
          widget.drivingLicenceDataResult,
          aaKeyDataGroup: 'DG13',
          documentType: 'eu_driving_licence',
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
