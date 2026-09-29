import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtd/vcmrtd.dart' show FaceMatch;
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/face_verification_screen.dart';
import 'package:idem/widgets/pages/iris_face_verification_screen.dart';
import 'package:idem/widgets/pages/regula_face_verification_screen.dart';
import 'package:idem/services/flow_step_plan.dart';

/// Orchestrates the face verification flow for the engine chosen up front
/// (Regula, on-device or Iris SDK, picked in the advanced settings).
/// Regula needs a server that announced it ([faceVerification]) to do the
/// match: the QR session's, or the passport issuer's for a standalone scan.
/// Without one it falls back to on-device. Nothing
/// engine-related — no [FaceVerificationEngine], no Iris SDK instance, no
/// camera — is created before this screen decides which flow to enter.
class FaceVerificationEntryScreen extends StatelessWidget {
  final Uint8List? nfcImageBytes;

  /// Explicit cancel — leaves the face verification flow without having
  /// verified anything (e.g. back to NFC reading).
  final VoidCallback onBackPressed;

  /// Fired once verification has passed, to continue on to whatever comes
  /// after face verification (e.g. the document data screen).
  final ValueChanged<FaceVerificationOutcome> onVerified;
  final DateTime? photoIssueDate;
  final FaceEngineChoice engineChoice;

  /// Liveness mode for the on-device engine, picked in the advanced settings.
  /// Not applicable to the Iris SDK, which runs its own native flow.
  final LivenessMode livenessMode;

  /// The session's Regula announcement, if any.
  final ProofingFaceVerification? faceVerification;

  /// Standalone Regula: the passport issuer's match (see RegulaFaceVerificationScreen).
  final Future<FaceMatch?> Function(String livenessTransactionId)? matchFace;

  // Test-only: injects a pre-built on-device engine.
  @visibleForTesting
  final FaceVerificationEngine? testEngine;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 3 there) so any caller not passing these
  /// explicitly keeps today's behaviour; routing.dart passes a session's
  /// actual FlowStepPlan values when a QR/deep-link flow governs the
  /// numbering.
  final int stepNumber;
  final int totalSteps;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    required this.engineChoice,
    required this.livenessMode,
    this.faceVerification,
    this.matchFace,
    this.photoIssueDate,
    this.stepNumber = FlowStepPlan.defaultFaceVerificationStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
    this.testEngine,
  });

  /// The engine that actually runs: a session whose flow chose Regula gets
  /// Regula whatever the setting; otherwise Regula only when a server offers it.
  static FaceEngineChoice effectiveEngine(FaceEngineChoice choice, ProofingFaceVerification? faceVerification) {
    if (faceVerification?.requiredBySession ?? false) return FaceEngineChoice.regula;
    return choice == FaceEngineChoice.regula && !(faceVerification?.isRegula ?? false)
        ? FaceEngineChoice.onDevice
        : choice;
  }

  @override
  Widget build(BuildContext context) {
    switch (effectiveEngine(engineChoice, faceVerification)) {
      case FaceEngineChoice.regula:
        return RegulaFaceVerificationScreen(
          faceVerification: faceVerification!,
          matchFace: matchFace,
          onBackPressed: onBackPressed,
          onVerified: onVerified,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
        );
      case FaceEngineChoice.iris:
        return IrisFaceVerificationScreen(
          nfcImageBytes: nfcImageBytes,
          onBackPressed: onBackPressed,
          onVerified: onVerified,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
        );
      case FaceEngineChoice.onDevice:
        return FlutterFaceVerificationScreen(
          mode: livenessMode,
          nfcImageBytes: nfcImageBytes,
          onBackPressed: onBackPressed,
          onVerified: onVerified,
          photoIssueDate: photoIssueDate,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          testEngine: testEngine,
        );
    }
  }
}
