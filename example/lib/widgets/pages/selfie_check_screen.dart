import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:vcmrtd/vcmrtd.dart' show ImageType;
import 'package:vcmrtdapp/services/face_match_service.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/profile_picture.dart';

/// Screen that captures a selfie and compares it to the document photo.
///
/// Reimplements the selfie check flow from multipaz-samples:
/// 1. Show front camera preview
/// 2. User captures a selfie
/// 3. Extract face embeddings from both the selfie and document photo
/// 4. Calculate and display cosine similarity percentage
class SelfieCheckScreen extends StatefulWidget {
  final Uint8List documentPhotoBytes;
  final ImageType documentPhotoType;
  final VoidCallback onBack;

  const SelfieCheckScreen({
    super.key,
    required this.documentPhotoBytes,
    required this.documentPhotoType,
    required this.onBack,
  });

  @override
  State<SelfieCheckScreen> createState() => _SelfieCheckScreenState();
}

enum _SelfieCheckState {
  initializing,
  cameraReady,
  capturing,
  processing,
  result,
  error,
}

class _SelfieCheckScreenState extends State<SelfieCheckScreen> {
  CameraController? _cameraController;
  final FaceMatchService _faceMatchService = FaceMatchService();

  _SelfieCheckState _state = _SelfieCheckState.initializing;
  String? _errorMessage;
  double? _similarity;
  String? _selfieFilePath;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _faceMatchService.initialize();
      await _initCamera();
      if (mounted) {
        setState(() => _state = _SelfieCheckState.cameraReady);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SelfieCheckState.error;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
  }

  bool _isCapturing = false;

  Future<void> _captureSelfie() async {
    if (_isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }
    _isCapturing = true;

    setState(() => _state = _SelfieCheckState.capturing);

    try {
      final photo = await _cameraController!.takePicture();
      _selfieFilePath = photo.path;

      // Let camera plugin finish its internal callbacks before disposing.
      await _disposeCamera();

      if (!mounted) return;
      setState(() => _state = _SelfieCheckState.processing);
      await _performFaceMatch(photo.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SelfieCheckState.error;
          _errorMessage = 'Failed to capture selfie: $e';
        });
      }
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;

    // Short delay so the camera plugin can finish posting its state callbacks
    // before we tear down the controller (avoids "Reply already submitted").
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await controller.dispose();
    } catch (_) {
      // Ignore dispose errors – the controller is being discarded anyway.
    }
  }

  Future<void> _performFaceMatch(String selfiePath) async {
    try {
      // If the document photo is JPEG2000, convert to JPEG first.
      // The Dart `image` package and ML Kit cannot decode JP2 natively.
      Uint8List documentJpegBytes = widget.documentPhotoBytes;
      if (widget.documentPhotoType == ImageType.jpeg2000) {
        final converted = await decodeImage(widget.documentPhotoBytes, null);
        if (converted == null) {
          if (mounted) {
            setState(() {
              _state = _SelfieCheckState.error;
              _errorMessage =
                  'Could not convert the JPEG2000 document photo. '
                  'Selfie check is not supported for this document.';
            });
          }
          return;
        }
        documentJpegBytes = converted;
      }

      // Extract embeddings from both images in parallel
      final results = await Future.wait([
        _faceMatchService.getEmbeddingFromFile(selfiePath),
        _faceMatchService.getEmbeddingFromBytes(documentJpegBytes),
      ]);

      final selfieEmbedding = results[0];
      final documentEmbedding = results[1];

      if (selfieEmbedding == null || documentEmbedding == null) {
        if (mounted) {
          setState(() {
            _state = _SelfieCheckState.error;
            _errorMessage =
                'Could not detect a face in ${selfieEmbedding == null ? 'the selfie' : 'the document photo'}. '
                'Please ensure the face is clearly visible and try again.';
          });
        }
        return;
      }

      final similarity = _faceMatchService.calculateSimilarity(
        selfieEmbedding,
        documentEmbedding,
      );

      if (mounted) {
        setState(() {
          _similarity = similarity;
          _state = _SelfieCheckState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SelfieCheckState.error;
          _errorMessage = 'Face matching failed: $e';
        });
      }
    }
  }

  Future<void> _retry() async {
    // Dispose current camera if still around
    await _disposeCamera();

    // Clean up previous selfie
    if (_selfieFilePath != null) {
      try {
        await File(_selfieFilePath!).delete();
      } catch (_) {}
      _selfieFilePath = null;
    }

    if (!mounted) return;
    setState(() {
      _state = _SelfieCheckState.initializing;
      _similarity = null;
      _errorMessage = null;
    });

    try {
      await _initCamera();
      if (mounted) {
        setState(() => _state = _SelfieCheckState.cameraReady);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SelfieCheckState.error;
          _errorMessage = 'Failed to restart camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    // Fire-and-forget; the controller is going away with the widget.
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          controller.dispose();
        } catch (_) {}
      });
    }
    _faceMatchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selfie Check'),
        leading: IconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: switch (_state) {
          _SelfieCheckState.initializing => _buildInitializing(),
          _SelfieCheckState.cameraReady => _buildCameraPreview(),
          _SelfieCheckState.capturing => _buildCameraPreview(capturing: true),
          _SelfieCheckState.processing => _buildProcessing(),
          _SelfieCheckState.result => _buildResult(),
          _SelfieCheckState.error => _buildError(),
        },
      ),
    );
  }

  Widget _buildInitializing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing camera and face detection...'),
        ],
      ),
    );
  }

  Widget _buildCameraPreview({bool capturing = false}) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1 / _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
              // Face guide overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _FaceGuideOverlayPainter(),
                ),
              ),
              if (capturing)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Position your face within the oval and tap the button below',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        const SizedBox(height: 24),
        // Capture button
        SizedBox(
          width: 72,
          height: 72,
          child: ElevatedButton(
            onPressed: capturing ? null : _captureSelfie,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Icon(Icons.camera_alt, size: 32),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selfieFilePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_selfieFilePath!),
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Comparing faces...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Detecting faces and computing similarity',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final similarityPercent = ((_similarity ?? 0) * 100).round();
    final isMatch = similarityPercent >= 50;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Photos side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPhotoCard(
                'Document',
                ProfilePictureWidget(
                  imageData: widget.documentPhotoBytes,
                  imageType: widget.documentPhotoType,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.compare_arrows,
                size: 32,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 16),
              _buildPhotoCard(
                'Selfie',
                _selfieFilePath != null
                    ? Image.file(
                        File(_selfieFilePath!),
                        width: 120,
                        height: 150,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 120,
                        height: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, size: 48),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Similarity result
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isMatch ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMatch ? Colors.green[300]! : Colors.orange[300]!,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isMatch ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 48,
                  color: isMatch ? Colors.green[600] : Colors.orange[600],
                ),
                const SizedBox(height: 12),
                Text(
                  'Similarity: $similarityPercent%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isMatch ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMatch
                      ? 'The faces appear to match.'
                      : 'The faces may not match. Try again with better lighting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMatch ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String label, Widget image) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws an oval face guide overlay on the camera preview.
class _FaceGuideOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.55;
    final ovalHeight = ovalWidth * 1.35;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
