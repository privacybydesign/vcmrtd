import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';

import '../../providers/ocr_engine_provider.dart';
import '../../routing.dart';

/// Wires the mrz_capture scanner into this application: the OCR engine comes
/// from the settings provider, the route observer from the router.
class ScannerPage extends ConsumerStatefulWidget {
  final DocumentType documentType;
  final Function(ScannedMRZ) onSuccess;

  const ScannerPage({super.key, this.documentType = DocumentType.passport, required this.onSuccess});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final MRZController controller = MRZController();

  @override
  Widget build(BuildContext context) {
    return MRZScanner(
      controller: controller,
      documentType: widget.documentType,
      engine: ref.watch(ocrEngineProvider),
      routeObserver: routeObserver,
      onSuccess: (scannedMRZ, lines) => widget.onSuccess(scannedMRZ),
    );
  }
}
