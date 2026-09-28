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

  /// Whether the scanner draws its own document frame; off when the caller draws one.
  final bool showOverlay;

  const ScannerPage({
    super.key,
    this.documentType = DocumentType.passport,
    required this.onSuccess,
    this.showOverlay = true,
  });

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
      showOverlay: widget.showOverlay,
      onSuccess: (scannedMRZ, lines) => widget.onSuccess(scannedMRZ),
    );
  }
}
