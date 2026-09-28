// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import '../../routing.dart';
import 'scan_screen.dart';
import 'package:vcmrtd/vcmrtd.dart';

typedef ScannerWidgetBuilder =
    Widget Function({required DocumentType documentType, required ValueChanged<ScannedMRZ> onSuccess});

class MrzReaderRouteParams {
  final DocumentType documentType;

  MrzReaderRouteParams({required this.documentType});

  static MrzReaderRouteParams fromQueryParams(Map<String, String> params) {
    return MrzReaderRouteParams(documentType: stringToDocumentType(params['document_type']!));
  }

  Map<String, String> toQueryParams() {
    return {'document_type': documentTypeToString(documentType)};
  }
}

/// Wrapper around ScannerPage to handle navigation callbacks
class ScannerWrapper extends StatefulWidget {
  final Function(ScannedMRZ) onMrzScanned;
  final VoidCallback onManualEntry;
  final VoidCallback onBack;
  final DocumentType documentType;
  final ScannerWidgetBuilder? scannerBuilder;

  const ScannerWrapper({
    super.key,
    required this.onMrzScanned,
    required this.onManualEntry,
    required this.onBack,
    this.documentType = DocumentType.passport,
    this.scannerBuilder,
  });

  @override
  State<ScannerWrapper> createState() => _ScannerWrapperState();
}

class _ScannerWrapperState extends State<ScannerWrapper> with RouteAware {
  bool _hasNavigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _hasNavigated = false;

  void _onScanned(ScannedMRZ scannedMrz) {
    if (!_hasNavigated) {
      _hasNavigated = true;
      widget.onMrzScanned(scannedMrz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guided = context.guided;
    if (guided != null) return _buildGuided(context, guided);

    final scannerBuilder = widget.scannerBuilder ?? _defaultScannerBuilder;

    return Scaffold(
      body: Stack(
        children: [
          scannerBuilder(
            documentType: widget.documentType,
            onSuccess: (scannedMrz) {
              if (!_hasNavigated) {
                _hasNavigated = true;
                widget.onMrzScanned(scannedMrz);
              }
            },
          ),
          Positioned(left: 0, right: 0, top: 0, child: _buildTopOverlay(context)),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomControls(context)),
        ],
      ),
    );
  }

  Widget _buildTopOverlay(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(PlatformIcons(context).back, color: Colors.white),
                    onPressed: widget.onBack,
                  ),
                ),
                StepBadge(current: 1, total: 4, label: 'Scan ${_getDocumentTypeName()}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.fromLTRB(30, 0, 24, 0), child: _buildOverlayCard(context)),
        ],
      ),
    );
  }

  Widget _buildOverlayCard(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position the ${widget.documentType.displayName}',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Align the Machine Readable Zone (MRZ) with the frame at the bottom of the screen. Hold steady until scanning completes.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 24, 24, 32),
      decoration: BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          onPressed: () {
            widget.onManualEntry();
          },
          child: Text('Enter ${_getDocumentTypeName()} details manually', style: TextStyle(color: Colors.black)),
        ),
      ),
    );
  }

  String _getDocumentTypeName() {
    return widget.documentType.displayName;
  }

  /// Guided layout: a dark scrim with a card-shaped cut-out and the
  /// instructions in a sheet at the bottom. The scanner's own frame is off;
  /// [guidedScanFrame] draws one in the same place as the area it reads.
  Widget _buildGuided(BuildContext context, GuidedStyle g) {
    final scannerBuilder = widget.scannerBuilder ?? _guidedScannerBuilder;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: g.ink,
        body: Stack(
          children: [
            Positioned.fill(
              child: scannerBuilder(documentType: widget.documentType, onSuccess: _onScanned),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => CustomPaint(
                    painter: _GuidedScanFramePainter(
                      frame: guidedScanFrame(box.biggest),
                      mrzLines: _mrzLineCount(widget.documentType),
                      scrim: g.ink.withValues(alpha: 0.8),
                      highlight: g.heroAccent,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        GuidedTopBar(
                          leading: GuidedRoundButton(
                            icon: Icons.close,
                            tooltip: 'Close',
                            onDark: true,
                            onPressed: widget.onBack,
                          ),
                          center: GuidedTopBarTitle('Scan ${_guidedDocumentName(widget.documentType)}', onDark: true),
                        ),
                        const GuidedStepBar(step: 1, onDark: true),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _GuidedScanSheet(documentType: widget.documentType, onManualEntry: widget.onManualEntry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the guided scan screen draws the document frame for a view of [size]:
/// the same rectangle the MRZ scanner reads text from (see
/// `MRZCameraViewState._overlayRect` in mrz_capture), so what the user lines up
/// with the frame is what gets read.
@visibleForTesting
Rect guidedScanFrame(Size size) {
  const documentFrameRatio = 1.42;
  double width, height;
  if (size.height > size.width) {
    width = size.width * 0.9;
    height = width / documentFrameRatio;
  } else {
    height = size.height * 0.75;
    width = height * documentFrameRatio;
  }
  return Rect.fromLTWH((size.width - width) / 2, (size.height - height) / 2 - 60.0, width, height);
}

int _mrzLineCount(DocumentType type) => switch (type) {
  DocumentType.passport => 2,
  DocumentType.identityCard => 3,
  DocumentType.drivingLicence => 1,
};

String _guidedDocumentName(DocumentType type) => switch (type) {
  DocumentType.passport => 'passport',
  DocumentType.identityCard => 'identity card',
  DocumentType.drivingLicence => 'driving licence',
};

class _GuidedScanSheet extends StatelessWidget {
  const _GuidedScanSheet({required this.documentType, required this.onManualEntry});

  final DocumentType documentType;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final (title, tip) = switch (documentType) {
      DocumentType.passport => (
        'Place the photo page in the frame',
        'Make sure the two lines of text at the bottom are sharp and not covered by your fingers or glare.',
      ),
      DocumentType.identityCard => (
        'Place the back of your ID card in the frame',
        'Make sure the three lines of text at the bottom are sharp and not covered by your fingers or glare.',
      ),
      DocumentType.drivingLicence => (
        'Place the back of your driving licence in the frame',
        'Make sure the line of text at the bottom is sharp and not covered by your fingers or glare.',
      ),
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GuidedStepLabel(step: 1),
            const SizedBox(height: 16),
            Text(title, style: g.heading(22, height: 1.25)),
            const SizedBox(height: 16),
            Text(tip, style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText)),
            const SizedBox(height: 16),
            GuidedButton(label: 'Enter details manually', secondary: true, onPressed: onManualEntry),
          ],
        ),
      ),
    );
  }
}

class _GuidedScanFramePainter extends CustomPainter {
  _GuidedScanFramePainter({required this.frame, required this.mrzLines, required this.scrim, required this.highlight});

  final Rect frame;
  final int mrzLines;
  final Color scrim;
  final Color highlight;

  static const _radius = 16.0;
  static const _cornerLength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(frame, const Radius.circular(_radius));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(cutout),
      Paint()..color = scrim,
    );

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const r = Radius.circular(_radius);
    final l = frame.left, t = frame.top, rt = frame.right, b = frame.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + _cornerLength)
        ..lineTo(l, t + _radius)
        ..arcToPoint(Offset(l + _radius, t), radius: r)
        ..lineTo(l + _cornerLength, t)
        ..moveTo(rt - _cornerLength, t)
        ..lineTo(rt - _radius, t)
        ..arcToPoint(Offset(rt, t + _radius), radius: r)
        ..lineTo(rt, t + _cornerLength)
        ..moveTo(rt, b - _cornerLength)
        ..lineTo(rt, b - _radius)
        ..arcToPoint(Offset(rt - _radius, b), radius: r)
        ..lineTo(rt - _cornerLength, b)
        ..moveTo(l + _cornerLength, b)
        ..lineTo(l + _radius, b)
        ..arcToPoint(Offset(l, b - _radius), radius: r)
        ..lineTo(l, b - _cornerLength),
      corner,
    );

    // The machine-readable lines sit along the bottom of every supported document.
    final inset = frame.width * 0.044;
    final zoneHeight = frame.height * (0.08 + 0.08 * mrzLines);
    final zone = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        frame.left + inset,
        frame.bottom - frame.height * 0.08 - zoneHeight,
        frame.right - inset,
        frame.bottom - frame.height * 0.08,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(zone, Paint()..color = highlight.withValues(alpha: 0.12));
    canvas.drawRRect(
      zone,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GuidedScanFramePainter old) =>
      old.frame != frame || old.mrzLines != mrzLines || old.scrim != scrim || old.highlight != highlight;
}

Widget _defaultScannerBuilder({required DocumentType documentType, required ValueChanged<ScannedMRZ> onSuccess}) {
  return ScannerPage(documentType: documentType, onSuccess: onSuccess);
}

Widget _guidedScannerBuilder({required DocumentType documentType, required ValueChanged<ScannedMRZ> onSuccess}) {
  return ScannerPage(documentType: documentType, onSuccess: onSuccess, showOverlay: false);
}
