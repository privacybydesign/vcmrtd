import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/regula_face_service.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/common/face_verification_views.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

/// Runs a Regula liveness session against the announced Face API
/// ([faceVerification]). Only liveness runs in the app: the proofing
/// session's server matches after the step is submitted.
class RegulaFaceVerificationScreen extends ConsumerStatefulWidget {
  final ProofingFaceVerification faceVerification;
  final VoidCallback onBackPressed;
  final ValueChanged<FaceVerificationOutcome> onVerified;

  final int stepNumber;
  final int totalSteps;

  const RegulaFaceVerificationScreen({
    super.key,
    required this.faceVerification,
    required this.onBackPressed,
    required this.onVerified,
    this.stepNumber = FlowStepPlan.defaultFaceVerificationStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  ConsumerState<RegulaFaceVerificationScreen> createState() => _RegulaFaceVerificationScreenState();
}

enum _Status { intro, launching, continuing, notLive, cancelled, error }

class _RegulaFaceVerificationScreenState extends ConsumerState<RegulaFaceVerificationScreen> {
  _Status _status = _Status.intro;
  String? _error;

  Future<void> _run() async {
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
      _continue(FaceVerificationOutcome(engine: 'regula', livenessPassed: true, livenessTransactionId: transactionId));
    } on RegulaLivenessCancelled {
      if (mounted) setState(() => _status = _Status.cancelled);
    } catch (e) {
      if (mounted) _showError(context.l10n.faceRegulaFailedError('$e'));
    }
  }

  void _showError(String error) {
    setState(() {
      _error = error;
      _status = _Status.error;
    });
  }

  /// Moves on right away; the spinner stays up until the next screen.
  void _continue(FaceVerificationOutcome outcome) {
    setState(() => _status = _Status.continuing);
    widget.onVerified(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_status == _Status.intro) {
      return GuidedFaceIntroView(
        stepNumber: widget.stepNumber,
        totalSteps: widget.totalSteps,
        style: context.guided,
        title: l10n.faceSelfieIntroTitle,
        body: l10n.faceRegulaIntroBody,
        tips: [
          (Icons.wb_sunny_outlined, l10n.faceTipEvenLight),
          (Icons.face_retouching_off_outlined, l10n.faceTipRemoveAccessories),
          (Icons.center_focus_strong_outlined, l10n.faceRegulaStep2),
        ],
        startLabel: l10n.faceStartSelfieCheck,
        onStart: _run,
        onBack: widget.onBackPressed,
        backTooltip: l10n.faceBack,
      );
    }
    return FaceStepScaffold(
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      onBack: widget.onBackPressed,
      child: switch (_status) {
        _Status.intro || _Status.launching => FaceBusyView(label: l10n.faceRegulaOpeningCamera),
        _Status.continuing => FaceBusyView(label: l10n.faceContinuing),
        _Status.notLive => FaceResultView(
          icon: Icons.cancel,
          tone: FaceResultTone.failure,
          title: l10n.faceVerificationFailed,
          subtitle: l10n.faceRegulaNotLiveSubtitle,
          onRetry: _run,
        ),
        _Status.cancelled => FaceResultView(
          icon: Icons.info_outline,
          tone: FaceResultTone.notice,
          title: l10n.faceCancelled,
          subtitle: l10n.faceRegulaCancelledSubtitle,
          onRetry: _run,
        ),
        _Status.error => FaceResultView(
          icon: Icons.error_outline,
          tone: FaceResultTone.failure,
          title: l10n.faceSomethingWentWrong,
          subtitle: _error ?? '',
          onRetry: _run,
        ),
      },
    );
  }
}
