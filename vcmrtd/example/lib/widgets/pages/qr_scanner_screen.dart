import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:mrz_capture/mrz_capture.dart';

/// Full screen QR code scanner, built on Google ML Kit's barcode scanner.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.onScanned, required this.onBack, this.routeObserver});

  /// Called once with the decoded value of the first QR code found.
  final ValueChanged<String> onScanned;
  final VoidCallback onBack;
  final RouteObserver<ModalRoute<void>>? routeObserver;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  bool _canProcess = true;
  bool _isBusy = false;

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _processFrame(OcrFrame frame) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;
    try {
      final inputImage = InputImage.fromBytes(
        bytes: frame.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: frame.isNv21 ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: frame.bytesPerRow,
        ),
      );

      final barcodes = await _barcodeScanner.processImage(inputImage);
      final values = barcodes.map((b) => b.rawValue).whereType<String>();
      final value = values.isEmpty ? null : values.first;
      if (value != null && _canProcess) {
        _canProcess = false;
        widget.onScanned(value);
      }
    } catch (_) {
    } finally {
      _isBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _QrOverlay(
          child: MRZCameraView(showOverlay: false, routeObserver: widget.routeObserver, onImage: _processFrame),
        ),
        SafeArea(
          child: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }
}

/// Darkens everything outside a centered square, with a white border marking
/// where the QR code should be held.
class _QrOverlay extends StatelessWidget {
  const _QrOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) * 0.7;
        final rect = RRect.fromLTRBR(
          (c.maxWidth - side) / 2,
          (c.maxHeight - side) / 2,
          (c.maxWidth + side) / 2,
          (c.maxHeight + side) / 2,
          const Radius.circular(16),
        );
        return Stack(
          children: [
            child,
            ClipPath(
              clipper: _SquareHoleClipper(rect: rect),
              child: Container(foregroundDecoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.45))),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              child: Container(
                width: rect.width,
                height: rect.height,
                decoration: BoxDecoration(
                  border: Border.all(width: 2.0, color: Colors.white),
                  borderRadius: BorderRadius.all(rect.tlRadius),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SquareHoleClipper extends CustomClipper<Path> {
  _SquareHoleClipper({required this.rect});

  final RRect rect;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(rect)
    ..addRect(Rect.fromLTWH(0.0, 0.0, size.width, size.height))
    ..fillType = PathFillType.evenOdd;

  @override
  bool shouldReclip(_SquareHoleClipper oldClipper) => false;
}
