// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:mrz_capture/mrz_capture.dart';

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
      required bool capturePicture,
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
  final bool capturePicture;

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
    this.capturePicture = false,
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

  @override
  Widget build(BuildContext context) {
    final scannerBuilder = widget.scannerBuilder ?? _defaultScannerBuilder;

    return Scaffold(
      body: Stack(
        children: [
          scannerBuilder(
            documentType: widget.documentType,
            capturePicture: widget.capturePicture,
            onSuccess: (scannedMrz, picture) {
              if (!_hasNavigated) {
                _hasNavigated = true;
                widget.onMrzScanned(scannedMrz, picture);
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
            widget.capturePicture
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
}

Widget _defaultScannerBuilder({
  required DocumentType documentType,
  required bool capturePicture,
  required MrzScannedWithPicture onSuccess,
}) {
  return ScannerPage(documentType: documentType, capturePicture: capturePicture, onSuccess: onSuccess);
}
