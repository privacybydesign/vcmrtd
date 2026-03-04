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

      // Original normalization logic for ML Kit
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

  Future<void> _processTesseractFrame(OcrFrame frame) async {
    final docLeft = frame.roiLeft;
    final docTop = frame.roiTop;
    final docW = frame.roiWidth;
    final docH = frame.roiHeight;

    final strips = _mrzRoiAttempts(
      docLeft: docLeft,
      docTop: docTop,
      docWidth: docW,
      docHeight: docH,
    );

    final attempts = [
      (label: 'full', l: docLeft, t: docTop, w: docW, h: docH, zone: false),
      (label: strips[0].label, l: strips[0].l, t: strips[0].t, w: strips[0].w, h: strips[0].h, zone: false),
      (label: strips[1].label, l: strips[1].l, t: strips[1].t, w: strips[1].w, h: strips[1].h, zone: false),
      (label: strips[2].label, l: strips[2].l, t: strips[2].t, w: strips[2].w, h: strips[2].h, zone: false),
      (label: 'full-zone', l: docLeft, t: docTop, w: docW, h: docH, zone: true),
      (label: '${strips[0].label}-zone', l: strips[0].l, t: strips[0].t, w: strips[0].w, h: strips[0].h, zone: true),
      (label: '${strips[1].label}-zone', l: strips[1].l, t: strips[1].t, w: strips[1].w, h: strips[1].h, zone: true),
      (label: '${strips[2].label}-zone', l: strips[2].l, t: strips[2].t, w: strips[2].w, h: strips[2].h, zone: true),
    ];

    for (final a in attempts) {
      if (!_canProcess) break;
      final ok = await _runTesseractOcr(
        frame: frame,
        roiLeft: a.l,
        roiTop: a.t,
        roiWidth: a.w,
        roiHeight: a.h,
        label: a.label,
        useZoneDetector: a.zone,
      );
      if (ok) break;
    }
  }

  Future<bool> _runTesseractOcr({
    required OcrFrame frame,
    required double roiLeft,
    required double roiTop,
    required double roiWidth,
    required double roiHeight,
    required String label,
    required bool useZoneDetector,
  }) async {
    if (!_canProcess) return false;

    try {
      final String? res = await _ocrChannel.invokeMethod<String>('ocrNv21', {
        'bytes': frame.bytes,
        'width': frame.width,
        'height': frame.height,
        'rotation': frame.rotation,
        'lang': 'ocrb',
        'roiLeft': roiLeft,
        'roiTop': roiTop,
        'roiWidth': roiWidth,
        'roiHeight': roiHeight,
        'useZoneDetector': useZoneDetector,
      });
      final text = res ?? '';

      final candidates = _extractTesseractCandidates(text, label);
      final finalLines = _selectFinalLines(candidates);

      if (finalLines != null) {
        final parsedRaw = _parseScannedText(finalLines);
        if (parsedRaw != null) {
          _canProcess = false;
          widget.onSuccess(parsedRaw, finalLines);
          return true;
        }

        final correctedStrict = MRZHelper.fixForDocType(widget.documentType, finalLines);
        if (correctedStrict != null) {
          final parsedStrict = _parseScannedText(correctedStrict);
          if (parsedStrict != null) {
            _canProcess = false;
            widget.onSuccess(parsedStrict, correctedStrict);
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- Tesseract Helper Methods ---

  Map<String, double> _mrzStripFromDocRoi({
    required double docLeft,
    required double docTop,
    required double docWidth,
    required double docHeight,
    required double startFrac,
    required double heightFrac,
    double insetXFrac = 0.04,
  }) {
    final roiTop = (docTop + docHeight * startFrac).clamp(0.0, 1.0);
    final roiHeight = (docHeight * heightFrac).clamp(0.0, 1.0);
    final roiLeft = (docLeft + docWidth * insetXFrac).clamp(0.0, 1.0);
    final roiWidth = (docWidth * (1.0 - 2 * insetXFrac)).clamp(0.0, 1.0);

    return {
      'roiLeft': roiLeft,
      'roiTop': roiTop,
      'roiWidth': roiWidth,
      'roiHeight': roiHeight,
    };
  }

  List<({String label, double l, double t, double w, double h})> _mrzRoiAttempts({
    required double docLeft,
    required double docTop,
    required double docWidth,
    required double docHeight,
  }) {
    final a = _mrzStripFromDocRoi(
      docLeft: docLeft, docTop: docTop, docWidth: docWidth, docHeight: docHeight,
      startFrac: 0.68, heightFrac: 0.30, insetXFrac: 0.04,
    );
    final b = _mrzStripFromDocRoi(
      docLeft: docLeft, docTop: docTop, docWidth: docWidth, docHeight: docHeight,
      startFrac: 0.58, heightFrac: 0.40, insetXFrac: 0.04,
    );
    final c = _mrzStripFromDocRoi(
      docLeft: docLeft, docTop: docTop, docWidth: docWidth, docHeight: docHeight,
      startFrac: 0.45, heightFrac: 0.55, insetXFrac: 0.04,
    );

    return [
      (label: 'mrz-A-bottom30', l: a['roiLeft']!, t: a['roiTop']!, w: a['roiWidth']!, h: a['roiHeight']!),
      (label: 'mrz-B-bottom40', l: b['roiLeft']!, t: b['roiTop']!, w: b['roiWidth']!, h: b['roiHeight']!),
      (label: 'mrz-C-bottom55', l: c['roiLeft']!, t: c['roiTop']!, w: c['roiWidth']!, h: c['roiHeight']!),
    ];
  }

  List<String> _extractTesseractCandidates(String ocrText, String label) {
    final rawLines = ocrText
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final candidates = <String>[];
    for (final line in rawLines) {
      final t = MRZHelper.normalizeLine(line);
      if (t.isNotEmpty) candidates.add(t);
    }

    return candidates;
  }

  List<String>? _selectFinalLines(List<String> candidates) {
    if (candidates.isEmpty) return null;

    List<String>? best;
    int bestScore = -999999;

    void consider(List<String> w) {
      final ok = MRZHelper.getFinalListToParse(w);
      if (ok == null) return;
      final score = MRZHelper.scoreBlock(ok);
      if (score > bestScore) {
        bestScore = score;
        best = ok;
      }
    }

    void consider1LineOfLen(int len) {
      for (final a in candidates) {
        if (a.length == len) consider([a]);
      }
    }

    void consider2LineOfLen(int len) {
      for (int i = 0; i + 1 < candidates.length; i++) {
        final a = candidates[i];
        final b = candidates[i + 1];
        if (a.length == len && b.length == len) consider([a, b]);
      }
    }

    void consider3LineOfLen(int len) {
      for (int i = 0; i + 2 < candidates.length; i++) {
        final a = candidates[i];
        final b = candidates[i + 1];
        final c = candidates[i + 2];
        if (a.length == len && b.length == len && c.length == len) consider([a, b, c]);
      }
    }

    switch (widget.documentType) {
      case DocumentType.passport:
        consider2LineOfLen(44);
        if (best != null) return best;
        consider2LineOfLen(36);
        break;
      case DocumentType.identityCard:
        consider3LineOfLen(30);
        if (best != null) return best;
        consider2LineOfLen(36);
        break;
      case DocumentType.drivingLicence:
        consider1LineOfLen(30);
        if (best != null) return best;
        break;
    }
    return best;
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
    } on InvalidDocumentNumberException {
      return null;
    } on InvalidBirthDateException {
      return null;
    } on InvalidExpiryDateException {
      return null;
    } on InvalidOptionalDataException {
      return null;
    } on InvalidMrzValueException {
      return null;
    } on InvalidMrzInputException {
      return null;
    } catch (e) {
      return null;
    }
  }
}
