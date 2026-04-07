import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _VerificationState { idle, recording, processing, result }

Uint8List _readFileBytes(String path) => File(path).readAsBytesSync();

class VerificationResult {
  final double matchScore;
  final bool isLive;

  const VerificationResult({
    required this.matchScore,
    required this.isLive,
  });
}

class FaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;

  static const double matchThreshold = 0.6;

  const FaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {
  static const int _recordingDuration = 3; // record duration in seconds, more needed for active liveness or more accurate passive liveness
  static const MethodChannel _channel =
  MethodChannel('foundation.privacybydesign.vcmrtd/face_verification');

  CameraController? _cameraController;
  VerificationResult? _result;
  String? _errorMessage;
  Timer? _countdownTimer;

  _VerificationState _state = _VerificationState.idle;
  int _countdown = _recordingDuration;
  bool _cameraOpening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _state == _VerificationState.idle &&
        (_cameraController == null ||
            _cameraController?.value.isInitialized != true)) {
      _openCamera();
    }
  }

  Future<void> _openCamera() async {
    if (_cameraOpening) return;
    if (_cameraController?.value.isInitialized == true) return;

    _cameraOpening = true;
    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      final front = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not open camera: $e');
      }
    } finally {
      _cameraOpening = false;
    }
  }

  Future<void> _startRecording() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isRecordingVideo) return;

    try {
      await ctrl.startVideoRecording();
      if (!mounted) return;

      setState(() {
        _state = _VerificationState.recording;
        _countdown = _recordingDuration;
        _errorMessage = null;
      });

      _countdownTimer?.cancel();
      _countdownTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) async {
            if (!mounted) {
              timer.cancel();
              return;
            }

            if (_countdown > 1) {
              setState(() => _countdown--);
              return;
            }

            setState(() => _countdown = 0);
            timer.cancel();
            await _stopRecordingAndVerify();
          });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not start recording: $e');
      }
    }
  }

  Future<void> _stopRecordingAndVerify() async {
    _countdownTimer?.cancel();

    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isRecordingVideo) return;

    try {
      final videoFile = await ctrl.stopVideoRecording();
      await ctrl.dispose();

      if (!mounted) return;

      setState(() {
        _cameraController = null;
        _state = _VerificationState.processing;
      });

      final videoBytes = await compute(_readFileBytes, videoFile.path);
      await _runVerification(videoBytes);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not stop recording: $e');
      }
    }
  }

  Future<void> _runVerification(Uint8List videoBytes) async {
    try {
      final result =
      await _channel.invokeMethod<Map>('verifyFaceAndLiveness', {
        'nfcImage': widget.nfcImageBytes,
        'videoBytes': videoBytes,
      });

      if (!mounted) return;

      setState(() {
        _result = VerificationResult(
          matchScore: (result?['matchScore'] as num?)?.toDouble() ?? 0.0,
          isLive: (result?['isLive'] as bool?) ?? false,
        );
        _state = _VerificationState.result;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.code == 'NO_FACE'
            ? 'No face detected. Please try again.'
            : 'Verification failed: ${e.message}';
        _state = _VerificationState.idle;
      });

      await _openCamera();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Verification failed: $e';
        _state = _VerificationState.idle;
      });

      await _openCamera();
    }
  }

  Future<void> _retry() async {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _result = null;
      _errorMessage = null;
      _state = _VerificationState.idle;
      _countdown = _recordingDuration;
    });

    await _openCamera();
  }

  void _handleBack() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    widget.onBackPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : switch (_state) {
          _VerificationState.idle => _buildIdle(),
          _VerificationState.recording => _buildRecording(),
          _VerificationState.processing => _buildProcessing(),
          _VerificationState.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text(
                'Opening camera…',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    final ready = _cameraController?.value.isInitialized == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              const Text(
                'Make sure your face is clearly visible and well lit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: ready ? _startRecording : null,
                icon: const Icon(Icons.videocam),
                label: const Text('Start Verification'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording… $_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Analyzing liveness and face match…',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final passed =
        result.matchScore > FaceVerificationScreen.matchThreshold &&
            result.isLive;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 80,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            passed ? 'Identity Verified' : 'Verification Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: passed ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Match score: ${(result.matchScore * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Liveness: ${result.isLive ? 'Live' : 'Not live'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: result.isLive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: _retry,
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
              onPressed: _handleBack,
              child: const Text('Go Back'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _retry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
