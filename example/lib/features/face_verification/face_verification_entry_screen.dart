import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_feature_flags.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart' as legacy;

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
    if (kUseLegacyFaceVerification) {
      return legacy.FaceVerificationScreen(
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
