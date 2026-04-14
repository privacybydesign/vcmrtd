import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:twentyface_flutter/twentyface_flutter.dart';

/// Screen that continuously matches camera frames against a reference image.
///
/// Shows real-time feedback on whether a face is detected and the match percentage.
class ContinuousMatchScreen extends StatefulWidget {
  final FaceVerificationService service;
  final Uint8List referenceImage;
  final ImageType referenceImageType;
  final FaceVerificationConfig config;

  const ContinuousMatchScreen({
    super.key,
    required this.service,
    required this.referenceImage,
    this.referenceImageType = ImageType.jpeg,
    this.config = const FaceVerificationConfig(),
  });

  @override
  State<ContinuousMatchScreen> createState() => _ContinuousMatchScreenState();
}

class _ContinuousMatchScreenState extends State<ContinuousMatchScreen> {
  CameraController? _cameraController;
  Timer? _matchTimer;
  String? _error;

  bool _isProcessing = false;
  bool _faceDetected = false;
  double? _similarityPercentage;
  bool? _isMatch;
  int _matchCount = 0;
  List<FaceDetection> _detections = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
        _startMatchLoop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera error: $e');
      }
    }
  }

  void _startMatchLoop() {
    _matchTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _matchFrame(),
    );
  }

  Future<void> _matchFrame() async {
    if (_isProcessing || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    _isProcessing = true;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // First detect faces to give quick feedback
      final detections = await widget.service.detectFaces(
        bytes,
        config: widget.config,
      );

      if (!mounted) return;

      final hasFace = detections.isNotEmpty && detections.first.isOverallOk;

      if (!hasFace) {
        setState(() {
          _faceDetected = false;
          _similarityPercentage = null;
          _isMatch = null;
          _detections = detections;
        });
        _isProcessing = false;
        return;
      }

      // Face found — run comparison
      final result = await widget.service.compareFaces(
        liveImage: bytes,
        referenceImage: widget.referenceImage,
        referenceImageType: widget.referenceImageType,
        config: widget.config,
      );

      if (!mounted) return;

      _matchCount++;
      setState(() {
        _faceDetected = true;
        _similarityPercentage = result.similarityPercentage;
        _isMatch = result.match;
        _detections = detections;
      });
    } catch (e) {
      debugPrint('Match error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null ? _buildError() : _buildCamera(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: AspectRatio(
            aspectRatio: 1 / _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Face overlay
        CustomPaint(
          painter: FaceOverlayPainter(
            detections: _detections,
            isReady: _faceDetected,
          ),
          child: Container(),
        ),

        // Back button
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        // Reference image thumbnail (top right)
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 64,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                widget.referenceImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // Real-time feedback overlay at bottom
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: _buildFeedbackPanel(),
        ),
      ],
    );
  }

  Widget _buildFeedbackPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Face detection status
          Row(
            children: [
              Icon(
                _faceDetected ? Icons.face : Icons.face_retouching_off,
                color: _faceDetected ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _faceDetected ? 'Face detected' : 'No face detected',
                  style: TextStyle(
                    color: _faceDetected ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_matchCount > 0)
                Text(
                  '#$_matchCount',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Match percentage
          if (_similarityPercentage != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_similarityPercentage! / 100).clamp(0.0, 1.0),
                      minHeight: 20,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isMatch == true ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_similarityPercentage!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _isMatch == true ? Colors.green : Colors.orange,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isMatch == true ? 'MATCH' : 'NO MATCH',
              style: TextStyle(
                color: _isMatch == true ? Colors.green[300] : Colors.orange[300],
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ] else ...[
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _faceDetected ? 'Comparing...' : 'Waiting for face',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
