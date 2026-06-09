import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtd/face_verification.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

class FaceVerificationEntryScreen extends StatelessWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;
  final FaceVerificationEngine? _testEngine;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  }) : _testEngine = null;

  const FaceVerificationEntryScreen.withEngine({
    super.key,
    required FaceVerificationEngine engine,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  }) : _testEngine = engine;

  @override
  Widget build(BuildContext context) {
    final testEngine = _testEngine;
    if (testEngine != null) {
      return FlutterFaceVerificationScreen.withEngine(
        engine: testEngine,
        nfcImageBytes: nfcImageBytes,
        onBackPressed: onBackPressed,
        photoIssueDate: photoIssueDate,
      );
    }

    return FlutterFaceVerificationScreen(
      nfcImageBytes: nfcImageBytes,
      onBackPressed: onBackPressed,
      photoIssueDate: photoIssueDate,
    );
  }
}
