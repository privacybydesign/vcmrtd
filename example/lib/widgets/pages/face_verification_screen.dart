import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _VerificationState { idle, takingSelfie, reviewingSelfie, processing, result }

class FaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;

  const FaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  _VerificationState _state = _VerificationState.idle;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Uint8List? _selfieBytes;
  double? _matchScore;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      setState(() => _errorMessage = 'Could not access camera: $e');
    }
  }

  Future<void> _openCamera() async {
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() => _errorMessage = 'No camera available');
      return;
    }

    // Use the front camera, But first let me take a selfie
    final frontCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(frontCamera, ResolutionPreset.high);

    try {
      await _cameraController!.initialize();
      setState(() => _state = _VerificationState.takingSelfie);
    } catch (e) {
      setState(() => _errorMessage = 'Could not initialize camera: $e');
    }
  }

  Future<void> _takeSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      await _cameraController!.dispose();
      _cameraController = null;
      setState(() {
        _selfieBytes = bytes;
        _state = _VerificationState.reviewingSelfie;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not take photo: $e');
    }
  }

  Future<void> _retakeSelfie() async {
    setState(() {
      _selfieBytes = null;
      _state = _VerificationState.idle;
    });
  }

  static const _channel = MethodChannel('foundation.privacybydesign.vcmrtd/face_verification');

  Future<void> _startVerification() async {
    setState(() => _state = _VerificationState.processing);

    try {
      final score = await _channel.invokeMethod<double>('verifyFace', {
        'nfcImage': widget.nfcImageBytes,
        'selfieImage': _selfieBytes,
      });
      setState(() {
        _matchScore = score;
        _state = _VerificationState.result;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = e.code == 'NO_FACE'
            ? 'No face detected in one of the photos. Please try again.'
            : 'Verification failed: ${e.message}';
        _state = _VerificationState.idle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _cameraController?.dispose();
            widget.onBackPressed();
          },
        ),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : switch (_state) {
          _VerificationState.idle => _buildIdle(),
          _VerificationState.takingSelfie => _buildCamera(),
          _VerificationState.reviewingSelfie => _buildReview(),
          _VerificationState.processing => _buildProcessing(),
          _VerificationState.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildIdle() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.face, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Take a selfie to verify your identity',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure your face is clearly visible and well lit',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _openCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Selfie'),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(child: CameraPreview(_cameraController!)),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            onPressed: _takeSelfie,
            icon: const Icon(Icons.camera),
            label: const Text('Take Photo'),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Review your selfie',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_selfieBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retakeSelfie,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startVerification,
                  icon: const Icon(Icons.check),
                  label: const Text('Use this photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Verifying identity...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildResult() {
    // TODO: drempelwaarde bepalen na testen met het model begin met 50%
    final isMatch = (_matchScore ?? 0) > 0.6;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            size: 80,
            color: isMatch ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            isMatch ? 'Identity Verified' : 'Verification Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isMatch ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Match score: ${((_matchScore ?? 0) * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () => setState(() {
              _selfieBytes = null;
              _matchScore = null;
              _state = _VerificationState.idle;
            }),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onBackPressed,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}