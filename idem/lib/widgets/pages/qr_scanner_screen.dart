import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

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
    final guided = context.guided;
    if (guided != null) return _buildGuided(guided);

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

extension on _QrScannerScreenState {
  /// Guided layout: a dark scrim with a square cut-out, a short instruction
  /// above it and a reassurance below. Codes are found anywhere in the frame,
  /// so the cut-out is only a guide.
  Widget _buildGuided(GuidedStyle g) {
    return GuidedStatusBar(
      onDark: true,
      child: Scaffold(
        backgroundColor: g.ink,
        body: Stack(
          children: [
            Positioned.fill(
              child: MRZCameraView(showOverlay: false, routeObserver: widget.routeObserver, onImage: _processFrame),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => CustomPaint(
                    painter: _GuidedQrFramePainter(
                      frame: guidedQrFrame(box.biggest, minTop: MediaQuery.paddingOf(context).top + 244),
                      scrim: g.ink.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GuidedTopBar(
                    leading: GuidedRoundButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onDark: true,
                      onPressed: widget.onBack,
                    ),
                    center: const GuidedTopBarTitle('Scan QR code', onDark: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                    child: Column(
                      children: [
                        Text(
                          'Point your camera at the QR code',
                          textAlign: TextAlign.center,
                          style: g.heading(22, color: Colors.white, height: 1.25),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You’ll find it on the ${context.brand.appBarTitle} website or app that asked you to verify.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 1.5, color: g.heroMuted),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: g.heroMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Nothing is shared until you agree on the next screen.',
                            style: TextStyle(fontSize: 13, color: g.heroMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square the guided QR scanner asks the code to be held in, for a view of
/// [size]: a little above the middle, but never higher than [minTop], where
/// the instruction text ends.
@visibleForTesting
Rect guidedQrFrame(Size size, {double minTop = 0}) {
  final side = size.shortestSide * 0.69;
  final top = (size.height * 0.41 - side / 2).clamp(minTop, double.infinity);
  return Rect.fromLTWH((size.width - side) / 2, top, side, side);
}

class _GuidedQrFramePainter extends CustomPainter {
  _GuidedQrFramePainter({required this.frame, required this.scrim});

  final Rect frame;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(20);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(RRect.fromRectAndRadius(frame, radius)),
      Paint()..color = scrim,
    );
    const len = 32.0, r = 20.0;
    final l = frame.left, t = frame.top, rt = frame.right, b = frame.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..arcToPoint(Offset(l + r, t), radius: radius)
        ..lineTo(l + len, t)
        ..moveTo(rt - len, t)
        ..lineTo(rt - r, t)
        ..arcToPoint(Offset(rt, t + r), radius: radius)
        ..lineTo(rt, t + len)
        ..moveTo(rt, b - len)
        ..lineTo(rt, b - r)
        ..arcToPoint(Offset(rt - r, b), radius: radius)
        ..lineTo(rt - len, b)
        ..moveTo(l + len, b)
        ..lineTo(l + r, b)
        ..arcToPoint(Offset(l, b - r), radius: radius)
        ..lineTo(l, b - len),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GuidedQrFramePainter old) => old.frame != frame || old.scrim != scrim;
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
