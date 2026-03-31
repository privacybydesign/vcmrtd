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
  }) : super(key: controller);

  final Function(dynamic mrzResult, List<String> lines) onSuccess;
  final CameraLensDirection initialDirection;
  final bool showOverlay;
  final DocumentType documentType;

  @override
  MRZScannerState createState() => MRZScannerState();
}

class MRZScannerState extends ConsumerState<MRZScanner> with RouteAware {
  // --- Common OCR State ---
  static const MethodChannel _ocrChannel = MethodChannel('tesseract_ocr');
  final TextRecognizer _textRecognizer = TextRecognizer();

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
    _textRecognizer.close();
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
      onImage: (frame) => _processFrame(frame, selectedEngine),
    );
  }

  /// Main dispatcher that chooses the engine based on UI selection
  Future<void> _processFrame(OcrFrame frame, OcrEngine engine) async {
    if (!_canProcess || _isBusy) return;

    _isBusy = true;
    try {
      if (engine == OcrEngine.tesseract4android) {
        await _processTesseractFrame(frame);
      } else {
        await _runGoogleMlKitOcr(frame);
      }
    } finally {
      _isBusy = false;
    }
  }

  // ===========================================================================
  // --- GOOGLE ML KIT OCR ENGINE ---
  // ===========================================================================

  Future<void> _runGoogleMlKitOcr(OcrFrame frame) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: frame.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );

      final recognizedText = await _textRecognizer.processImage(inputImage);
      String fullText = recognizedText.text;

      String trimmedText = fullText.replaceAll(' ', '');
      List allText = trimmedText.split('\n');

      List<String> ableToScanText = [];
      for (var e in allText) {
        final normalized = MRZHelper.testTextLine(e.toString());
        if (normalized.isNotEmpty) {
          ableToScanText.add(normalized);
        }
      }

      final finalLines = MRZHelper.getFinalListToParse(ableToScanText);

      if (finalLines != null) {
        final parsedRaw = _parseScannedText(finalLines);
        if (parsedRaw != null) {
          _canProcess = false;
          widget.onSuccess(parsedRaw, finalLines);
          return;
        }

        final correctedStrict = MRZHelper.fixForDocType(widget.documentType, finalLines);
        if (correctedStrict != null) {
          final parsedStrict = _parseScannedText(correctedStrict);
          if (parsedStrict != null) {
            _canProcess = false;
            widget.onSuccess(parsedStrict, correctedStrict);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('ML Kit OCR error: $e');
    }
  }

  // ===========================================================================
  // --- TESSERACT 4 ANDROID OCR ENGINE ---
  // ===========================================================================

  /// Single call to native — MrzZoneDetector runs automatically in the native
  /// layer, no need for multiple ROI attempts or useZoneDetector flag.
  Future<void> _processTesseractFrame(OcrFrame frame) async {
    if (!_canProcess) return;

    try {
      final plane = frame.bytes;

      final String? res = await _ocrChannel.invokeMethod<String>('processImage', {
        'bytes': plane,
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

      final parsedRaw = _parseScannedText(finalLines);
      if (parsedRaw != null) {
        _canProcess = false;
        widget.onSuccess(parsedRaw, finalLines);
        return;
      }

      final correctedStrict = MRZHelper.fixForDocType(widget.documentType, finalLines);
      if (correctedStrict != null) {
        final parsedStrict = _parseScannedText(correctedStrict);
        if (parsedStrict != null) {
          _canProcess = false;
          widget.onSuccess(parsedStrict, correctedStrict);
          return;
        }
      }
    } catch (e) {
      debugPrint('Tesseract OCR error: $e');
    }
  }

  // ===========================================================================
  // --- SHARED PARSING LOGIC ---
  // ===========================================================================

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
    } catch (e) {
      return null;
    }
  }
}
