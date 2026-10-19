// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import '../../routing.dart';
import 'scan_screen.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/services/flow_step_plan.dart';

/// Called with the MRZ read and, when one was asked for, the picture taken
/// the moment it was read (null when the camera couldn't take it).
typedef MrzScannedWithPicture = void Function(ScannedMRZ mrz, DocumentPicture? picture);

typedef ScannerWidgetBuilder =
    Widget Function({
      required DocumentType documentType,
      required MrzScanPicture scanPicture,
      required MrzScannedWithPicture onSuccess,
    });

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
  final void Function(ScannedMRZ mrz, [DocumentPicture? picture]) onMrzScanned;
  final VoidCallback onManualEntry;
  final VoidCallback onBack;
  final DocumentType documentType;
  final ScannerWidgetBuilder? scannerBuilder;

  /// Photographs the document the moment its MRZ is read: the flow asks for
  /// a photo of the document, and the side with the MRZ needs none of its
  /// own then.
  final MrzScanPicture scanPicture;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 1) so any caller not passing these explicitly
  /// keeps today's behaviour; routing.dart passes a session's actual
  /// [FlowStepPlan] values when a QR/deep-link flow governs the numbering.
  final int stepNumber;
  final int totalSteps;

  const ScannerWrapper({
    super.key,
    required this.onMrzScanned,
    required this.onManualEntry,
    required this.onBack,
    this.documentType = DocumentType.passport,
    this.scannerBuilder,
    this.scanPicture = MrzScanPicture.none,
    this.stepNumber = FlowStepPlan.defaultDocumentCaptureStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
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

  void _onScanned(ScannedMRZ scannedMrz, DocumentPicture? picture) {
    if (_hasNavigated) return;

    _hasNavigated = true;
    widget.onMrzScanned(scannedMrz, picture);
  }

  @override
  Widget build(BuildContext context) {
    final guided = context.guided;
    if (guided != null) return _buildGuided(context, guided);

    final scannerBuilder = widget.scannerBuilder ?? _defaultScannerBuilder;

    return Scaffold(
      body: Stack(
        children: [
          scannerBuilder(documentType: widget.documentType, scanPicture: widget.scanPicture, onSuccess: _onScanned),
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
                StepBadge(
                  current: widget.stepNumber,
                  total: widget.totalSteps,
                  label: context.l10n.proofingScanDocument(widget.documentType.name),
                ),
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
    // The inset a Card's default margin used to give it.
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.proofingPositionDocument(widget.documentType.name),
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            widget.scanPicture == MrzScanPicture.capture
                ? context.l10n.proofingScanMrzPhotoInstructions
                : context.l10n.proofingScanMrzInstructions,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 24, 32),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          onPressed: widget.onManualEntry,
          child: Text(
            context.l10n.proofingEnterDetailsManually(widget.documentType.name),
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  /// Guided layout: a dark scrim with a card-shaped cut-out and the
  /// instructions in a sheet at the bottom. The scanner's own frame is off;
  /// [guidedScanFrame] draws one in the same place as the area it reads.
  Widget _buildGuided(BuildContext context, GuidedStyle g) {
    final scannerBuilder = widget.scannerBuilder ?? _guidedScannerBuilder;
    return GuidedStatusBar(
      backdrop: Backdrop.dark,
      bottomBackdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: g.header,
        body: Stack(
          children: [
            Positioned.fill(
              child: scannerBuilder(
                documentType: widget.documentType,
                scanPicture: widget.scanPicture,
                onSuccess: _onScanned,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => CustomPaint(
                    painter: _GuidedScanFramePainter(
                      frame: guidedScanFrame(box.biggest, widget.documentType),
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
                            tooltip: context.l10n.scanClose,
                            backdrop: Backdrop.dark,
                            onPressed: widget.onBack,
                          ),
                          center: GuidedTopBarTitle(
                            context.l10n.proofingScanDocument(widget.documentType.name),
                            backdrop: Backdrop.dark,
                          ),
                        ),
                        GuidedStepBar(step: widget.stepNumber, total: widget.totalSteps, backdrop: Backdrop.dark),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _GuidedScanSheet(
                    documentType: widget.documentType,
                    onManualEntry: widget.onManualEntry,
                    stepNumber: widget.stepNumber,
                    totalSteps: widget.totalSteps,
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

/// Where the guided scan screen draws the document frame for a view of [size]:
/// the same rectangle the MRZ scanner reads text from (see
/// `MRZCameraViewState._overlayRect` in mrz_capture), so what the user lines up
/// with the frame is what gets read.
@visibleForTesting
Rect guidedScanFrame(Size size, DocumentType type) => MRZCameraOverlay.frameRect(
  size,
  type == DocumentType.passport ? MRZCameraOverlay.passportFrameRatio : MRZCameraOverlay.cardFrameRatio,
);

int _mrzLineCount(DocumentType type) => switch (type) {
  DocumentType.passport => 2,
  DocumentType.identityCard => 3,
  DocumentType.drivingLicence => 1,
};

/// The instructions under the scan frame: a card that shows only the step
/// and what to do, and opens (tap, or swipe up) to the tip and manual entry.
/// Kept closed it leaves the whole frame, and the text read along its bottom,
/// in view on smaller phones.
class _GuidedScanSheet extends StatefulWidget {
  const _GuidedScanSheet({
    required this.documentType,
    required this.onManualEntry,
    required this.stepNumber,
    required this.totalSteps,
  });

  final DocumentType documentType;
  final VoidCallback onManualEntry;
  final int stepNumber;
  final int totalSteps;

  @override
  State<_GuidedScanSheet> createState() => _GuidedScanSheetState();
}

class _GuidedScanSheetState extends State<_GuidedScanSheet> {
  static const _duration = Duration(milliseconds: 280);

  bool _expanded = false;

  /// Stays true while the tip collapses, so it shrinks with its content.
  bool _tipMounted = false;

  void _expand() {
    if (!_expanded) {
      setState(() {
        _expanded = true;
        _tipMounted = true;
      });
    }
  }

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final l10n = context.l10n;
    final docType = widget.documentType.name;
    final (title, tip) = (l10n.scanSheetTitle(docType), l10n.scanSheetTip(docType));
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -100) _expand();
        if (velocity > 100) _collapse();
      },
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _expanded,
                hint: _expanded ? l10n.scanHideTips : l10n.scanShowTips,
                child: InkWell(
                  onTap: _expanded ? _collapse : _expand,
                  // The arrow turning is the feedback; a highlight greys half the card.
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(color: g.border, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GuidedStepLabel(step: widget.stepNumber, total: widget.totalSteps),
                                  const SizedBox(height: 4),
                                  GuidedHeading(title, style: g.heading(18, height: 1.3)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: _duration,
                              curve: Curves.easeOutCubic,
                              child: Icon(Icons.keyboard_arrow_up, color: g.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedAlign(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: _expanded ? 1 : 0,
                  onEnd: () {
                    if (!_expanded && _tipMounted) setState(() => _tipMounted = false);
                  },
                  child: AnimatedOpacity(
                    opacity: _expanded ? 1 : 0,
                    duration: _duration,
                    child: _tipMounted
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(tip, style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText)),
                                const SizedBox(height: 16),
                                GuidedButton(
                                  label: l10n.scanEnterDetailsManually,
                                  kind: GuidedButtonKind.secondary,
                                  onPressed: widget.onManualEntry,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ),
              ),
            ],
          ),
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

Widget _defaultScannerBuilder({
  required DocumentType documentType,
  required MrzScanPicture scanPicture,
  required MrzScannedWithPicture onSuccess,
}) {
  return ScannerPage(documentType: documentType, scanPicture: scanPicture, onSuccess: onSuccess);
}

Widget _guidedScannerBuilder({
  required DocumentType documentType,
  required MrzScanPicture scanPicture,
  required MrzScannedWithPicture onSuccess,
}) {
  return ScannerPage(
    documentType: documentType,
    scanPicture: scanPicture,
    onSuccess: onSuccess,
    frame: ScanFrame.caller,
  );
}
