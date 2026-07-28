import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'camera_viewfinder.dart';
import 'mrz_helper.dart';
import 'ocr_engine.dart';
import 'scanned_mrz.dart';

/// Called with the MRZ that was read and the MRZ lines it was parsed from.
typedef MrzScannedCallback = void Function(ScannedMRZ mrz, List<String> lines);

class MRZScanner extends StatefulWidget {
  const MRZScanner({
    Key? controller,
    required this.onSuccess,
    required this.engine,
    this.routeObserver,
    this.initialDirection = CameraLensDirection.back,
    this.showOverlay = true,
    this.documentType = DocumentType.passport,
    @visibleForTesting this.initializeCamera = true,
    @visibleForTesting this.googleMlKitOcrForTesting,
  }) : super(key: controller);

  final MrzScannedCallback onSuccess;

  /// The OCR engine to read frames with. It is read per frame, so a caller can
  /// hand the scanner a value it rebuilds on and the change takes effect on the
  /// next frame.
  final OcrEngine engine;

  /// The caller's route observer. It is passed on to the camera view so the live
  /// feed pauses while another route is on top of the scanner, and it is what
  /// re-arms scanning when the scanner comes back to the top.
  ///
  /// Optional, but note what is lost without one: a successful parse stops
  /// processing so [onSuccess] fires once per document, and the observer's pop
  /// callback is the only thing that resumes it on its own. A caller that passes
  /// no observer has a single-shot scanner until it calls
  /// [MRZScannerState.resumeScanning], which it can reach through the
  /// `MRZController` it passed as `controller`.
  final RouteObserver<ModalRoute<void>>? routeObserver;

  final CameraLensDirection initialDirection;
  final bool showOverlay;
  final DocumentType documentType;
  @visibleForTesting
  final bool initializeCamera;
  @visibleForTesting
  final Future<List<String>?> Function(OcrFrame frame)? googleMlKitOcrForTesting;

  @override
  MRZScannerState createState() => MRZScannerState();
}

class MRZScannerState extends State<MRZScanner> with RouteAware {
  static const MethodChannel _ocrChannel = MethodChannel('tesseract_ocr');
  static final Logger _log = Logger('MRZScanner');

  // Lazily instantiated — ML Kit model is not loaded until actually needed.
  TextRecognizer? _textRecognizerInstance;
  TextRecognizer get _textRecognizer => _textRecognizerInstance ??= TextRecognizer();

  bool _canProcess = true;
  bool _isBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      widget.routeObserver?.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    _canProcess = false;
    _textRecognizerInstance?.close();
    super.dispose();
  }

  /// Starts reading frames again after a successful scan.
  ///
  /// A successful parse stops processing so [MRZScanner.onSuccess] is reported
  /// once per document. Callers that pass a [MRZScanner.routeObserver] get this
  /// for free when the scanner's route comes back to the top; callers that do
  /// not have to call this themselves to read the next document.
  void resumeScanning() {
    _canProcess = true;
    _isBusy = false;
  }

  @override
  void didPopNext() => resumeScanning();

  @override
  Widget build(BuildContext context) {
    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      initializeCamera: widget.initializeCamera,
      routeObserver: widget.routeObserver,
      onImage: (frame) => _processFrame(frame, widget.engine),
    );
  }

  // Tesseract is Android-only; iOS always uses ML Kit.
  Future<void> _processFrame(OcrFrame frame, OcrEngine engine) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;
    try {
      if (engine == OcrEngine.tesseract4android && Platform.isAndroid) {
        await _processTesseractFrame(frame);
      } else {
        await _runGoogleMlKitOcr(frame);
      }
    } finally {
      _isBusy = false;
    }
  }

  // ===========================================================================
  // GOOGLE ML KIT OCR ENGINE
  // ===========================================================================

  Future<void> _runGoogleMlKitOcr(OcrFrame frame) async {
    try {
      final googleMlKitOcrForTesting = widget.googleMlKitOcrForTesting;
      if (googleMlKitOcrForTesting != null) {
        final finalLines = await googleMlKitOcrForTesting(frame);
        if (finalLines != null) _tryParseAndNotify(finalLines);
        return;
      }

      final inputImage = InputImage.fromBytes(
        bytes: frame.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: frame.isNv21 ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: frame.bytesPerRow,
        ),
      );

      final recognizedText = await _textRecognizer.processImage(inputImage);

      final lines = recognizedText.text
          .replaceAll(' ', '')
          .split('\n')
          .map(MRZHelper.testTextLine)
          .where((s) => s.isNotEmpty)
          .toList();

      final finalLines = MRZHelper.getFinalListToParse(lines);
      if (finalLines != null) _tryParseAndNotify(finalLines);
    } catch (_) {}
  }

  // ===========================================================================
  // TESSERACT OCR ENGINE (Android only)
  // ===========================================================================

  Future<void> _processTesseractFrame(OcrFrame frame) async {
    if (!_canProcess) return;

    try {
      final String? res = await _ocrChannel.invokeMethod<String>('processImage', {
        'bytes': frame.bytes,
        'width': frame.width,
        'height': frame.height,
        'stride': frame.width,
        'rotation': frame.rotation,
        'lang': 'ocrb',
        'roiLeft': frame.roiLeft,
        'roiTop': frame.roiTop,
        'roiWidth': frame.roiWidth,
        'roiHeight': frame.roiHeight,
      });

      final text = res ?? '';
      if (text.trim().isEmpty) return;

      final lines = text
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => MRZHelper.normalizeLine(s))
          .where((s) => s.isNotEmpty)
          .toList();

      final finalLines = MRZHelper.getFinalListToParse(lines);
      if (finalLines == null) return;

      _tryParseAndNotify(finalLines);
    } catch (_) {}
  }

  // ===========================================================================
  // SHARED PARSING LOGIC
  // ===========================================================================

  bool _tryParseAndNotify(List<String> lines) {
    final parsedRaw = _parseScannedText(lines);
    if (parsedRaw != null) {
      _canProcess = false;
      _notify(parsedRaw, lines);
      return true;
    }
    final correctedStrict = MRZHelper.fixForDocType(widget.documentType, lines);
    if (correctedStrict != null) {
      final parsedStrict = _parseScannedText(correctedStrict);
      if (parsedStrict != null) {
        _canProcess = false;
        _notify(parsedStrict, correctedStrict);
        return true;
      }
    }
    return false;
  }

  void _notify(ScannedMRZ mrz, List<String> lines) {
    _log.info('MRZ Scanned');
    _log.info(mrz.documentType.toString());
    widget.onSuccess(mrz, lines);
  }

  @visibleForTesting
  ScannedMRZ? debugParseScannedText(List<String> lines) => _parseScannedText(lines);

  @visibleForTesting
  bool debugTryParseAndNotify(List<String> lines) => _tryParseAndNotify(lines);

  @visibleForTesting
  Future<void> debugProcessFrame(OcrFrame frame, OcrEngine engine) => _processFrame(frame, engine);

  @visibleForTesting
  Future<void> debugProcessTesseractFrame(OcrFrame frame) => _processTesseractFrame(frame);

  @visibleForTesting
  bool get debugCanProcess => _canProcess;

  @visibleForTesting
  bool get debugIsBusy => _isBusy;

  ScannedMRZ? _parseScannedText(List<String> lines) {
    try {
      switch (widget.documentType) {
        case DocumentType.passport:
          return ScannedPassportMRZ.fromMRZResult(
            PassportMrzParser().parse(lines),
            documentType: DocumentType.passport,
          );
        case DocumentType.identityCard:
          return ScannedPassportMRZ.fromMRZResult(
            IdCardMrzParser().parse(lines),
            documentType: DocumentType.identityCard,
          );
        case DocumentType.drivingLicence:
          return ScannedDriverLicenseMRZ.fromMRZResult(DrivingLicenceMrzParser().parse(lines));
      }
    } catch (_) {
      return null;
    }
  }
}
