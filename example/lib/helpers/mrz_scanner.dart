import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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

// =============================================================================
// Top-level function for isolate — must not reference any instance or class.
// =============================================================================

Uint8List _convertYuv420ToNv21(Map<String, dynamic> p) {
  final int w = p['w'];
  final int h = p['h'];
  final Uint8List yBytes = p['yBytes'];
  final Uint8List uBytes = p['uBytes'];
  final Uint8List vBytes = p['vBytes'];
  final int uBytesPerRow = p['uBytesPerRow'];
  final int vBytesPerRow = p['vBytesPerRow'];
  final int uPixelStride = p['uPixelStride'];
  final int vPixelStride = p['vPixelStride'];

  final ySize = w * h;
  final nv21 = Uint8List(ySize + w * h ~/ 2);

  nv21.setRange(0, ySize, yBytes);

  int uvIndex = ySize;
  for (int row = 0; row < h ~/ 2; row++) {
    final uRow = row * uBytesPerRow;
    final vRow = row * vBytesPerRow;
    for (int col = 0; col < w ~/ 2; col++) {
      nv21[uvIndex++] = vBytes[vRow + col * vPixelStride];
      nv21[uvIndex++] = uBytes[uRow + col * uPixelStride];
    }
  }
  return nv21;
}

// =============================================================================

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
      // ML Kit is fastest with direct NV21 from the camera (no conversion).
      // Tesseract needs YUV420 so we can convert + crop with ROI in the isolate.
      useNv21: engine == OcrEngine.googleMlKit,
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
      if (_canProcess) _isBusy = false;
    }
  }

  // ===========================================================================
  // GOOGLE ML KIT PIPELINE
  // Works on both Android and iOS.
  // ===========================================================================

  Future<void> _runGoogleMlKitOcr(CameraFrame frame) async {
    final inputImage = await _buildMlKitInputImage(frame);
    if (inputImage == null) return;

    try {
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
    } catch (e) {
      debugPrint('ML Kit OCR error: $e');
    }
  }

  /// Builds an [InputImage] from a [CameraFrame].
  ///
  /// If the camera already delivers NV21 (1 plane), uses it directly — no
  /// conversion needed, same speed as the original standalone ML Kit version.
  /// If the camera delivers YUV420 (3 planes), converts in an isolate.
  Future<InputImage?> _buildMlKitInputImage(CameraFrame frame) async {
    final image = frame.image;

    if (Platform.isAndroid) {
      final nv21 = await _getNv21Bytes(image);
      if (nv21 == null) return null;
      return InputImage.fromBytes(
        bytes: nv21.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: nv21.bytesPerRow,
        ),
      );
    } else {
      // iOS: BGRA8888 has a single plane — use directly.
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
  // ===========================================================================

  Future<void> _runTesseractOcr(CameraFrame frame) async {
    final image = frame.image;

    final nv21 = await _getNv21Bytes(image);
    if (nv21 == null) return;

    final roi = _normaliseRoi(frame.overlayRect, frame.previewRect);

    try {
      final String? res = await _ocrChannel.invokeMethod<String>('processImage', {
        'bytes': nv21.bytes,
        'width': image.width,
        'height': image.height,
        'stride': nv21.bytesPerRow,
        'rotation': frame.rotation,
        'lang': 'ocrb',
        'roiLeft': roi.left,
        'roiTop': roi.top,
        'roiWidth': roi.width,
        'roiHeight': roi.height,
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
    } catch (e) {
      debugPrint('Tesseract OCR error: $e');
    }
  }

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
  // SHARED: NV21 byte acquisition
  //
  // If the camera already delivers NV21 (1 plane) → use directly, zero cost.
  // If it delivers YUV420 (3 planes) → convert in an isolate off the UI thread.
  // ===========================================================================

  /// Simple container for NV21 bytes + the correct bytesPerRow.
  Future<_Nv21Frame?> _getNv21Bytes(CameraImage image) async {
    if (image.planes.length == 1) {
      // Camera delivered NV21 directly — same as the original ML Kit version.
      return _Nv21Frame(bytes: image.planes[0].bytes, bytesPerRow: image.planes[0].bytesPerRow);
    }
    if (image.planes.length >= 3) {
      // YUV420 — convert in isolate.
      final nv21 = await compute(_convertYuv420ToNv21, {
        'w': image.width,
        'h': image.height,
        'yBytes': Uint8List.fromList(image.planes[0].bytes),
        'uBytes': Uint8List.fromList(image.planes[1].bytes),
        'vBytes': Uint8List.fromList(image.planes[2].bytes),
        'uBytesPerRow': image.planes[1].bytesPerRow,
        'vBytesPerRow': image.planes[2].bytesPerRow,
        'uPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'vPixelStride': image.planes[2].bytesPerPixel ?? 1,
      });
      // After manual conversion there is no row padding.
      return _Nv21Frame(bytes: nv21, bytesPerRow: image.width);
    }
    return null;
  }

  // ===========================================================================
  // SHARED: MRZ parsing
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
    } catch (_) {
      return null;
    }
  }

  void _succeed(dynamic result, List<String> lines) {
    _canProcess = false;
    widget.onSuccess(result, lines);
  }
}

/// Holds NV21 bytes together with the correct bytesPerRow/stride value.
class _Nv21Frame {
  final Uint8List bytes;
  final int bytesPerRow;

  const _Nv21Frame({required this.bytes, required this.bytesPerRow});
}
