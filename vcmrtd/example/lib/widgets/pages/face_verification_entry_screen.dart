import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/providers/face_engine_provider.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/iris_face_verification_screen.dart';

/// Orchestrates the face verification flow for the engine chosen up front
/// (on-device vs Iris SDK, picked in the advanced settings). Nothing
/// engine-related — no [FaceVerificationEngine], no Iris SDK instance, no
/// camera — is created before this screen decides which flow to enter.
class FaceVerificationEntryScreen extends StatelessWidget {
  final Uint8List? nfcImageBytes;

  /// Explicit cancel — leaves the face verification flow without having
  /// verified anything (e.g. back to NFC reading).
  final VoidCallback onBackPressed;

  /// Fired once verification has passed, to continue on to whatever comes
  /// after face verification (e.g. the document data screen).
  final VoidCallback onVerified;
  final DateTime? photoIssueDate;
  final FaceEngineChoice engineChoice;

  /// Liveness mode for the on-device engine, picked in the advanced settings.
  /// Not applicable to the Iris SDK, which runs its own native flow.
  final LivenessMode livenessMode;

  // Test-only: injects a pre-built on-device engine.
  final FaceVerificationEngine? testEngine;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    required this.engineChoice,
    required this.livenessMode,
    this.photoIssueDate,
  }) : testEngine = null;

  const FaceVerificationEntryScreen.withEngine({
    super.key,
    required FaceVerificationEngine engine,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    required this.engineChoice,
    required this.livenessMode,
    this.photoIssueDate,
  }) : testEngine = engine;

  @override
  Widget build(BuildContext context) {
    switch (engineChoice) {
      case FaceEngineChoice.iris:
        return IrisFaceVerificationScreen(
          nfcImageBytes: nfcImageBytes,
          onBackPressed: onBackPressed,
          onVerified: onVerified,
        );
      case FaceEngineChoice.onDevice:
        final engine = testEngine;
        if (engine != null) {
          return FlutterFaceVerificationScreen.withEngine(
            engine: engine,
            mode: livenessMode,
            nfcImageBytes: nfcImageBytes,
            onBackPressed: onBackPressed,
            onVerified: onVerified,
            photoIssueDate: photoIssueDate,
          );
        }
        return FlutterFaceVerificationScreen(
          mode: livenessMode,
          nfcImageBytes: nfcImageBytes,
          onBackPressed: onBackPressed,
          onVerified: onVerified,
          photoIssueDate: photoIssueDate,
        );
    }
  }
}
