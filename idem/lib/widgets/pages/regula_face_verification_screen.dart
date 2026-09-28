import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart' show FaceMatch;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/regula_face_service.dart';

/// Runs a Regula liveness session against the announced Face API
/// ([faceVerification]). Only liveness runs in the app: a proofing session's
/// server matches after the step is submitted, while a standalone scan asks
/// the passport issuer to match right here ([matchFace]).
class RegulaFaceVerificationScreen extends ConsumerStatefulWidget {
  final ProofingFaceVerification faceVerification;
  final VoidCallback onBackPressed;
  final ValueChanged<FaceVerificationOutcome> onVerified;

  /// Standalone only: has the passport issuer match the transaction against
  /// the chip photo. It uses up the issuer session, so a failure can't retry.
  final Future<FaceMatch?> Function(String livenessTransactionId)? matchFace;
  final int stepNumber;
  final int totalSteps;

  const RegulaFaceVerificationScreen({
    super.key,
    required this.faceVerification,
    required this.onBackPressed,
    required this.onVerified,
    this.matchFace,
    this.stepNumber = 3,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<RegulaFaceVerificationScreen> createState() => _RegulaFaceVerificationScreenState();
}

enum _Status { intro, launching, live, matching, matched, noMatch, notLive, cancelled, error }

class _RegulaFaceVerificationScreenState extends ConsumerState<RegulaFaceVerificationScreen> {
  _Status _status = _Status.intro;
  String? _error;
  double? _similarity;
  Timer? _autoContinueTimer;

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    _autoContinueTimer?.cancel();
    setState(() {
      _status = _Status.launching;
      _error = null;
    });
    try {
      final result = await ref
          .read(regulaFaceServiceProvider)
          .captureLiveness(
            tag: widget.faceVerification.tag.isEmpty ? null : widget.faceVerification.tag,
            serviceUrl: widget.faceVerification.faceApiUrl,
          );
      if (!mounted) return;
      final transactionId = result.transactionId;
      if (!result.isLive || transactionId == null) {
        setState(() => _status = _Status.notLive);
        return;
      }
      final matchFace = widget.matchFace;
      if (matchFace == null) {
        setState(() => _status = _Status.live);
        _continue(
          FaceVerificationOutcome(engine: 'regula', livenessPassed: true, livenessTransactionId: transactionId),
        );
        return;
      }
      setState(() => _status = _Status.matching);
      final FaceMatch? match;
      try {
        match = await matchFace(transactionId);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = context.l10n.faceRegulaFailedError('$e');
          _status = _Status.error;
        });
        return;
      }
      if (!mounted) return;
      if (match == null) {
        setState(() {
          _error = context.l10n.faceRegulaMatchUnavailable;
          _status = _Status.error;
        });
        return;
      }
      setState(() {
        _similarity = match!.similarity;
        _status = match.matched ? _Status.matched : _Status.noMatch;
      });
      if (match.matched) {
        _continue(FaceVerificationOutcome(engine: 'regula', livenessPassed: true, matchScore: match.similarity));
      }
    } on RegulaLivenessCancelled {
      if (mounted) setState(() => _status = _Status.cancelled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.faceRegulaFailedError('$e');
        _status = _Status.error;
      });
    }
  }

  void _continue(FaceVerificationOutcome outcome) {
    _autoContinueTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onVerified(outcome);
    });
  }

  /// A failure after the issuer was asked can't retry: its session is used up.
  VoidCallback get _retry => widget.matchFace == null ? _run : widget.onBackPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepBadgeTopBar(
              icon: Icons.arrow_back,
              tooltip: l10n.faceBack,
              onBack: widget.onBackPressed,
              current: widget.stepNumber,
              total: widget.totalSteps,
              label: l10n.faceStepLabel,
            ),
            Expanded(
              child: switch (_status) {
                _Status.intro => _buildIntro(context),
                _Status.launching => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.faceRegulaOpeningCamera),
                    ],
                  ),
                ),
                _Status.live => _ResultView(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: l10n.faceRegulaLiveTitle,
                  subtitle: l10n.faceRegulaLiveSubtitle,
                ),
                _Status.matching => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.faceRegulaMatching),
                    ],
                  ),
                ),
                _Status.matched => _ResultView(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: l10n.faceIdentityVerified,
                  subtitle: l10n.faceRegulaMatchedSubtitle(((_similarity ?? 0) * 100).toStringAsFixed(1)),
                ),
                _Status.noMatch => _ResultView(
                  icon: Icons.cancel,
                  color: Colors.red,
                  title: l10n.faceVerificationFailed,
                  subtitle: l10n.faceRegulaNoMatchSubtitle,
                  onRetry: _retry,
                  retryLabel: l10n.faceRegulaScanAgain,
                ),
                _Status.notLive => _ResultView(
                  icon: Icons.cancel,
                  color: Colors.red,
                  title: l10n.faceVerificationFailed,
                  subtitle: l10n.faceRegulaNotLiveSubtitle,
                  onRetry: _run,
                ),
                _Status.cancelled => _ResultView(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  title: l10n.faceCancelled,
                  subtitle: l10n.faceRegulaCancelledSubtitle,
                  onRetry: _run,
                ),
                _Status.error => _ResultView(
                  icon: Icons.error_outline,
                  color: Colors.red,
                  title: l10n.faceSomethingWentWrong,
                  subtitle: _error ?? '',
                  onRetry: _retry,
                  retryLabel: widget.matchFace == null ? null : l10n.faceRegulaScanAgain,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            l10n.faceRegulaIntroTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.faceRegulaIntroBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.faceIrisWhatToExpect, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('1. ${l10n.faceRegulaStep1}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('2. ${l10n.faceRegulaStep2}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('3. ${l10n.faceRegulaStep3}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _run,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.face),
            label: Text(l10n.faceStartVerification),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const _ResultView({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (onRetry != null)
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? context.l10n.faceTryAgain))
          else
            Center(
              child: Text(context.l10n.faceContinuing, style: const TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}
