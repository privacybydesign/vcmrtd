import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/src/models/document.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/return_to_web.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

import 'data_screen_widgets/verify_result.dart';

class PassportDataScreen extends ConsumerStatefulWidget {
  final PassportData passport;
  final PassportDataResult passportDataResult;
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

  Future<void> _verifyPassport() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      _verificationResponse = await issuer.verifyPassport(widget.passportDataResult);
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  Future<void> _returnToIssue() async {
    final issuer = ref.read(passportIssuerProvider);

    try {
      final response = await issuer.startIrmaIssuanceSession(widget.passportDataResult);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error, color: Colors.red[600], size: 48),
        title: const Text('Return Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to return to web application:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Text(error, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            const SizedBox(height: 12),
            const Text('Please try again or contact support if the problem persists.', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToIssue();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
