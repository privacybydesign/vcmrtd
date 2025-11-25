import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';
import '../../widgets/pages/data_screen_widgets/return_to_web.dart';
import '../../widgets/pages/data_screen_widgets/verify_result.dart';
import '../common/issuance-result-dialogs.dart';

class DrivingLicenceDataScreen extends ConsumerStatefulWidget {
  final DrivingLicenceData drivingLicence;
  final RawDocumentData drivingLicenceDataResult;
  final VoidCallback onBackPressed;

  const DrivingLicenceDataScreen({
    super.key,
    required this.drivingLicence,
    required this.drivingLicenceDataResult,
    required this.onBackPressed,
  });

  @override
  ConsumerState<DrivingLicenceDataScreen> createState() => _DrivingLicenceDataScreenState();
}

class _DrivingLicenceDataScreenState extends ConsumerState<DrivingLicenceDataScreen> {
  VerificationResponse? _verificationResponse;

  @override
  Widget build(BuildContext context) {
    final imageData = widget.drivingLicence.photoImageData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving Licence Data'),
        leading: IconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBackPressed),
      ),
      body: SafeArea(
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
              if (widget.drivingLicenceDataResult.sessionId != null) ...[
                const SizedBox(height: 20),
                if (_verificationResponse == null)
                  ReturnToWebSection(
                    isReturningToIssue: false,
                    isReturningToVerify: false,
                    onIssuePressed: _issueDrivingLicence,
                    onVerifyPressed: _verifyDrivingLicence,
                  )
                else ...[
                  const SizedBox(height: 20),
                  VerifyResultSection(
                    isExpired: _verificationResponse!.isExpired,
                    authenticChip: _verificationResponse!.authenticChip,
                    authenticContent: _verificationResponse!.authenticContent,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyDrivingLicence() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      final result = await issuer.verifyDrivingLicence(widget.drivingLicenceDataResult);
      setState(() {
        _verificationResponse = result;
      });
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  Future<void> _issueDrivingLicence() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      final response = await issuer.startIrmaIssuanceSession(widget.drivingLicenceDataResult, "issue-driving-licence");
      await launchUrl(response.toUniversalLink(), mode: LaunchMode.externalApplication);
      _showReturnSuccessDialog();
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  void _showReturnSuccessDialog() {
    DialogHelpers.showSuccessDialog(
      context: context,
      title: 'Success!',
      message:
          'Your driving licence data has been securely transmitted to the web application. '
          'You can now close this app or scan another document.',
      onContinue: widget.onBackPressed,
    );
  }

  void _showReturnErrorDialog(String error) {
    DialogHelpers.showErrorDialog(
      context: context,
      title: 'Verification Failed',
      message: 'Failed to verify driving licence:',
      error: error,
      onRetry: _verifyDrivingLicence,
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
