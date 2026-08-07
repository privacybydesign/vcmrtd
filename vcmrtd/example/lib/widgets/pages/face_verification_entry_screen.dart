import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/widgets/pages/face_method_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

/// Orchestrates the face verification flow: a method picker first, then the
/// on-device selfie screen (active/passive liveness).
class FaceVerificationEntryScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;

  // Test-only: injects a pre-built on-device engine.
  final FaceVerificationEngine? testEngine;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  }) : testEngine = null;

  const FaceVerificationEntryScreen.withEngine({
    super.key,
    required FaceVerificationEngine engine,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  }) : testEngine = engine;

  @override
  State<FaceVerificationEntryScreen> createState() => _FaceVerificationEntryScreenState();
}

enum _Step { selecting, scanning }

class _FaceVerificationEntryScreenState extends State<FaceVerificationEntryScreen> {
  _Step _step = _Step.selecting;
  LivenessMode _mode = LivenessMode.passive;

  void _selectMode(LivenessMode mode) => setState(() {
    _mode = mode;
    _step = _Step.scanning;
  });

  void _backToSelection() => setState(() => _step = _Step.selecting);

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.scanning:
        final engine = widget.testEngine;
        if (engine != null) {
          return FlutterFaceVerificationScreen.withEngine(
            engine: engine,
            mode: _mode,
            nfcImageBytes: widget.nfcImageBytes,
            onBackPressed: _backToSelection,
            photoIssueDate: widget.photoIssueDate,
          );
        }
        return FlutterFaceVerificationScreen(
          mode: _mode,
          nfcImageBytes: widget.nfcImageBytes,
          onBackPressed: _backToSelection,
          photoIssueDate: widget.photoIssueDate,
        );
      case _Step.selecting:
        return FaceMethodSelectionScreen(onBackPressed: widget.onBackPressed, onModeSelected: _selectMode);
    }
  }
}
