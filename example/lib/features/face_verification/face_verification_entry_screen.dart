import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';

class FaceVerificationEntryScreen extends StatelessWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;

  const FaceVerificationEntryScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterFaceVerificationScreen(
      nfcImageBytes: nfcImageBytes,
      onBackPressed: onBackPressed,
      photoIssueDate: photoIssueDate,
    );
  }
}
