import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:vcmrtdapp/models/document_result.dart';
import 'package:http/http.dart' as http;

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/return_to_web.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

import '../../models/mrtd_data.dart';
import '../../services/api_service.dart';
import 'data_screen_widgets/verify_result.dart';

class PassportDataScreen extends StatefulWidget {
  final MrtdData mrtdData;
  final DocumentResult passportDataResult;
  final VoidCallback onBackPressed;
  final String? sessionId;
  final Uint8List? nonce;

  const PassportDataScreen({
    super.key,
    required this.mrtdData,
    required this.onBackPressed,
    required this.passportDataResult,
    this.sessionId,
    this.nonce,
  });

  @override
  State<PassportDataScreen> createState() => _PassportDataScreenState();
}

class _PassportDataScreenState extends State<PassportDataScreen> {
  final _apiService = ApiService();
  bool _isReturningToIssue = false;
  bool _isReturningToVerify = false;
  bool? _isExpired;
  bool? _authenticContent;
  bool? _authenticChip;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Passport Data'),
        leading: PlatformIconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBackPressed),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Return to Web banner if opened via universal link
              if (widget.sessionId != null) WebBanner(sessionId: widget.sessionId),
              PersonalDataSection(mrz: widget.mrtdData.dg1!.mrz, dg2: widget.mrtdData.dg2!),
              const SizedBox(height: 20),
              SecurityContent(mrtdData: widget.mrtdData),
              const SizedBox(height: 20),
              if (widget.sessionId != null) ...[
                const SizedBox(height: 20),
                if (_isExpired == null && _authenticChip == null && _authenticContent == null)
                  ReturnToWebSection(
                    isReturningToIssue: _isReturningToIssue,
                    isReturningToVerify: _isReturningToVerify,
                    onIssuePressed: _returnToIssue,
                    onVerifyPressed: _returnToVerify,
                  )
                else ...[
                  const SizedBox(height: 20),
                  VerifyResultSection(
                    isExpired: _isExpired!,
                    authenticChip: _authenticChip!,
                    authenticContent: _authenticContent!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _returnToVerify() async {
    if (widget.sessionId == null) return;
    setState(() {
      _isReturningToVerify = true;
    });

    try {
      final payload = widget.passportDataResult.toJson();
      final String jsonPayload = json.encode(payload);

      final response = await http.post(
        Uri.parse('https://passport-issuer.staging.yivi.app/api/verify-passport'),
        headers: {'Content-Type': 'application/json'},
        body: jsonPayload,
      );
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      setState(() {
        _isExpired = responseBody['is_expired'] as bool?;
        _authenticChip = responseBody['authentic_chip'] as bool?;
        _authenticContent = responseBody['authentic_content'] as bool?;
        _isReturningToVerify = false;
      });
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  /// Handle return to web functionality
  Future<void> _returnToIssue() async {
    if (widget.sessionId == null) return;

    setState(() {
      _isReturningToIssue = true;
    });

    try {
      // Create secure data payload
      final payload = widget.passportDataResult.toJson();

      // Get the signed IRMA JWt from the passport issuer
      final responseBody = await _apiService.getIrmaSessionJwt(payload);
      final irmaServerUrlParam = responseBody["irma_server_url"];
      final jwtUrlParam = responseBody["jwt"];

      // Start the session
      final sessionResponseBody = await _apiService.startIrmaSession(jwtUrlParam, irmaServerUrlParam);
      final sessionPtr = sessionResponseBody["sessionPtr"];
      final urlEncodedSessionPtr = Uri.encodeFull(jsonEncode(sessionPtr));

      // Open the session using a universal link in the Yivi app.
      final returnUrl = _apiService.generateUniversalLink(urlEncodedSessionPtr);

      // Open the universal link.
      final uri = Uri.parse(returnUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Show success message and close app
        _showReturnSuccessDialog();
      } else {
        throw Exception('Cannot launch return URL: $returnUrl');
      }
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isReturningToIssue = false;
        });
      }
    }
  }

  /// Show success dialog after successful return
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

  /// Show error dialog if return fails
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
              _returnToIssue(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
