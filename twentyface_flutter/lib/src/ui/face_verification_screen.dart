import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../face_verification_service.dart';
import 'face_overlay_painter.dart';
import 'verification_result_widget.dart';

/// Feedback message for face positioning.
enum PositionFeedback {
  noFace('Position your face in the oval'),
  tooFar('Move closer'),
  tooClose('Move back'),
  tooLeft('Move right'),
  tooRight('Move left'),
  tooHigh('Move down'),
  tooLow('Move up'),
  rotated('Face the camera directly'),
  blurry('Hold still'),
  overexposed('Reduce lighting'),
  multipleFaces('Only one face please'),
  ready('Hold still...');

  final String message;
  const PositionFeedback(this.message);
}

/// Full-screen face verification widget with camera preview.
///
/// Provides a complete verification flow including:
/// - Camera preview with face guide overlay
/// - Real-time face detection and positioning feedback
/// - Auto-capture when face is properly positioned
/// - Liveness check
/// - Result display with retry option
class FaceVerificationScreen extends StatefulWidget {
  /// Reference image (e.g., DG2 passport photo) to compare against.
  final Uint8List referenceImage;

  /// Type of the reference image.
  final ImageType referenceImageType;

  /// Verification configuration.
  final FaceVerificationConfig config;

  /// Callback when verification completes (success or failure).
  final void Function(FaceComparisonResult result) onResult;

  /// Callback when user cancels verification.
  final VoidCallback? onCancel;

  /// Instruction text shown above the camera preview.
  final String? instructionText;

  /// Color of the overlay outside the face guide.
  final Color? overlayColor;

  /// Custom loading widget shown during verification.
  final Widget? loadingWidget;

  /// Whether to auto-capture when face is ready.
  final bool autoCapture;

  /// Delay before auto-capture in milliseconds.
  final int autoCaptureDelay;

  /// Pre-initialized face verification service.
  /// If not provided, the screen will expect the service to be initialized externally.
  final FaceVerificationService? service;

  const FaceVerificationScreen({
    super.key,
    required this.referenceImage,
    required this.onResult,
    this.referenceImageType = ImageType.jpeg,
    this.config = const FaceVerificationConfig(),
    this.onCancel,
    this.instructionText,
    this.overlayColor,
    this.loadingWidget,
    this.autoCapture = true,
    this.autoCaptureDelay = 1500,
    this.service,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  List<FaceDetection> _detections = [];
  PositionFeedback _feedback = PositionFeedback.noFace;
  bool _isReady = false;
  bool _isProcessing = false;
  bool _isVerifying = false;
  FaceComparisonResult? _result;
  Timer? _autoCaptureTimer;
  Timer? _detectionTimer;
  String? _error;
  String _debugStatus = 'Initializing...';
  int _detectionCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() => _debugStatus = 'Finding cameras...');
      final cameras = await availableCameras();
      setState(() => _debugStatus = 'Found ${cameras.length} camera(s)');

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      setState(() => _debugStatus = 'Using ${frontCamera.lensDirection.name} camera');

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      setState(() => _debugStatus = 'Initializing camera...');
      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _debugStatus = 'Camera ready, starting detection...');
        _startDetectionLoop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize camera: $e';
          _debugStatus = 'Camera error: $e';
        });
      }
    }
  }

  void _startDetectionLoop() {
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _detectFaces(),
    );
  }

  Future<void> _detectFaces() async {
    if (_isProcessing || _isVerifying || _cameraController == null) {
      return;
    }
    if (!_cameraController!.value.isInitialized) {
      setState(() => _debugStatus = 'Camera not initialized');
      return;
    }

    _isProcessing = true;
    _detectionCount++;

    try {
      setState(() => _debugStatus = 'Capturing frame #$_detectionCount...');

      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      if (widget.service == null) {
        setState(() => _debugStatus = 'No service provided');
        _isProcessing = false;
        return;
      }

      if (!widget.service!.isInitialized) {
        setState(() => _debugStatus = 'Service not initialized!');
        _isProcessing = false;
        return;
      }

      setState(() => _debugStatus = 'Detecting faces (${bytes.length} bytes)...');

      final detections = await widget.service!.detectFaces(
        bytes,
        config: widget.config,
      );

      if (!mounted) return;

      final feedback = _analyzeDetections(detections);
      final isReady = feedback == PositionFeedback.ready;

      setState(() {
        _detections = detections;
        _feedback = feedback;
        _isReady = isReady;
        _debugStatus = 'Found ${detections.length} face(s) - ${feedback.message}';
      });

      if (isReady && widget.autoCapture) {
        _scheduleAutoCapture(bytes);
      } else {
        _autoCaptureTimer?.cancel();
        _autoCaptureTimer = null;
      }
    } catch (e, stackTrace) {
      debugPrint('Face detection error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _debugStatus = 'Detection error: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  PositionFeedback _analyzeDetections(List<FaceDetection> detections) {
    if (detections.isEmpty) {
      return PositionFeedback.noFace;
    }

    if (detections.length > 1) {
      return PositionFeedback.multipleFaces;
    }

    final detection = detections.first;
    final status = detection.status;

    if (status.qualitycheckBlurry) {
      return PositionFeedback.blurry;
    }
    if (status.qualitycheckOverexposed) {
      return PositionFeedback.overexposed;
    }
    if (status.qualitycheckRotated) {
      return PositionFeedback.rotated;
    }
    if (status.detectionTooSmall) {
      return PositionFeedback.tooFar;
    }

    // Check face position relative to center
    final rect = detection.normalizedRect;
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;

    // Ideal center is around 0.5, 0.5
    if (centerX < 0.35) return PositionFeedback.tooLeft;
    if (centerX > 0.65) return PositionFeedback.tooRight;
    if (centerY < 0.35) return PositionFeedback.tooHigh;
    if (centerY > 0.65) return PositionFeedback.tooLow;

    // Check if face is too big (too close)
    if (rect.width > 0.8 || rect.height > 0.8) {
      return PositionFeedback.tooClose;
    }

    // Check overall status
    if (!detection.isOverallOk) {
      return PositionFeedback.noFace;
    }

    return PositionFeedback.ready;
  }

  void _scheduleAutoCapture(Uint8List capturedImage) {
    if (_autoCaptureTimer != null) return;

    _autoCaptureTimer = Timer(
      Duration(milliseconds: widget.autoCaptureDelay),
      () {
        if (_isReady && !_isVerifying) {
          _performVerification(capturedImage);
        }
      },
    );
  }

  Future<void> _performVerification(Uint8List liveImage) async {
    if (_isVerifying || widget.service == null) return;

    setState(() {
      _isVerifying = true;
      _detectionTimer?.cancel();
    });

    try {
      final result = await widget.service!.compareFaces(
        liveImage: liveImage,
        referenceImage: widget.referenceImage,
        referenceImageType: widget.referenceImageType,
        config: widget.config,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _isVerifying = false;
      });

      widget.onResult(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _error = 'Verification failed: $e';
        });
        _startDetectionLoop();
      }
    }
  }

  Future<void> _captureManually() async {
    if (_cameraController == null || _isVerifying) return;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      await _performVerification(bytes);
    } catch (e) {
      setState(() {
        _error = 'Capture failed: $e';
      });
    }
  }

  void _retry() {
    setState(() {
      _result = null;
      _error = null;
      _isReady = false;
      _detections = [];
    });
    _startDetectionLoop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildErrorView();
    }

    if (_result != null) {
      return _buildResultView();
    }

    if (_isVerifying) {
      return _buildVerifyingView();
    }

    return _buildCameraView();
  }

  Widget _buildCameraView() {
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
            isReady: _isReady,
            guideColor: widget.overlayColor ?? Colors.white,
          ),
          child: Container(),
        ),

        // Instruction text
        Positioned(
          top: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                widget.instructionText ?? 'Position your face in the oval',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildFeedbackChip(),
            ],
          ),
        ),

        // Cancel button
        if (widget.onCancel != null)
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: widget.onCancel,
            ),
          ),

        // Manual capture button (when not auto-capture or for testing)
        if (!widget.autoCapture)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCaptureButton(),
            ),
          ),

        // Debug status display
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _debugStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_detections.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Face: ${_detections.first.status.isOverallOk ? "OK" : "Issues"} | '
                    'Score: ${_detections.first.score.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _detections.first.status.isOverallOk
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackChip() {
    final color = _isReady ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isReady ? Icons.check_circle : Icons.info_outline,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _feedback.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isReady ? _captureManually : null,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isReady ? Colors.white : Colors.white.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: _isReady
            ? const Icon(Icons.camera, color: Colors.black, size: 32)
            : null,
      ),
    );
  }

  Widget _buildVerifyingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.loadingWidget ??
              const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Verifying...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const LivenessStatusWidget(isChecking: true),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: VerificationResultWidget(
          result: _result!,
          onRetry: _retry,
          onConfirm: widget.onCancel,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
