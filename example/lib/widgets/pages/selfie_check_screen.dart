import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:vcmrtd/vcmrtd.dart' show ImageType;
import 'package:vcmrtdapp/services/face_match_service.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';
import 'package:vcmrtdapp/services/selfie_liveness_service.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/profile_picture.dart';

/// Screen that performs liveness detection followed by face matching.
///
/// Flow:
/// 1. Intro screen explaining the liveness check
/// 2. Real-time liveness verification (head movements, eye closure, smile, etc.)
/// 3. Auto-capture selfie on liveness success
/// 4. Compare selfie to document photo using FaceNet embeddings
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

enum _ScreenState {
  initializing,
  livenessIntro,
  livenessActive,
  livenessFailed,
  capturing,
  processing,
  result,
  error,
}

class _SelfieCheckScreenState extends State<SelfieCheckScreen> {
  // ── Camera ──────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _frontCameraIndex = 0;

  // ── Face detection for liveness ─────────────────────────────
  late final FaceDetector _livenessFaceDetector;
  bool _isDetecting = false;

  // ── Services ────────────────────────────────────────────────
  final FaceMatchService _faceMatchService = FaceMatchService();
  final SelfieLivenessService _livenessService = SelfieLivenessService();

  // ── Screen state ────────────────────────────────────────────
  _ScreenState _state = _ScreenState.initializing;
  String? _errorMessage;
  double? _similarity;
  String? _selfieFilePath;
  bool _isCapturing = false;

  // ── Liveness UI state ───────────────────────────────────────
  LivenessFeedback? _currentFeedback;
  LivenessStep _currentLivenessStep = LivenessStep.initial;
  int _countdownSeconds = 10;
  double _countdownProgress = 1.0;
  List<bool> _gazeSectorStates =
      List.filled(SelfieLivenessService.gazeCircleSectors, false);

  // ── InputImage helpers ──────────────────────────────────────
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _livenessFaceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _setupLivenessCallbacks();
    _initialize();
  }

  @override
  void dispose() {
    _livenessService.dispose();
    _livenessFaceDetector.close();
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

  // ── Initialization ──────────────────────────────────────────

  void _setupLivenessCallbacks() {
    _livenessService.onStepChanged = (step) {
      if (mounted) {
        setState(() {
          _currentLivenessStep = step;
          _gazeSectorStates = _livenessService.gazeSectorStates;
        });
      }
    };

    _livenessService.onFeedbackChanged = (feedback) {
      if (mounted) {
        setState(() {
          _currentFeedback = feedback;
          if (_currentLivenessStep == LivenessStep.circularGaze) {
            _gazeSectorStates = _livenessService.gazeSectorStates;
          }
        });
      }
    };

    _livenessService.onCountdownTick = (seconds, progress) {
      if (mounted) {
        setState(() {
          _countdownSeconds = seconds;
          _countdownProgress = progress;
        });
      }
    };

    _livenessService.onCompleted = _onLivenessCompleted;

    _livenessService.onFailed = () {
      if (mounted) {
        _stopImageStream();
        setState(() => _state = _ScreenState.livenessFailed);
      }
    };
  }

  Future<void> _initialize() async {
    try {
      await _faceMatchService.initialize();
      await _initCamera();
      _livenessService.initialize();
      if (mounted) {
        setState(() => _state = _ScreenState.livenessIntro);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _frontCameraIndex = _cameras.indexOf(frontCamera);

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

  // ── Liveness flow ───────────────────────────────────────────

  void _startLivenessCheck() {
    _livenessService.startVerification();
    setState(() => _state = _ScreenState.livenessActive);
    _cameraController?.startImageStream(_onCameraFrame);
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isDetecting || _state != _ScreenState.livenessActive) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _livenessFaceDetector.processImage(inputImage);
      if (faces.isNotEmpty && _state == _ScreenState.livenessActive) {
        // Compute effective image size in the coordinate space ML Kit returns.
        final rotation = inputImage.metadata?.rotation;
        Size imageSize;
        if (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg) {
          imageSize = Size(image.height.toDouble(), image.width.toDouble());
        } else {
          imageSize = Size(image.width.toDouble(), image.height.toDouble());
        }
        _livenessService.onFaceDetected(faces.first, imageSize);
      }
    } catch (_) {
      // Ignore detection errors during streaming.
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _onLivenessCompleted() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      await _stopImageStream();

      if (mounted) {
        setState(() => _state = _ScreenState.capturing);
      }

      // Brief delay for camera to settle after stopping stream.
      await Future.delayed(const Duration(milliseconds: 300));

      final photo = await _cameraController!.takePicture();
      _selfieFilePath = photo.path;

      await _disposeCamera();

      if (!mounted) return;
      setState(() => _state = _ScreenState.processing);
      await _performFaceMatch(photo.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'Failed to capture selfie: $e';
        });
      }
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _stopImageStream() async {
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        await _cameraController?.stopImageStream();
      }
    } catch (_) {}
  }

  // ── Camera disposal ─────────────────────────────────────────

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;

    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await controller.dispose();
    } catch (_) {}
  }

  // ── Face matching ───────────────────────────────────────────

  Future<void> _performFaceMatch(String selfiePath) async {
    try {
      Uint8List documentJpegBytes = widget.documentPhotoBytes;
      if (widget.documentPhotoType == ImageType.jpeg2000) {
        final converted = await decodeImage(widget.documentPhotoBytes, null);
        if (converted == null) {
          if (mounted) {
            setState(() {
              _state = _ScreenState.error;
              _errorMessage =
                  'Could not convert the JPEG2000 document photo. '
                  'Selfie check is not supported for this document.';
            });
          }
          return;
        }
        documentJpegBytes = converted;
      }

      final results = await Future.wait([
        _faceMatchService.getEmbeddingFromFile(selfiePath),
        _faceMatchService.getEmbeddingFromBytes(documentJpegBytes),
      ]);

      final selfieEmbedding = results[0];
      final documentEmbedding = results[1];

      if (selfieEmbedding == null || documentEmbedding == null) {
        if (mounted) {
          setState(() {
            _state = _ScreenState.error;
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
          _state = _ScreenState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'Face matching failed: $e';
        });
      }
    }
  }

  // ── Retry ───────────────────────────────────────────────────

  Future<void> _retryLiveness() async {
    await _stopImageStream();
    await _disposeCamera();

    if (_selfieFilePath != null) {
      try {
        await File(_selfieFilePath!).delete();
      } catch (_) {}
      _selfieFilePath = null;
    }

    _livenessService.resetForRetry();

    if (!mounted) return;
    setState(() {
      _state = _ScreenState.initializing;
      _similarity = null;
      _errorMessage = null;
      _currentFeedback = null;
      _currentLivenessStep = LivenessStep.initial;
      _gazeSectorStates =
          List.filled(SelfieLivenessService.gazeCircleSectors, false);
    });

    try {
      await _initCamera();
      _livenessService.initialize();
      if (mounted) {
        setState(() => _state = _ScreenState.livenessIntro);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'Failed to restart camera: $e';
        });
      }
    }
  }

  // ── InputImage conversion (from camera_viewfinder.dart) ─────

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameras[_frontCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // Handle YUV420 → NV21 conversion on Android.
    if (format == null ||
        (Platform.isAndroid && format == InputImageFormat.yuv_420_888)) {
      final nv21Bytes = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    if ((Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _yuv420ToNv21(CameraImage img) {
    final int width = img.width;
    final int height = img.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    nv21.setRange(0, ySize, img.planes[0].bytes);

    final u = img.planes[1];
    final v = img.planes[2];
    final int uRowStride = u.bytesPerRow;
    final int vRowStride = v.bytesPerRow;
    final int uPixelStride = u.bytesPerPixel ?? 1;
    final int vPixelStride = v.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      int uRowStart = row * uRowStride;
      int vRowStart = row * vRowStride;
      for (int col = 0; col < width ~/ 2; col++) {
        nv21[uvIndex++] = v.bytes[vRowStart + col * vPixelStride];
        nv21[uvIndex++] = u.bytes[uRowStart + col * uPixelStride];
      }
    }
    return nv21;
  }

  // ── Build ───────────────────────────────────────────────────

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
          _ScreenState.initializing => _buildInitializing(),
          _ScreenState.livenessIntro => _buildLivenessIntro(),
          _ScreenState.livenessActive => _buildLivenessActive(),
          _ScreenState.livenessFailed => _buildLivenessFailed(),
          _ScreenState.capturing => _buildCapturing(),
          _ScreenState.processing => _buildProcessing(),
          _ScreenState.result => _buildResult(),
          _ScreenState.error => _buildError(),
        },
      ),
    );
  }

  // ── State builders ──────────────────────────────────────────

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

  Widget _buildLivenessIntro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.face,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Liveness Verification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'To verify your identity you will be asked to perform a '
              'series of head movements. All analysis happens on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure you are in a well-lit area and position your '
              'face clearly in front of the camera.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startLivenessCheck,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Verification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivenessActive() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final isGazeStep = _currentLivenessStep == LivenessStep.circularGaze;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewSize =
                    min(constraints.maxWidth - 48, constraints.maxHeight - 48)
                        .clamp(200.0, 350.0);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular camera preview
                    SizedBox(
                      width: previewSize,
                      height: previewSize,
                      child: ClipOval(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: SizedBox(
                            width: previewSize,
                            height: previewSize *
                                _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                    // Progress ring / gaze sectors overlay
                    SizedBox(
                      width: previewSize + 16,
                      height: previewSize + 16,
                      child: CustomPaint(
                        painter: isGazeStep
                            ? _GazeSectorPainter(
                                sectorStates: _gazeSectorStates,
                              )
                            : _CountdownRingPainter(
                                progress: _countdownProgress,
                                color: Theme.of(context).primaryColor,
                              ),
                      ),
                    ),
                    // Direction arrow overlay
                    if (_isRotationStep)
                      SizedBox(
                        width: previewSize + 80,
                        height: previewSize + 80,
                        child: _buildDirectionArrow(),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        // Instruction card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _stepTitle,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  if (_currentFeedback != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentFeedback!.message,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Countdown
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '${_countdownSeconds}s remaining',
            style: TextStyle(
              fontSize: 14,
              color:
                  _countdownSeconds <= 3 ? Colors.red : Colors.grey[600],
              fontWeight: _countdownSeconds <= 3
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  bool get _isRotationStep {
    return _currentLivenessStep == LivenessStep.rotateHeadLeft ||
        _currentLivenessStep == LivenessStep.rotateHeadRight ||
        _currentLivenessStep == LivenessStep.rotateHeadUp ||
        _currentLivenessStep == LivenessStep.rotateHeadDown;
  }

  String get _stepTitle {
    return switch (_currentLivenessStep) {
      LivenessStep.centerFace => 'Center Your Face',
      LivenessStep.rotateHeadLeft => 'Turn Head Left',
      LivenessStep.rotateHeadRight => 'Turn Head Right',
      LivenessStep.rotateHeadUp => 'Tilt Head Up',
      LivenessStep.rotateHeadDown => 'Tilt Head Down',
      LivenessStep.circularGaze => 'Look Around',
      LivenessStep.closeEyes => 'Close Your Eyes',
      LivenessStep.smile => 'Smile',
      LivenessStep.lookStraight => 'Look Straight Ahead',
      _ => 'Verifying...',
    };
  }

  Widget _buildDirectionArrow() {
    IconData icon;
    Alignment alignment;

    switch (_currentLivenessStep) {
      case LivenessStep.rotateHeadLeft:
        icon = Icons.arrow_back;
        alignment = Alignment.centerLeft;
      case LivenessStep.rotateHeadRight:
        icon = Icons.arrow_forward;
        alignment = Alignment.centerRight;
      case LivenessStep.rotateHeadUp:
        icon = Icons.arrow_upward;
        alignment = Alignment.topCenter;
      case LivenessStep.rotateHeadDown:
        icon = Icons.arrow_downward;
        alignment = Alignment.bottomCenter;
      default:
        return const SizedBox.shrink();
    }

    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildLivenessFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off, size: 64, color: Colors.orange[400]),
            const SizedBox(height: 16),
            Text(
              'Verification Timed Out',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentFeedback?.message ??
                  'The verification step could not be completed in time. '
                      'Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _retryLiveness,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Capturing selfie...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
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
                color:
                    isMatch ? Colors.green[300]! : Colors.orange[300]!,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isMatch
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  size: 48,
                  color:
                      isMatch ? Colors.green[600] : Colors.orange[600],
                ),
                const SizedBox(height: 12),
                Text(
                  'Similarity: $similarityPercent%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isMatch
                        ? Colors.green[800]
                        : Colors.orange[800],
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
                    color: isMatch
                        ? Colors.green[700]
                        : Colors.orange[700],
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
                  onPressed: _retryLiveness,
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
                  onPressed: _retryLiveness,
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

// ── Custom painters ─────────────────────────────────────────────

/// Draws a countdown ring around the face preview circle.
class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CountdownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progress > 0.3 ? color : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Draws gaze sector indicators around the face preview circle.
class _GazeSectorPainter extends CustomPainter {
  final List<bool> sectorStates;

  _GazeSectorPainter({required this.sectorStates});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final sectorCount = sectorStates.length;
    final sectorAngle = 2 * pi / sectorCount;
    const gap = 0.06; // gap between sectors in radians

    for (int i = 0; i < sectorCount; i++) {
      final startAngle = -pi / 2 + i * sectorAngle + gap / 2;
      final sweepAngle = sectorAngle - gap;

      final paint = Paint()
        ..color = sectorStates[i]
            ? Colors.green
            : Colors.grey.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sectorStates[i] ? 6.0 : 4.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GazeSectorPainter old) =>
      !_listsEqual(old.sectorStates, sectorStates);

  static bool _listsEqual(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
