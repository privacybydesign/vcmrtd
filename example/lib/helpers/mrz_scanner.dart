import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../routing.dart';
import '../providers/ocr_engine_provider.dart';
import 'camera_viewfinder.dart';
import 'mrz_helper.dart';

class MRZScanner extends ConsumerStatefulWidget {
  const MRZScanner({
    Key? controller,
    required this.onSuccess,
    this.initialDirection = CameraLensDirection.back,
    this.showOverlay = true,
    this.documentType = DocumentType.passport,
    @visibleForTesting this.initializeCamera = true,
    @visibleForTesting this.googleMlKitOcrForTesting,
  }) : super(key: controller);

  final Function(dynamic mrzResult, List<String> lines) onSuccess;
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

class MRZScannerState extends ConsumerState<MRZScanner> with RouteAware {
  static const MethodChannel _ocrChannel = MethodChannel('tesseract_ocr');

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
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _canProcess = false;
    _textRecognizerInstance?.close();
    super.dispose();
  }

  @override
  void didPopNext() {
    _canProcess = true;
    _isBusy = false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEngine = ref.watch(ocrEngineProvider);

    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      initializeCamera: widget.initializeCamera,
      onImage: (frame) => _processFrame(frame, selectedEngine),
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
      widget.onSuccess(parsedRaw, lines);
      return true;
    }
    final correctedStrict = MRZHelper.fixForDocType(widget.documentType, lines);
    if (correctedStrict != null) {
      final parsedStrict = _parseScannedText(correctedStrict);
      if (parsedStrict != null) {
        _canProcess = false;
        widget.onSuccess(parsedStrict, correctedStrict);
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  dynamic debugParseScannedText(List<String> lines) => _parseScannedText(lines);

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

  dynamic _parseScannedText(List<String> lines) {
    try {
      switch (widget.documentType) {
        case DocumentType.passport:
          return PassportMrzParser().parse(lines);
        case DocumentType.identityCard:
          return IdCardMrzParser().parse(lines);
        case DocumentType.drivingLicence:
          return DrivingLicenceMrzParser().parse(lines);
      }
    } catch (_) {
      return null;
    }
  }
}
