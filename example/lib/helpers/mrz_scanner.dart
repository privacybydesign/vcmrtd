import 'dart:io';
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

/// Shared [TextRecognizer] managed by Riverpod so it is properly disposed.
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

  /// When true, a recognition call is in flight — drop incoming frames.
  bool _isBusy = false;

  /// Set to false after a successful scan; reset when navigating back.
  bool _canProcess = true;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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
    // Screen became visible again — allow scanning.
    _canProcess = true;
    _isBusy = false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(ocrEngineProvider);

    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      onFrame: (frame) => _processFrame(frame, engine),
    );
  }

  // ---------------------------------------------------------------------------
  // Frame dispatcher
  // ---------------------------------------------------------------------------

  Future<void> _processFrame(CameraFrame frame, OcrEngine engine) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      if (engine == OcrEngine.googleMlKit) {
        await _runGoogleMlKitOcr(frame);
      } else if (engine == OcrEngine.tesseract4android) {
        await _runTesseractOcr(frame);
      }
    } finally {
      // Only release the busy-lock if we haven't already stopped processing
      // (i.e. a successful scan sets _canProcess = false).
      if (_canProcess) _isBusy = false;
    }
  }

  // ===========================================================================
  // GOOGLE ML KIT PIPELINE
  // Works on both Android and iOS — exactly like the original working version.
  // ===========================================================================

  Future<void> _runGoogleMlKitOcr(CameraFrame frame) async {
    final inputImage = _buildMlKitInputImage(frame);
    if (inputImage == null) return;

    try {
      final recognizedText = await ref.read(textRecognizerProvider).processImage(inputImage);
      final fullText = recognizedText.text;
      if (fullText.trim().isEmpty) return;

      // Use the ML Kit normalizer (preserves original working behaviour).
      final lines = fullText
          .replaceAll(' ', '')
          .split('\n')
          .map(MRZHelper.testTextLine)
          .where((s) => s.isNotEmpty)
          .toList();

      _tryParse(lines);
    } catch (e) {
      debugPrint('ML Kit OCR error: $e');
    }
  }

  /// Builds an [InputImage] from a [CameraFrame].
  ///
  /// Android: converts YUV420 → NV21, uses the Y-plane's actual bytesPerRow.
  /// iOS:     uses the single BGRA8888 plane directly with its bytesPerRow.
  ///
  /// This matches what the original working ML Kit viewfinder did internally.
  InputImage? _buildMlKitInputImage(CameraFrame frame) {
    final image = frame.image;

    if (Platform.isAndroid) {
      // YUV420 has 3 planes; convert to NV21.
      if (image.planes.length < 3) return null;
      return InputImage.fromBytes(
        bytes: _yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          // After our manual YUV→NV21 conversion the bytes are written
          // without padding, so bytesPerRow equals the image width.
          bytesPerRow: image.width,
        ),
      );
    } else {
      // iOS: BGRA8888 has a single plane.
      if (image.planes.isEmpty) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
  }

  // ===========================================================================
  // TESSERACT 4 ANDROID PIPELINE (Android only)
  // The provider guarantees this engine is never selected on iOS.
  // ===========================================================================

  Future<void> _runTesseractOcr(CameraFrame frame) async {
    final image = frame.image;
    if (image.planes.length < 3) return;

    // Compute normalised ROI from overlay ↔ preview screen rects.
    final roi = _normaliseRoi(frame.overlayRect, frame.previewRect);

    try {
      final String? res = await _ocrChannel.invokeMethod<String>('processImage', {
        'bytes': _yuv420ToNv21(image),
        'width': image.width,
        'height': image.height,
        'stride': image.width,
        'rotation': frame.rotation,
        'lang': 'ocrb',
        'roiLeft': roi.left,
        'roiTop': roi.top,
        'roiWidth': roi.width,
        'roiHeight': roi.height,
      });

      final text = res ?? '';
      if (text.trim().isEmpty) return;

      // Use the Tesseract normalizer.
      final lines = text
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(MRZHelper.normalizeLine)
          .where((s) => s.isNotEmpty)
          .toList();

      _tryParse(lines);
    } catch (e) {
      debugPrint('Tesseract OCR error: $e');
    }
  }

  /// Converts overlay and preview screen rects into normalised ROI fractions
  /// (0..1) relative to the preview rect.
  Rect _normaliseRoi(Rect overlayRect, Rect previewRect) {
    final intersection = overlayRect.intersect(previewRect);
    final roi = intersection.isEmpty ? previewRect : intersection;

    return Rect.fromLTWH(
      ((roi.left - previewRect.left) / previewRect.width).clamp(0.0, 1.0),
      ((roi.top - previewRect.top) / previewRect.height).clamp(0.0, 1.0),
      (roi.width / previewRect.width).clamp(0.0, 1.0),
      (roi.height / previewRect.height).clamp(0.0, 1.0),
    );
  }

  // ===========================================================================
  // SHARED: YUV420 → NV21 byte conversion (used by both Android pipelines)
  // ===========================================================================

  Uint8List _yuv420ToNv21(CameraImage img) {
    final w = img.width;
    final h = img.height;
    final ySize = w * h;
    final nv21 = Uint8List(ySize + w * h ~/ 2);

    // Copy Y plane.
    nv21.setRange(0, ySize, img.planes[0].bytes);

    // Interleave V and U (NV21 = VUVU…).
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
  // SHARED: MRZ parsing — used by both pipelines
  // ===========================================================================

  /// Tries to parse [lines] as MRZ, with optional OCR-fix fallback.
  void _tryParse(List<String> lines) {
    final finalLines = MRZHelper.getFinalListToParse(lines);
    if (finalLines == null) return;

    // First attempt: parse the raw lines.
    final result = _parse(finalLines);
    if (result != null) {
      _succeed(result, finalLines);
      return;
    }

    // Second attempt: apply OCR corrections and retry.
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
    } catch (_) {
      return null;
    }
  }

  void _succeed(dynamic result, List<String> lines) {
    _canProcess = false;
    widget.onSuccess(result, lines);
  }
}
