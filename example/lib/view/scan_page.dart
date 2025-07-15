import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../custom/custom_logger_extension.dart';
import '../controllers/mrz_controller.dart';
import '../helpers/mrz_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MRZController controller = MRZController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        return MRZScanner(
          controller: controller,
          onSuccess: (mrzResult, lines) async {
            'MRZ Scanned'.logInfo();
            Navigator.of(context, rootNavigator: true).pop(mrzResult);
          },
        );
      }),
    );
  }
}
