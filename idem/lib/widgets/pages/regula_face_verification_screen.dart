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
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/common/face_verification_views.dart';

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
    this.stepNumber = FlowStepPlan.defaultFaceVerificationStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
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
      await _match(matchFace, transactionId);
    } on RegulaLivenessCancelled {
      if (mounted) setState(() => _status = _Status.cancelled);
    } catch (e) {
      if (mounted) _showError(context.l10n.faceRegulaFailedError('$e'));
    }
  }

  Future<void> _match(Future<FaceMatch?> Function(String) matchFace, String transactionId) async {
    setState(() => _status = _Status.matching);
    final FaceMatch? match;
    try {
      match = await matchFace(transactionId);
    } catch (e) {
      if (mounted) _showError(context.l10n.faceRegulaFailedError('$e'));
      return;
    }
    if (!mounted) return;
    if (match == null) {
      _showError(context.l10n.faceRegulaMatchUnavailable);
      return;
    }
    setState(() {
      _similarity = match!.similarity;
      _status = match.matched ? _Status.matched : _Status.noMatch;
    });
    if (match.matched) {
      _continue(FaceVerificationOutcome(engine: 'regula', livenessPassed: true, matchScore: match.similarity));
    }
  }

  void _showError(String error) {
    setState(() {
      _error = error;
      _status = _Status.error;
    });
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
                _Status.intro => FaceIntroView(
                  title: l10n.faceRegulaIntroTitle,
                  body: l10n.faceRegulaIntroBody,
                  steps: [l10n.faceRegulaStep1, l10n.faceRegulaStep2, l10n.faceRegulaStep3],
                  onStart: _run,
                ),
                _Status.launching => FaceBusyView(label: l10n.faceRegulaOpeningCamera),
                _Status.live => FaceResultView(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: l10n.faceRegulaLiveTitle,
                  subtitle: l10n.faceRegulaLiveSubtitle,
                ),
                _Status.matching => FaceBusyView(label: l10n.faceRegulaMatching),
                _Status.matched => FaceResultView(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: l10n.faceIdentityVerified,
                  subtitle: l10n.faceRegulaMatchedSubtitle(((_similarity ?? 0) * 100).toStringAsFixed(1)),
                ),
                _Status.noMatch => FaceResultView(
                  icon: Icons.cancel,
                  color: Colors.red,
                  title: l10n.faceVerificationFailed,
                  subtitle: l10n.faceRegulaNoMatchSubtitle,
                  onRetry: _retry,
                  retryLabel: l10n.faceRegulaScanAgain,
                ),
                _Status.notLive => FaceResultView(
                  icon: Icons.cancel,
                  color: Colors.red,
                  title: l10n.faceVerificationFailed,
                  subtitle: l10n.faceRegulaNotLiveSubtitle,
                  onRetry: _run,
                ),
                _Status.cancelled => FaceResultView(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  title: l10n.faceCancelled,
                  subtitle: l10n.faceRegulaCancelledSubtitle,
                  onRetry: _run,
                ),
                _Status.error => FaceResultView(
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
}
