import 'dart:typed_data';

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

/// Single shared [TextRecognizer] for the app lifetime.
/// ML Kit loads its TFLite models on first use (~500 ms). One instance means
/// that load only ever happens once, not on every navigation.
final textRecognizerProvider = Provider<TextRecognizer>((ref) {
  final recognizer = TextRecognizer();
  ref.onDispose(recognizer.close);
  return recognizer;
});

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
  static const MethodChannel _ocrChannel = MethodChannel('tesseract_ocr');

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
    super.dispose();
  }

  @override
  void didPopNext() {
    _canProcess = true;
    _isBusy = false;
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(ocrEngineProvider);

    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      onImage: (frame) => _processFrame(frame, engine),
    );
  }

  Future<void> _processFrame(OcrFrame frame, OcrEngine engine) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      switch (engine) {
        case OcrEngine.googleMlKit:
          await _runGoogleMlKitOcr(frame);
        case OcrEngine.tesseract4android:
          await _runTesseractOcr(frame);
      }
    } finally {
      if (_canProcess) _isBusy = false;
    }
  }

  // ===========================================================================
  // GOOGLE ML KIT PIPELINE
  // Android: yuv420 → NV21 → InputImage → TextRecognizer
  // iOS:     bgra8888 plane → InputImage → TextRecognizer
  // ===========================================================================

  Future<void> _runGoogleMlKitOcr(OcrFrame frame) async {
    final inputImage = _buildMlKitInputImage(frame);
    if (inputImage == null) return;

    final recognizedText = await ref.read(textRecognizerProvider).processImage(inputImage);
    final fullText = recognizedText.text;
    if (fullText.trim().isEmpty) return;

    final lines = fullText
        .replaceAll(' ', '')
        .split('\n')
        .map(MRZHelper.testTextLine)
        .where((s) => s.isNotEmpty)
        .toList();

    _tryParse(lines);
  }

  InputImage? _buildMlKitInputImage(OcrFrame frame) {
    final image = frame.image;

    if (frame.format == FrameFormat.nv21) {
      if (image.planes.length < 3) return null;
      return InputImage.fromBytes(
        bytes: _yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } else {
      if (image.planes.isEmpty) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
  }

  // ===========================================================================
  // TESSERACT PIPELINE (Android only)
  // yuv420 → NV21 bytes + ROI → native channel → text → MRZHelper
  // ===========================================================================

  Future<void> _runTesseractOcr(OcrFrame frame) async {
    final image = frame.image;
    if (image.planes.length < 3) return;

    final String? res = await _ocrChannel.invokeMethod<String>('processImage', {
      'bytes':     _yuv420ToNv21(image),
      'width':     image.width,
      'height':    image.height,
      'stride':    image.width,
      'rotation':  frame.rotation,
      'lang':      'ocrb',
      'roiLeft':   frame.roiLeft,
      'roiTop':    frame.roiTop,
      'roiWidth':  frame.roiWidth,
      'roiHeight': frame.roiHeight,
    });

    final text = res ?? '';
    if (text.trim().isEmpty) return;

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(MRZHelper.normalizeLine)
        .where((s) => s.isNotEmpty)
        .toList();

    _tryParse(lines);
  }

  // ===========================================================================
  // SHARED BYTE CONVERSION
  // ===========================================================================

  Uint8List _yuv420ToNv21(CameraImage img) {
    final w = img.width;
    final h = img.height;
    final ySize = w * h;
    final nv21 = Uint8List(ySize + w * h ~/ 2);

    nv21.setRange(0, ySize, img.planes[0].bytes);

    final u = img.planes[1];
    final v = img.planes[2];
    final uPixel = u.bytesPerPixel ?? 1;
    final vPixel = v.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < h ~/ 2; row++) {
      final uRow = row * u.bytesPerRow;
      final vRow = row * v.bytesPerRow;
      for (int col = 0; col < w ~/ 2; col++) {
        nv21[uvIndex++] = v.bytes[vRow + col * vPixel];
        nv21[uvIndex++] = u.bytes[uRow + col * uPixel];
      }
    }
    return nv21;
  }

  // ===========================================================================
  // SHARED MRZ PARSING
  // ===========================================================================

  void _tryParse(List<String> lines) {
    final finalLines = MRZHelper.getFinalListToParse(lines);
    if (finalLines == null) return;

    final result = _parse(finalLines);
    if (result != null) {
      _succeed(result, finalLines);
      return;
    }

    final corrected = MRZHelper.fixForDocType(widget.documentType, finalLines);
    if (corrected == null) return;

    final correctedResult = _parse(corrected);
    if (correctedResult != null) _succeed(correctedResult, corrected);
  }

  dynamic _parse(List<String> lines) {
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

  void _succeed(dynamic result, List<String> lines) {
    _canProcess = false;
    widget.onSuccess(result, lines);
  }
}