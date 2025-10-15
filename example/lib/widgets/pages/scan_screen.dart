import 'package:flutter/material.dart';

import '../../custom/custom_logger_extension.dart';
import '../../controllers/mrz_controller.dart';
import '../../helpers/mrz_scanner.dart';
import 'package:vcmrtd/vcmrtd.dart';

class ScannerPage extends StatefulWidget {
  final DocumentType documentType;
  final  Function(dynamic) onSuccess;

  const ScannerPage({super.key, this.documentType = DocumentType.passport, required this.onSuccess});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MRZController controller = MRZController();
  @override
  Widget build(BuildContext context) {
        return MRZScanner(
          controller: controller,
          documentType: widget.documentType,
          onSuccess: (dynamic mrzResult, lines) async {
            'MRZ Scanned'.logInfo();
            widget.onSuccess(mrzResult);
          },
        );
      }
  }

