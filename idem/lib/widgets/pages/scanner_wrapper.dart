// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
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
      required ValueChanged<DocumentType> onWrongDocument,
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

  /// What the last MRZ read showed when it was the other card type.
  DocumentType? _wrongDocument;

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

  void _onWrongDocument(DocumentType found) {
    if (_wrongDocument != found) setState(() => _wrongDocument = found);
  }

  @override
  Widget build(BuildContext context) {
    return _buildGuided(context, context.guided);
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
                onWrongDocument: _onWrongDocument,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => CustomPaint(
                    painter: GuidedScanFramePainter(
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
                    wrongDocument: _wrongDocument,
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
  DocumentType.identityCard || DocumentType.residencePermit => 3,
  DocumentType.drivingLicence => 1,
};

/// The instructions under the scan frame: a card that shows only the step
/// and what to do, and opens (tap, or swipe up) to the tip and manual entry.
/// Kept closed it leaves the whole frame, and the text read along its bottom,
/// in view on smaller phones.
class _GuidedScanSheet extends StatelessWidget {
  const _GuidedScanSheet({
    required this.documentType,
    required this.wrongDocument,
    required this.onManualEntry,
    required this.stepNumber,
    required this.totalSteps,
  });

  final DocumentType documentType;
  final DocumentType? wrongDocument;
  final VoidCallback onManualEntry;
  final int stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final l10n = context.l10n;
    final docType = documentType.name;
    return GuidedSheet(
      label: GuidedStepLabel(step: stepNumber, total: totalSteps),
      title: l10n.scanSheetTitle(docType),
      showTip: l10n.scanShowTips,
      hideTip: l10n.scanHideTips,
      notice: switch (wrongDocument) {
        final found? => Text(
          '${l10n.wrongDocumentTitle(found.name)}. ${l10n.wrongDocumentHint(found.name)}',
          style: TextStyle(fontSize: 15, height: 1.4, color: g.error),
        ),
        null => null,
      },
      tip: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.scanSheetTip(docType), style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText)),
          const SizedBox(height: 16),
          GuidedButton(
            label: l10n.scanEnterDetailsManually,
            kind: GuidedButtonKind.secondary,
            onPressed: onManualEntry,
          ),
        ],
      ),
    );
  }
}

Widget _guidedScannerBuilder({
  required DocumentType documentType,
  required MrzScanPicture scanPicture,
  required MrzScannedWithPicture onSuccess,
  required ValueChanged<DocumentType> onWrongDocument,
}) {
  return ScannerPage(
    documentType: documentType,
    scanPicture: scanPicture,
    onSuccess: onSuccess,
    onWrongDocument: onWrongDocument,
    frame: ScanFrame.caller,
  );
}
