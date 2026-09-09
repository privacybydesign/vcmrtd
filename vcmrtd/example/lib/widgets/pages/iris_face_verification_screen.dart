import 'dart:async';

import 'package:face_verification_iris/face_verification_iris.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';

/// Runs the Iris SDK's face-verification flow.
///
/// Unlike [FlutterFaceVerificationScreen], there is no camera preview to
/// build here — the Iris SDK presents its own full-screen native UI once
/// [IrisFaceVerifier.verify] is called. This screen only bridges into that
/// call and renders the outcome once it returns. Since we have no visibility
/// into the native flow itself, the feedback we *can* control — the intro,
/// the brief hand-off while the SDK boots, and the result — is made as
/// informative as possible to make up for that black box in the middle.
class IrisFaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;

  /// Explicit cancel — the back-arrow tap. Leaves this screen without having
  /// verified anything.
  final VoidCallback onBackPressed;

  /// Fired once, a couple of seconds after a matched result, to continue on to
  /// whatever comes after face verification. Distinct from [onBackPressed] so
  /// callers can send a cancel and a successful verification to different
  /// places (e.g. back to NFC reading vs. on to the document data screen).
  final VoidCallback onVerified;

  // Test-only: injects a verifier so tests don't have to hit the real plugin.
  final IrisFaceVerifier? testVerifier;

  const IrisFaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
  }) : testVerifier = null;

  const IrisFaceVerificationScreen.withVerifier({
    super.key,
    required IrisFaceVerifier verifier,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
  }) : testVerifier = verifier;

  @override
  State<IrisFaceVerificationScreen> createState() => _IrisFaceVerificationScreenState();
}

enum _Status { intro, launching, result }

class _IrisFaceVerificationScreenState extends State<IrisFaceVerificationScreen> {
  late final IrisFaceVerifier _verifier = widget.testVerifier ?? IrisFaceVerifier();

  _Status _status = _Status.intro;
  String _launchMessage = 'Preparing your document photo…';
  Uint8List? _documentPhoto;
  IrisVerificationResult? _result;
  String? _error;
  Timer? _autoContinueTimer;

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  Future<void> _runVerification() async {
    _autoContinueTimer?.cancel();
    setState(() {
      _status = _Status.launching;
      _launchMessage = 'Preparing your document photo…';
      _result = null;
      _error = null;
    });

    final portrait = await _toPng(widget.nfcImageBytes);
    if (portrait == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read the reference portrait for the Iris SDK.';
        _status = _Status.result;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _documentPhoto = portrait;
      _launchMessage = 'Opening the Iris camera…';
    });

    try {
      final result = await _verifier.verify(portrait);
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = _Status.result;
      });
      _scheduleAutoContinueIfMatched(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(e);
        _status = _Status.result;
      });
    }
  }

  /// On a matched result, give the user a brief look at the outcome before
  /// automatically moving on — only a failed/cancelled result waits for
  /// "Try Again".
  void _scheduleAutoContinueIfMatched(IrisVerificationResult result) {
    if (result.outcome != IrisVerificationOutcome.matched) return;
    _autoContinueTimer?.cancel();
    _autoContinueTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      widget.onVerified();
    });
  }

  static String _describeError(Object e) {
    if (e is MissingPluginException) {
      return 'The Iris SDK is not available on this device.';
    }
    if (e is PlatformException) {
      return switch (e.code) {
        'NO_ACTIVITY' => 'Could not open the camera. Please try again.',
        'ALREADY_RUNNING' => 'A verification is already in progress.',
        _ => e.message ?? 'Verification failed (${e.code}).',
      };
    }
    return 'Verification failed: $e';
  }

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  // The Iris SDK requires a PNG-encoded portrait; DG2 photos may be JPEG or
  // JPEG2000. Mirrors face_verification's FaceVerificationEngine._decodeNfcImage:
  // falls back to the native JP2 decoder via image_channel when the Dart
  // decoder does not recognise the format.
  static Future<Uint8List?> _toPng(Uint8List? bytes) async {
    if (bytes == null) return null;
    final decoded = await _decodeImage(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  static Future<img.Image?> _decodeImage(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded != null) return decoded;

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) return null;
      return img.decodeImage(converted);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: switch (_status) {
                _Status.intro => _buildIntro(),
                _Status.launching => _buildLaunching(),
                _Status.result => _buildResult(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => StepBadgeTopBar(
    icon: Icons.arrow_back,
    tooltip: 'Back',
    onBack: widget.onBackPressed,
    current: 3,
    total: 4,
    label: 'Face Verification',
  );

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Verify with the Iris SDK',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Iris SDK opens its own full-screen camera to check that a live '
            'person is present, then compares that face against the portrait '
            'stored on your document.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What to expect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                _IntroStepRow(number: '1', text: 'A camera screen from the Iris SDK will open'),
                SizedBox(height: 6),
                _IntroStepRow(number: '2', text: 'Look directly at the camera and follow any prompts'),
                SizedBox(height: 6),
                _IntroStepRow(number: '3', text: 'Hold still until it finishes — this only takes a moment'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _runVerification,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.face),
            label: const Text('Start Verification'),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_launchMessage)],
      ),
    );
  }

  Widget _buildResult() {
    final error = _error;
    if (error != null) {
      return _ResultView(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Something Went Wrong',
        subtitle: error,
        onRetry: _runVerification,
      );
    }

    return switch (_result?.outcome ?? IrisVerificationOutcome.failed) {
      IrisVerificationOutcome.matched => _ResultView(
        icon: Icons.check_circle,
        color: Colors.green,
        title: 'Identity Verified',
        subtitle: 'The live face matched the document photo.',
        documentPhoto: _documentPhoto,
        liveFace: switch (_result?.face) {
          final face? when face.isNotEmpty => face,
          _ => null,
        },
        isContinuing: true,
      ),
      IrisVerificationOutcome.failed => _ResultView(
        icon: Icons.cancel,
        color: Colors.red,
        title: 'Verification Failed',
        subtitle:
            'The live face did not match the document photo. Make sure '
            "you're well lit and looking at the camera, then try again.",
        documentPhoto: _documentPhoto,
        onRetry: _runVerification,
      ),
      IrisVerificationOutcome.cancelled => _ResultView(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: 'Cancelled',
        subtitle: 'You cancelled the verification. Tap below to try again.',
        onRetry: _runVerification,
      ),
    };
  }
}

class _IntroStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _IntroStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Uint8List? documentPhoto;
  final Uint8List? liveFace;
  final VoidCallback? onRetry;
  final bool isContinuing;

  const _ResultView({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.documentPhoto,
    this.liveFace,
    this.onRetry,
    this.isContinuing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (documentPhoto != null || liveFace != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (documentPhoto != null) _Thumbnail(label: 'Document photo', bytes: documentPhoto!),
                if (documentPhoto != null && liveFace != null) const SizedBox(width: 16),
                if (liveFace != null) _Thumbnail(label: 'Live capture', bytes: liveFace!),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (isContinuing)
            const Center(
              child: Text('Continuing…', style: TextStyle(color: Colors.grey)),
            )
          else if (onRetry != null)
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
