import 'package:flutter/material.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';

class FaceVerificationEntryScreen extends StatelessWidget {
  final FaceVerificationArgs args;
  final VoidCallback onBackPressed;

  const FaceVerificationEntryScreen({super.key, required this.args, required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return FlutterFaceVerificationScreen(args: args, onBackPressed: onBackPressed);
  }
}
