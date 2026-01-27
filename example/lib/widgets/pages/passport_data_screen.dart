import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/return_to_web.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

import '../common/issuance_result_dialogs.dart';
import 'data_screen_widgets/verify_result.dart';

class PassportDataScreen extends ConsumerStatefulWidget {
  final PassportData passport;
  final RawDocumentData passportDataResult;
  final VoidCallback onBackPressed;

  const PassportDataScreen({
    super.key,
    required this.passport,
    required this.onBackPressed,
    required this.passportDataResult,
  });

  @override
  ConsumerState<PassportDataScreen> createState() => _PassportDataScreenState();
}

class _PassportDataScreenState extends ConsumerState<PassportDataScreen> {
  VerificationResponse? _verificationResponse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport Data'),
        leading: IconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBackPressed),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.passportDataResult.sessionId != null)
                WebBanner(sessionId: widget.passportDataResult.sessionId!),
              PersonalDataSection(passport: widget.passport),
              const SizedBox(height: 16),
              _buildSelfieCheckButton(),
              const SizedBox(height: 20),
              SecurityContent(passport: widget.passport),
              const SizedBox(height: 20),
              if (widget.passportDataResult.sessionId != null) ...[
                const SizedBox(height: 20),
                if (_verificationResponse == null)
                  ReturnToWebSection(
                    isReturningToIssue: false,
                    isReturningToVerify: false,
                    onIssuePressed: _returnToIssue,
                    onVerifyPressed: _verifyPassport,
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

  Widget _buildSelfieCheckButton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/selfie_check', extra: widget.passport.photoImageData);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.face,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selfie Check',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compare your face with the document photo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPassport() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      final result = await issuer.verifyPassport(widget.passportDataResult);
      setState(() {
        _verificationResponse = result;
      });
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  Future<void> _returnToIssue() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      final response = await issuer.startIrmaIssuanceSession(widget.passportDataResult, DocumentType.passport);
      await launchUrl(response.toUniversalLink(), mode: LaunchMode.externalApplication);
      _showReturnSuccessDialog();
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  void _showReturnSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
        title: const Text('Success!'),
        content: const Text(
          'Your passport data has been securely transmitted to the web application. '
          'You can now close this app or scan another passport.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onBackPressed();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showReturnErrorDialog(String error) {
    DialogHelpers.showErrorDialog(
      context: context,
      title: 'Return Failed',
      message: 'Failed to return to web application:',
      error: error,
      onRetry: _returnToIssue,
    );
  }
}
