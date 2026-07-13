import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';
import 'package:vcmrtdapp/services/regula_face_service.dart';
import 'package:vcmrtdapp/widgets/pages/face_method_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/regula_result_screen.dart';

/// Orchestrates the face verification flow: a method picker first, then either
/// the on-device selfie screen (active/passive) or Regula's native session
/// followed by its result screen.
class FaceVerificationEntryScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;

  // Test-only: injects a pre-built on-device engine.
  final FaceVerificationEngine? testEngine;

  // Test-only: injects a Regula service so the flow runs without the native SDK.
  final RegulaFaceService? regulaService;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
    this.regulaService,
  }) : testEngine = null;

  const FaceVerificationEntryScreen.withEngine({
    super.key,
    required FaceVerificationEngine engine,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
    this.regulaService,
  }) : testEngine = engine;

  @override
  State<FaceVerificationEntryScreen> createState() => _FaceVerificationEntryScreenState();
}

enum _Step { selecting, scanning, regulaResult }

class _FaceVerificationEntryScreenState extends State<FaceVerificationEntryScreen> {
  _Step _step = _Step.selecting;
  LivenessMode _mode = LivenessMode.passive;
  bool _regulaBusy = false;
  RegulaFaceResult? _regulaResult;
  RegulaFaceService? _lazyRegula;

  RegulaFaceService get _regula => widget.regulaService ?? (_lazyRegula ??= RegulaFaceServiceImpl());

  void _selectMode(LivenessMode mode) => setState(() {
    _mode = mode;
    _step = _Step.scanning;
  });

  Future<void> _runRegula() async {
    final nfcImage = widget.nfcImageBytes;
    if (nfcImage == null || nfcImage.isEmpty) {
      _showError('Missing NFC image');
      return;
    }
    setState(() => _regulaBusy = true);
    try {
      final result = await _regula.verifyAgainstDocument(nfcImage);
      if (!mounted) return;
      setState(() {
        _regulaResult = result;
        _step = _Step.regulaResult;
      });
    } catch (e) {
      if (mounted) _showError('Regula verification failed: $e');
    } finally {
      if (mounted) setState(() => _regulaBusy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _backToSelection() => setState(() {
    _step = _Step.selecting;
    _regulaResult = null;
  });

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
      case _Step.regulaResult:
        return RegulaResultScreen(result: _regulaResult!, onBackPressed: _backToSelection, onRetry: _runRegula);
      case _Step.selecting:
        return FaceMethodSelectionScreen(
          onBackPressed: widget.onBackPressed,
          onModeSelected: _selectMode,
          onRegulaSelected: _runRegula,
          regulaBusy: _regulaBusy,
        );
    }
  }
}
