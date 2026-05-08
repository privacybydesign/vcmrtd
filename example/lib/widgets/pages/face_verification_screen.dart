import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcmrtdapp/features/face_verification/face_verification_ui.dart';

export 'package:vcmrtdapp/features/face_verification/face_verification_ui.dart'
    show VerificationState, faceActionLabel, faceActionIcon;

class VerificationResult {
  final double matchScore;
  final bool isLive;
  const VerificationResult({required this.matchScore, required this.isLive});
}

/// NV21 packing — runs in a compute isolate.
/// Only called for the frame that is actually sent to the native side.
Uint8List? _packNv21Isolate(CameraImage image) {
  if (image.planes.length < 3) return null;

  final w = image.width;
  final h = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final uvPixelStride = vPlane.bytesPerPixel ?? 1;
  final uvRowStride = vPlane.bytesPerRow;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final uRowStride = uPlane.bytesPerRow;
  final yRowStride = yPlane.bytesPerRow;

  final uvHeight = h ~/ 2;
  final uvWidth = w ~/ 2;

  final out = Uint8List(8 + (w * h + uvHeight * uvWidth * 2));
  final header = ByteData.sublistView(out, 0, 8);
  header.setInt32(0, w, Endian.big);
  header.setInt32(4, h, Endian.big);

  var idx = 8;

  for (var row = 0; row < h; row++) {
    final rowStart = row * yRowStride;
    for (var col = 0; col < w; col++) {
      out[idx++] = yPlane.bytes[rowStart + col];
    }
  }

  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      final vIdx = row * uvRowStride + col * uvPixelStride;
      final uIdx = row * uRowStride + col * uPixelStride;
      if (vIdx < vPlane.bytes.length && uIdx < uPlane.bytes.length) {
        out[idx++] = vPlane.bytes[vIdx];
        out[idx++] = uPlane.bytes[uIdx];
      } else {
        out[idx++] = 128;
        out[idx++] = 128;
      }
    }
  }

  return out;
}

class FaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;
  final VoidCallback onBackPressed;
  final DateTime? photoIssueDate;

  const FaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    this.photoIssueDate,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> with WidgetsBindingObserver {
  static const _methodChannel = MethodChannel('foundation.privacybydesign.vcmrtd/face_verification');
  static const _eventChannel = EventChannel('foundation.privacybydesign.vcmrtd/liveness_events');
  static const Map<DeviceOrientation, int> _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _cameraController;
  CameraDescription? _activeCamera;
  StreamSubscription<dynamic>? _eventSub;

  VerificationResult? _result;
  String? _errorMessage;
  VerificationState _state = VerificationState.idle;

  List<String> _actions = <String>[];
  String? _currentAction;
  Set<String> _completedActions = <String>{};
  bool _extraActionMode = false;
  bool _actionFlash = false;

  bool _cameraOpening = false;
  bool _cameraClosing = false;
  bool _isDisposed = false;
  bool _activeLivenessStopping = false;
  bool _startingLiveness = false;

  CameraImage? _pendingImage;
  bool _isSending = false;
  int _frameToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeEverything());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_stopActiveFlow(disposeCamera: true));
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _state == VerificationState.idle &&
        (_cameraController == null || _cameraController?.value.isInitialized != true)) {
      _openCamera();
    }
  }

  Future<void> _disposeEverything() async {
    await _stopActiveFlow(disposeCamera: true);
  }

  Future<void> _stopActiveFlow({required bool disposeCamera}) async {
    if (_cameraClosing || _activeLivenessStopping) return;
    _activeLivenessStopping = true;

    try {
      _invalidateFramePipeline();

      await _eventSub?.cancel();
      _eventSub = null;

      try {
        await _methodChannel.invokeMethod<void>('stopActiveLiveness');
      } catch (_) {}

      final ctrl = _cameraController;
      if (ctrl != null) {
        await _disposeCameraController(ctrl, disposeCamera: disposeCamera);
      }
    } finally {
      _activeLivenessStopping = false;
    }
  }

  Future<void> _disposeCameraController(CameraController ctrl, {required bool disposeCamera}) async {
    try {
      if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
    } catch (_) {}

    if (disposeCamera) {
      _cameraClosing = true;
      try {
        await ctrl.dispose();
      } catch (_) {}
      if (identical(_cameraController, ctrl)) _cameraController = null;
      _cameraClosing = false;
    }
  }

  void _invalidateFramePipeline() {
    _pendingImage = null;
    _isSending = false;
    _frameToken++;
  }

  bool get _isFrameLoopActive => !_isDisposed && _state == VerificationState.activeLiveness;

  void _finalizeSendCycle(int token) {
    if (token != _frameToken) return;
    _isSending = false;
    if (_pendingImage != null && _isFrameLoopActive) {
      _isSending = true;
      unawaited(_sendLatestFrame(token));
    }
  }

  Future<void> _openCamera() async {
    if (_isDisposed || _cameraOpening || _cameraClosing) return;
    if (_cameraController?.value.isInitialized == true) return;
    _cameraOpening = true;

    try {
      final cameras = await availableCameras();
      if (!mounted || _isDisposed) return;
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      if (!mounted || _isDisposed) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _cameraController = ctrl;
        _activeCamera = front;
        _errorMessage = null;
      });

      unawaited(
        _methodChannel
            .invokeMethod<void>('initialize', {
              'sensorOrientation': front.sensorOrientation,
              'isFrontCamera': front.lensDirection == CameraLensDirection.front,
            })
            .catchError((_) {}),
      );
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not open camera: $e');
      }
    } finally {
      _cameraOpening = false;
    }
  }

  Future<void> _startActiveLiveness() async {
    if (_startingLiveness || _state == VerificationState.activeLiveness) return;

    final ctrl = _cameraController;
    final nfcImage = widget.nfcImageBytes;
    if (_isDisposed || ctrl == null || !ctrl.value.isInitialized) return;
    if (nfcImage == null || nfcImage.isEmpty) {
      setState(() => _errorMessage = 'Missing NFC image');
      return;
    }

    setState(() => _startingLiveness = true);
    try {
      _invalidateFramePipeline();

      await _eventSub?.cancel();
      _eventSub = _eventChannel.receiveBroadcastStream().listen(_onLivenessEvent, onError: _onLivenessStreamError);

      final actions = await _methodChannel.invokeMethod<List<dynamic>>('startActiveLiveness', {'nfcImage': nfcImage});

      if (!mounted || _isDisposed || actions == null || actions.isEmpty) return;

      setState(() {
        _state = VerificationState.activeLiveness;
        _actions = actions.cast<String>();
        _currentAction = null;
        _completedActions = <String>{};
        _extraActionMode = false;
        _actionFlash = false;
        _errorMessage = null;
        _result = null;
      });

      if (!ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Could not start liveness: $e');
      }
    } finally {
      if (mounted && !_isDisposed) setState(() => _startingLiveness = false);
    }
  }

  void _onLivenessStreamError(Object e) {
    if (mounted && !_isDisposed) {
      _invalidateFramePipeline();
      setState(() {
        _state = VerificationState.idle;
        _currentAction = null;
        _errorMessage = 'Liveness error: $e';
      });
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed) return;
    if (_state != VerificationState.activeLiveness) return;
    if (_cameraClosing || _activeLivenessStopping) return;

    _pendingImage = image;

    if (!_isSending) {
      _isSending = true;
      final token = _frameToken;
      unawaited(_sendLatestFrame(token));
    }
  }

  Future<void> _sendLatestFrame(int token) async {
    try {
      while (_isFrameLoopActive && token == _frameToken) {
        final image = _pendingImage;
        if (image == null) break;

        _pendingImage = null;
        final data = await compute(_packNv21Isolate, image);

        if (!_isFrameLoopActive || token != _frameToken || data == null) continue;

        final rotation = _cameraFrameRotation();
        if (rotation == null) continue;

        await _methodChannel.invokeMethod<void>('processFrame', {'frame': data, 'rotation': rotation});
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _invalidateFramePipeline();
        setState(() {
          _state = VerificationState.idle;
          _currentAction = null;
          _errorMessage = 'Frame processing error: $e';
        });
      }
    } finally {
      _finalizeSendCycle(token);
    }
  }

  int? _cameraFrameRotation() {
    final ctrl = _cameraController;
    final camera = _activeCamera ?? ctrl?.description;
    if (ctrl == null || camera == null) return null;

    final rotationComp = _orientations[ctrl.value.deviceOrientation];
    if (rotationComp == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      return (camera.sensorOrientation + rotationComp) % 360;
    }
    return (camera.sensorOrientation - rotationComp + 360) % 360;
  }

  void _onLivenessEvent(dynamic event) {
    if (!mounted || _isDisposed) return;
    if (_state != VerificationState.activeLiveness && _state != VerificationState.processing) return;

    final map = Map<String, dynamic>.from(event as Map);
    final type = map['type'] as String;

    switch (type) {
      case 'actionDetected':
        final action = map['action'] as String;
        setState(() {
          _completedActions.add(action);
          _actionFlash = true;
        });
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_isDisposed) setState(() => _actionFlash = false);
        });

      case 'nextAction':
        setState(() {
          _currentAction = map['action'] as String;
        });

      case 'extraAction':
        final extra = map['action'] as String;
        setState(() {
          _extraActionMode = true;
          _actions = [..._actions, extra];
          _currentAction = extra;
        });

      case 'processing':
        _pendingImage = null;
        setState(() {
          _state = VerificationState.processing;
          _currentAction = null;
        });

      case 'timeout':
        final action = map['action'] as String?;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Take your time - ${action != null ? faceActionLabel(action) : 'perform the action'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );

      case 'complete':
        final passed = map['passed'] as bool;
        final matchScore = (map['matchScore'] as num?)?.toDouble() ?? 0.0;
        _onComplete(passed: passed, matchScore: matchScore);

      case 'error':
        final message = map['message']?.toString() ?? 'Unknown native error';
        _invalidateFramePipeline();
        setState(() {
          _state = VerificationState.idle;
          _currentAction = null;
          _errorMessage = message;
        });
    }
  }

  void _onComplete({required bool passed, required double matchScore}) {
    if (!mounted || _isDisposed) return;
    _invalidateFramePipeline();
    setState(() {
      _state = VerificationState.result;
      _result = VerificationResult(matchScore: matchScore, isLive: passed);
    });
    unawaited(_stopActiveFlow(disposeCamera: false));
  }

  Future<void> _retry() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed || !mounted) return;
    setState(() {
      _result = null;
      _errorMessage = null;
      _state = VerificationState.idle;
      _actions = <String>[];
      _currentAction = null;
      _completedActions = <String>{};
      _extraActionMode = false;
      _actionFlash = false;
    });
    await _openCamera();
  }

  Future<void> _handleBack() async {
    await _stopActiveFlow(disposeCamera: true);
    if (_isDisposed) return;
    widget.onBackPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? buildFaceErrorScreen(errorMessage: _errorMessage!, onBack: _handleBack, onRetry: _retry)
            : switch (_state) {
                VerificationState.idle => buildFaceIdleScreen(
                    cameraController: _cameraController,
                    ready: _cameraController?.value.isInitialized == true,
                    startingLiveness: _startingLiveness,
                    onStart: _startActiveLiveness,
                  ),
                VerificationState.activeLiveness => buildFaceActiveLivenessScreen(
                    cameraController: _cameraController,
                    currentAction: _currentAction,
                    actionFlash: _actionFlash,
                    actions: _actions,
                    completedActions: _completedActions,
                    extraActionMode: _extraActionMode,
                  ),
                VerificationState.processing => buildFaceProcessingScreen(),
                VerificationState.result => _buildResult(),
              },
      ),
    );
  }

  // Threshold scales down for older passport photos, which naturally score lower.
  Widget _buildResult() {
    final r = _result!;
    final threshold = faceMatchThreshold(widget.photoIssueDate);
    final passed = r.matchScore > threshold && r.isLive;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel, size: 80, color: passed ? Colors.green : Colors.red),
          const SizedBox(height: 24),
          Text(
            passed ? 'Identity Verified' : 'Verification Failed',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            'Match score: ${(r.matchScore * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          OutlinedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
