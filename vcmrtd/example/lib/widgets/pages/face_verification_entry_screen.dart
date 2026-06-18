import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

class FaceVerificationEntryScreen extends StatelessWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;

  const FaceVerificationEntryScreen({super.key, required this.nfcImageBytes, required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return FlutterFaceVerificationScreen(nfcImageBytes: nfcImageBytes, onBackPressed: onBackPressed);
  }
}
