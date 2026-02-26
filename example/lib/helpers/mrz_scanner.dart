import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../routing.dart';
import 'camera_viewfinder.dart';
import 'mrz_helper.dart';

class MRZScanner extends StatefulWidget {
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

class MRZScannerState extends State<MRZScanner> with RouteAware {

  static const MethodChannel _ocrChannel = MethodChannel('tesseract_ocr');

  bool _canProcess = true;
  bool _isBusy = false;
  DateTime _lastOcrAttempt = DateTime.fromMillisecondsSinceEpoch(0);

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
    super.dispose();
  }

  @override
  void didPopNext() {
    _canProcess = true;
    _isBusy = false;
    _lastOcrAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      onImage: _processFrame,
    );
  }

  Map<String, double> _mrzStripFromDocRoi({
    required double docLeft,
    required double docTop,
    required double docWidth,
    required double docHeight,
    required double startFrac,
    required double heightFrac,
    double insetXFrac = 0.04,
  }) {
    final roiTop    = (docTop + docHeight * startFrac).clamp(0.0, 1.0);
    final roiHeight = (docHeight * heightFrac).clamp(0.0, 1.0);
    final roiLeft   = (docLeft + docWidth * insetXFrac).clamp(0.0, 1.0);
    final roiWidth  = (docWidth * (1.0 - 2 * insetXFrac)).clamp(0.0, 1.0);

    return {
      'roiLeft':   roiLeft,
      'roiTop':    roiTop,
      'roiWidth':  roiWidth,
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

  Future<void> _processFrame(OcrFrame frame) async {
    if (!_canProcess || _isBusy) return;

    final now = DateTime.now();
    if (now.difference(_lastOcrAttempt).inMilliseconds < 10) return;
    _lastOcrAttempt = now;

    _isBusy = true;
    try {
      final docLeft = frame.roiLeft;
      final docTop  = frame.roiTop;
      final docW    = frame.roiWidth;
      final docH    = frame.roiHeight;

      final strips = _mrzRoiAttempts(
        docLeft: docLeft, docTop: docTop, docWidth: docW, docHeight: docH,
      );

      final attempts = [
        (label: 'full',                    l: docLeft,     t: docTop,     w: docW,        h: docH,        zone: false),
        (label: strips[0].label,           l: strips[0].l, t: strips[0].t, w: strips[0].w, h: strips[0].h, zone: false),
        (label: strips[1].label,           l: strips[1].l, t: strips[1].t, w: strips[1].w, h: strips[1].h, zone: false),
        (label: strips[2].label,           l: strips[2].l, t: strips[2].t, w: strips[2].w, h: strips[2].h, zone: false),
        (label: 'full-zone',               l: docLeft,     t: docTop,     w: docW,        h: docH,        zone: true),
        (label: '${strips[0].label}-zone', l: strips[0].l, t: strips[0].t, w: strips[0].w, h: strips[0].h, zone: true),
        (label: '${strips[1].label}-zone', l: strips[1].l, t: strips[1].t, w: strips[1].w, h: strips[1].h, zone: true),
        (label: '${strips[2].label}-zone', l: strips[2].l, t: strips[2].t, w: strips[2].w, h: strips[2].h, zone: true),
      ];

      for (final a in attempts) {
        if (!_canProcess) break;
        final ok = await _runOcr(
          frame:           frame,
          roiLeft:         a.l,
          roiTop:          a.t,
          roiWidth:        a.w,
          roiHeight:       a.h,
          label:           a.label,
          useZoneDetector: a.zone,
        );
        if (ok) break;
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<bool> _runOcr({
    required OcrFrame frame,
    required double roiLeft,
    required double roiTop,
    required double roiWidth,
    required double roiHeight,
    required String label,
    required bool useZoneDetector,
  }) async {
    if (!_canProcess) return false;

    final sw = Stopwatch()..start();

    try {
      final String? res = await _ocrChannel.invokeMethod<String>('ocrNv21', {
        'bytes':           frame.bytes,
        'width':           frame.width,
        'height':          frame.height,
        'rotation':        frame.rotation,
        'lang':            'ocrb',
        'roiLeft':         roiLeft,
        'roiTop':          roiTop,
        'roiWidth':        roiWidth,
        'roiHeight':       roiHeight,
        'useZoneDetector': useZoneDetector,
      });
      final text = res ?? '';

      debugPrint(
        "OCR($label): ${sw.elapsedMilliseconds}ms len=${text.length} "
            "roi=(${roiLeft.toStringAsFixed(3)},${roiTop.toStringAsFixed(3)},"
            "${roiWidth.toStringAsFixed(3)},${roiHeight.toStringAsFixed(3)}) "
            "zone=$useZoneDetector docType=${widget.documentType}",
      );

      final candidates = _extractCandidates(text, label);
      final finalLines = _selectFinalLines(candidates);

      if (finalLines != null) {
        _logLines("MRZ FINAL LINES [$label]", finalLines);

        final parsedRaw = _parseScannedText(finalLines);
        if (parsedRaw != null) {
          _logParsedResult(label, parsedRaw);
          _canProcess = false;
          widget.onSuccess(parsedRaw, finalLines);
          return true;
        }

        debugPrint("PARSE failed for $label -> dumping OCR lines/candidates");
        const maxChars = 400;
        final shown = text.length > maxChars ? "${text.substring(0, maxChars)}…<truncated>" : text;
        debugPrint("OCR($label) TEXT:\n$shown\n---");
        _logLines("OCR RAW LINES [$label]", text.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList());
        _logLines("OCR NORMALIZED CANDIDATES [$label]", candidates);

        final correctedStrict = MRZHelper.fixForDocType(widget.documentType, finalLines);
        if (correctedStrict != null) {
          final parsedStrict = _parseScannedText(correctedStrict);
          if (parsedStrict != null) {
            debugPrint("PARSE recovered via typed-field fixer ($label)");
            _logLines("MRZ CORRECTED LINES [$label]", correctedStrict);
            debugPrint("PARSE SUCCESS via fixer [$label]: $parsedStrict");
            _canProcess = false;
            widget.onSuccess(parsedStrict, correctedStrict);
            return true;
          }
        }
      }
      return false;

    } catch (e) {
      debugPrint("OCR($label): error $e");
      return false;
    }
  }

  void _logParsedResult(String label, dynamic result) {
    if (result is PassportMrzResult) {
      debugPrint('''
PARSE SUCCESS [$label] PassportMrzResult:
  documentType: ${result.documentType}
  countryCode: ${result.countryCode}
  surnames: ${result.surnames}
  givenNames: ${result.givenNames}
  documentNumber: ${result.documentNumber}
  nationalityCountryCode: ${result.nationalityCountryCode}
  birthDate: ${result.birthDate}
  sex: ${result.sex}
  expiryDate: ${result.expiryDate}
  personalNumber: ${result.personalNumber}
---''');
    } else if (result is DrivingLicenceMrzResult) {
      debugPrint('''
PARSE SUCCESS [$label] DrivingLicenceMrzResult:
  documentType: ${result.documentType}
  configuration: ${result.configuration}
  countryCode: ${result.countryCode}
  version: ${result.version}
  documentNumber: ${result.documentNumber}
  randomData: ${result.randomData}
---''');
    } else {
      debugPrint("PARSE SUCCESS [$label]: $result");
    }
  }

  void _logLines(String label, List<String> lines) {
    debugPrint(
      "$label (${lines.length} lines):\n"
          "${lines.asMap().entries.map((e) => "[${e.key}] (${e.value.length}) ${e.value}").join('\n')}\n---",
    );
  }

  List<String> _extractCandidates(String ocrText, String label) {
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
    if (best != null) {
      debugPrint("MRZ selected: ${best!.length} lines of len=${best!.first.length} for ${widget.documentType}");
    }
    return best;
  }

  dynamic _parseScannedText(List<String> lines) {
    final shape = "${lines.length}x${lines.isNotEmpty ? lines.first.length : 0}";
    final parserName = switch (widget.documentType) {
      DocumentType.passport      => "PassportMrzParser",
      DocumentType.identityCard  => "IdCardMrzParser",
      DocumentType.drivingLicence => "DrivingLicenceMrzParser",
    };

    try {
      debugPrint("PARSE start: docType=${widget.documentType} parser=$parserName shape=$shape");
      switch (widget.documentType) {
        case DocumentType.passport:
          return PassportMrzParser().parse(lines);
        case DocumentType.identityCard:
          return IdCardMrzParser().parse(lines);
        case DocumentType.drivingLicence:
          return DrivingLicenceMrzParser().parse(lines);
      }
    } on InvalidDocumentNumberException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): doc number check digit mismatch\n$e\n$st");
      return null;
    } on InvalidBirthDateException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): birth date check digit mismatch\n$e\n$st");
      return null;
    } on InvalidExpiryDateException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): expiry date check digit mismatch\n$e\n$st");
      return null;
    } on InvalidOptionalDataException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): optional data check digit mismatch\n$e\n$st");
      return null;
    } on InvalidMrzValueException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): final composite check digit mismatch\n$e\n$st");
      return null;
    } on InvalidMrzInputException catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): invalid input shape/length\n$e\n$st");
      return null;
    } catch (e, st) {
      debugPrint("PARSE FAIL ($parserName shape=$shape): other\n$e\n$st");
      return null;
    }
  }
}