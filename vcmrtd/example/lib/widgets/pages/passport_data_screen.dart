import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';

import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';
import '../../widgets/pages/data_screen_widgets/return_to_web.dart';
import '../../widgets/pages/data_screen_widgets/web_banner.dart';

import '../common/issuance_result_dialogs.dart';
import 'data_screen_widgets/verify_result.dart';

class PassportDataScreen extends ConsumerStatefulWidget {
  final DocumentData document;
  final RawDocumentData passportDataResult;
  final VoidCallback onBackPressed;
  final DocumentType documentType;
  final void Function(FaceVerificationArgs) onFaceVerification;

  const PassportDataScreen({
    super.key,
    required this.document,
    required this.onBackPressed,
    required this.passportDataResult,
    required this.onFaceVerification,
    this.documentType = DocumentType.passport,
  });

  @override
  ConsumerState<PassportDataScreen> createState() => _PassportDataScreenState();
}

class _PassportDataScreenState extends ConsumerState<PassportDataScreen> {
  VerificationResponse? _verificationResponse;
  bool _startingFaceVerification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.documentType.displayName} Data'),
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
              PersonalDataSection(passport: widget.document as PassportData),
              const SizedBox(height: 20),
              SecurityContent(passport: widget.document as PassportData),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startingFaceVerification ? null : _startFaceVerification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _startingFaceVerification
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.face),
                label: Text(_startingFaceVerification ? 'Starting…' : 'Start Face Verification'),
              ),
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

  // Starts a face verification: ensures we have a verification response (which
  // carries the face_session the issuer started from the DG2 portrait), then
  // navigates to the face screen with the raw DG2 bytes needed to derive the
  // binding key. Verification still works when no face session is configured —
  // the face screen then falls back to local alignment only.
  Future<void> _startFaceVerification() async {
    final passport = widget.document as PassportData;
    setState(() => _startingFaceVerification = true);

    var response = _verificationResponse;
    try {
      if (response?.faceSession == null) {
        response = await ref.read(passportIssuerProvider).verifyPassport(widget.passportDataResult);
        if (!mounted) return;
        setState(() => _verificationResponse = response);
      }
    } catch (e) {
      // Non-fatal: continue to the face screen for local alignment.
      if (mounted) _showReturnErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _startingFaceVerification = false);
    }
    if (!mounted) return;

    final dg2Hex = widget.passportDataResult.dataGroups['DG2'];
    final referencePhoto = dg2Hex == null ? null : const Uint8ListConverter().fromJson(dg2Hex);

    widget.onFaceVerification(
      FaceVerificationArgs(
        portraitImageBytes: passport.photoImageData,
        referencePhotoBytes: referencePhoto,
        faceSession: response?.faceSession,
        issueDate: passport.dateOfIssue,
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
      // When face verification is enabled the issuer gates issuance on a
      // successful face verification; pass the face_session_id from the verify
      // response so it can correlate the authoritative result.
      final response = await issuer.startIrmaIssuanceSession(
        widget.passportDataResult,
        widget.documentType,
        faceSessionId: _verificationResponse?.faceSession?.faceSessionId,
      );
      await launchUrl(response.toUniversalLink(), mode: LaunchMode.externalApplication);
      _showReturnSuccessDialog();
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    }
  }

  void _showReturnSuccessDialog() {
    final docName = widget.documentType.displayName.toLowerCase();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
        title: const Text('Success!'),
        content: Text(
          'Your $docName data has been securely transmitted to the web application. '
          'You can now close this app or scan another document.',
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
